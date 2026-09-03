import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  Optional,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool, PoolClient } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';
import { VendorServicesService } from '../vendors/vendor-services.service';
import { VendorAvailabilityService } from './vendor-availability.service';
import {
  allowedCapabilitySet,
  normalizeCapabilityKey,
  parseSelectedCapabilities,
  parseVendorCapabilities,
  validateSelectedCapabilities,
  type SelectedCapability,
} from './vendor-capability.util';
import { CrmRealtimeBroadcastService } from '../../integrations/realtime/crm-realtime-broadcast.service';
import { resolveEventWindow } from './vendor-availability.util';

export const CHANGE_REQUEST_TYPES = [
  'ADD_CAPABILITY',
  'REMOVE_CAPABILITY',
  'CHANGE_DATE',
  'CHANGE_TIME',
  'CHANGE_VENUE',
  'SPECIAL_REQUIREMENT',
] as const;
export type ChangeRequestType = (typeof CHANGE_REQUEST_TYPES)[number];

export const CHANGE_REQUEST_STATUSES = [
  'pending',
  'accepted',
  'declined',
  'cancelled',
  'expired',
] as const;
export type ChangeRequestStatus = (typeof CHANGE_REQUEST_STATUSES)[number];

type ParentRow = {
  id: string;
  tenant_id: string;
  event_id: string;
  vendor_id: string;
  organizer_id: string;
  stage: string;
  service_key: string;
  service_label: string | null;
  vendor_service_id: string | null;
  metadata: unknown;
  scheduled_at: Date | null;
  scheduled_end: Date | null;
};

type ChangeRow = {
  id: string;
  tenant_id: string;
  vendor_request_id: string;
  event_id: string;
  vendor_id: string;
  organizer_id: string;
  requested_by_user_id: string;
  responded_by_user_id: string | null;
  type: ChangeRequestType;
  status: ChangeRequestStatus;
  original_snapshot: Record<string, unknown>;
  requested_payload: Record<string, unknown>;
  response_payload: Record<string, unknown>;
  created_at: Date;
  updated_at: Date;
  resolved_at: Date | null;
};

const ACTIVE_PARENT_STAGES = new Set(['accepted', 'scheduled', 'arrived']);

@Injectable()
export class VendorChangeRequestService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly availability: VendorAvailabilityService,
    @Optional() private readonly vendorServices?: VendorServicesService,
    @Optional() private readonly crmRealtime?: CrmRealtimeBroadcastService,
  ) {}

  async listForRequest(actor: CommerceActor, requestId: string) {
    const parent = await this.loadParentAuthorized(actor, requestId, 'read');
    const { rows } = await this.pool.query<ChangeRow>(
      `SELECT * FROM vendor_request_change_requests
       WHERE tenant_id = $1 AND vendor_request_id = $2
       ORDER BY created_at DESC`,
      [actor.tenantId, parent.id],
    );
    return { items: rows.map((r) => this.toView(r)) };
  }

  async create(actor: CommerceActor, requestId: string, body: Record<string, unknown>) {
    const parent = await this.loadParentAuthorized(actor, requestId, 'organizer');
    if (!ACTIVE_PARENT_STAGES.has(parent.stage)) {
      throw new UnprocessableEntityException({
        code: 'CHANGE_NOT_ALLOWED',
        message: 'Change requests are only allowed for active accepted bookings',
      });
    }

    const type = this.assertType(String(body.type ?? ''));
    const event = await this.loadEvent(actor.tenantId, parent.event_id);
    const originalSnapshot = this.buildOriginalSnapshot(parent, event);
    const requestedPayload = await this.validateAndNormalizePayload(actor, parent, type, body, event);

    const { rows } = await this.pool.query<ChangeRow>(
      `INSERT INTO vendor_request_change_requests (
         tenant_id, vendor_request_id, event_id, vendor_id, organizer_id,
         requested_by_user_id, type, status, original_snapshot, requested_payload
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,'pending',$8::jsonb,$9::jsonb)
       RETURNING *`,
      [
        actor.tenantId,
        parent.id,
        parent.event_id,
        parent.vendor_id,
        parent.organizer_id,
        actor.userId,
        type,
        JSON.stringify(originalSnapshot),
        JSON.stringify(requestedPayload),
      ],
    );
    const created = rows[0]!;

    // Parent booking must remain unchanged while pending.
    await this.emitToVendor(parent, 'vendor_change_request_created', created);

    return this.toView(created);
  }

  async accept(actor: CommerceActor, changeId: string) {
    return this.resolve(actor, changeId, 'accepted');
  }

  async decline(actor: CommerceActor, changeId: string, body: Record<string, unknown> = {}) {
    return this.resolve(actor, changeId, 'declined', body);
  }

  async cancel(actor: CommerceActor, changeId: string) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const row = await this.lockChange(client, actor.tenantId, changeId);
      await this.assertOrganizerOnParent(actor, row.vendor_request_id);
      if (row.status !== 'pending') {
        if (row.status === 'cancelled') {
          await client.query('COMMIT');
          return this.toView(row); // idempotent
        }
        throw new UnprocessableEntityException({
          code: 'INVALID_TRANSITION',
          message: `Cannot cancel from ${row.status}`,
        });
      }
      const { rows } = await client.query<ChangeRow>(
        `UPDATE vendor_request_change_requests
         SET status = 'cancelled',
             responded_by_user_id = $3,
             response_payload = $4::jsonb,
             resolved_at = now(),
             updated_at = now()
         WHERE tenant_id = $1 AND id = $2
         RETURNING *`,
        [
          actor.tenantId,
          changeId,
          actor.userId,
          JSON.stringify({ cancelledBy: 'organizer' }),
        ],
      );
      await client.query('COMMIT');
      const updated = rows[0]!;
      const parent = await this.loadParent(actor.tenantId, updated.vendor_request_id);
      await this.emitToVendor(parent, 'vendor_change_request_cancelled', updated);
      return this.toView(updated);
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  private async resolve(
    actor: CommerceActor,
    changeId: string,
    outcome: 'accepted' | 'declined',
    body: Record<string, unknown> = {},
  ) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const row = await this.lockChange(client, actor.tenantId, changeId);
      await this.assertVendorOnParent(actor, row.vendor_id);

      // Idempotent re-accept / re-decline
      if (row.status === outcome) {
        await client.query('COMMIT');
        return this.toView(row);
      }
      if (row.status !== 'pending') {
        throw new UnprocessableEntityException({
          code: 'INVALID_TRANSITION',
          message: `Cannot ${outcome} from ${row.status}`,
        });
      }

      const parent = await this.lockParent(client, actor.tenantId, row.vendor_request_id);
      if (!ACTIVE_PARENT_STAGES.has(parent.stage) && outcome === 'accepted') {
        throw new UnprocessableEntityException({
          code: 'PARENT_NOT_ACTIVE',
          message: 'Parent booking is no longer active',
        });
      }

      let responsePayload: Record<string, unknown> = {
        note: body.note ? String(body.note).slice(0, 2000) : null,
      };

      if (outcome === 'accepted') {
        responsePayload = {
          ...responsePayload,
          ...(await this.applyAcceptedChange(client, actor, parent, row)),
        };
      }

      const { rows } = await client.query<ChangeRow>(
        `UPDATE vendor_request_change_requests
         SET status = $3,
             responded_by_user_id = $4,
             response_payload = $5::jsonb,
             resolved_at = now(),
             updated_at = now()
         WHERE tenant_id = $1 AND id = $2 AND status = 'pending'
         RETURNING *`,
        [actor.tenantId, changeId, outcome, actor.userId, JSON.stringify(responsePayload)],
      );
      if (!rows[0]) {
        throw new ConflictException({
          code: 'CHANGE_CONFLICT',
          message: 'Change request was already resolved',
        });
      }
      await client.query('COMMIT');

      const updated = rows[0];
      const sseType =
        outcome === 'accepted'
          ? 'vendor_change_request_accepted'
          : 'vendor_change_request_declined';
      await this.emitToOrganizer(parent, sseType, updated);
      return this.toView(updated);
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  private async applyAcceptedChange(
    client: PoolClient,
    actor: CommerceActor,
    parent: ParentRow,
    change: ChangeRow,
  ): Promise<Record<string, unknown>> {
    const payload = change.requested_payload ?? {};
    switch (change.type) {
      case 'ADD_CAPABILITY':
      case 'REMOVE_CAPABILITY':
        return this.applyCapabilityChange(client, parent, change.type, payload);
      case 'CHANGE_DATE':
      case 'CHANGE_TIME':
        return this.applyScheduleChange(client, actor, parent, payload);
      case 'CHANGE_VENUE':
        return this.applyVenueChange(client, parent, payload);
      case 'SPECIAL_REQUIREMENT':
        return this.applySpecialRequirement(client, parent, payload, actor.userId);
      default:
        throw new BadRequestException({ code: 'TYPE_UNSUPPORTED', message: 'Unknown change type' });
    }
  }

  private async applyCapabilityChange(
    client: PoolClient,
    parent: ParentRow,
    type: 'ADD_CAPABILITY' | 'REMOVE_CAPABILITY',
    payload: Record<string, unknown>,
  ) {
    const key = normalizeCapabilityKey(String(payload.capabilityKey ?? ''));
    const label = String(payload.capabilityLabel ?? key);
    const meta =
      parent.metadata && typeof parent.metadata === 'object' && !Array.isArray(parent.metadata)
        ? { ...(parent.metadata as Record<string, unknown>) }
        : {};
    let selected = parseSelectedCapabilities(meta.selectedCapabilities);
    const before = selected.map((s) => s.key);

    if (type === 'ADD_CAPABILITY') {
      if (!selected.some((s) => s.key === key)) {
        selected = [...selected, { key, label }];
      }
    } else {
      selected = selected.filter((s) => s.key !== key);
    }
    meta.selectedCapabilities = selected;
    await client.query(
      `UPDATE vendor_event_requests
       SET metadata = $3::jsonb, updated_at = now()
       WHERE tenant_id = $1 AND id = $2`,
      [parent.tenant_id, parent.id, JSON.stringify(meta)],
    );
    return {
      applied: true,
      capabilityKey: key,
      selectedBefore: before,
      selectedAfter: selected.map((s) => s.key),
    };
  }

  private async applyScheduleChange(
    client: PoolClient,
    actor: CommerceActor,
    parent: ParentRow,
    payload: Record<string, unknown>,
  ) {
    const startsAt = new Date(String(payload.startsAt ?? ''));
    const endsAt = new Date(String(payload.endsAt ?? ''));
    if (Number.isNaN(startsAt.getTime()) || Number.isNaN(endsAt.getTime()) || endsAt < startsAt) {
      throw new BadRequestException({
        code: 'INVALID_WINDOW',
        message: 'startsAt/endsAt required and endsAt must be >= startsAt',
      });
    }

    // Re-validate availability at acceptance time (critical).
    const vsStatus = parent.vendor_service_id && this.vendorServices
      ? (await this.vendorServices.getById(actor.tenantId, parent.vendor_id, parent.vendor_service_id))
          ?.status === 'active'
      : true;
    await this.availability.assertServiceWindowBookable({
      tenantId: actor.tenantId,
      vendorId: parent.vendor_id,
      vendorServiceId: parent.vendor_service_id,
      serviceKey: parent.service_key,
      window: { start: startsAt, end: endsAt },
      offerActive: vsStatus,
      excludeRequestId: parent.id,
    });

    const { rows: beforeEv } = await client.query<{ starts_at: Date; ends_at: Date | null }>(
      `SELECT starts_at, ends_at FROM events WHERE tenant_id = $1 AND id = $2 FOR UPDATE`,
      [actor.tenantId, parent.event_id],
    );
    const before = beforeEv[0];
    await client.query(
      `UPDATE events
       SET starts_at = $3, ends_at = $4, updated_at = now()
       WHERE tenant_id = $1 AND id = $2`,
      [actor.tenantId, parent.event_id, startsAt, endsAt],
    );
    await client.query(
      `UPDATE vendor_event_requests
       SET scheduled_at = $3, scheduled_end = $4, updated_at = now()
       WHERE tenant_id = $1 AND id = $2`,
      [actor.tenantId, parent.id, startsAt, endsAt],
    );
    return {
      applied: true,
      eventStartsAtBefore: before?.starts_at?.toISOString() ?? null,
      eventEndsAtBefore: before?.ends_at?.toISOString() ?? null,
      eventStartsAtAfter: startsAt.toISOString(),
      eventEndsAtAfter: endsAt.toISOString(),
    };
  }

  private async applyVenueChange(
    client: PoolClient,
    parent: ParentRow,
    payload: Record<string, unknown>,
  ) {
    const { rows } = await client.query<{ metadata: Record<string, unknown> }>(
      `SELECT metadata FROM events WHERE tenant_id = $1 AND id = $2 FOR UPDATE`,
      [parent.tenant_id, parent.event_id],
    );
    const meta = { ...(rows[0]?.metadata ?? {}) };
    const before = {
      venue: meta.venue ?? meta.venueName ?? null,
      venueName: meta.venueName ?? null,
      venueAddress: meta.venueAddress ?? null,
      city: meta.city ?? null,
      state: meta.state ?? null,
    };
    if (payload.venue != null) meta.venue = String(payload.venue);
    if (payload.venueName != null) meta.venueName = String(payload.venueName);
    if (payload.venueAddress != null) meta.venueAddress = String(payload.venueAddress);
    if (payload.city != null) meta.city = String(payload.city);
    if (payload.state != null) meta.state = String(payload.state);
    await client.query(
      `UPDATE events SET metadata = $3::jsonb, updated_at = now() WHERE tenant_id = $1 AND id = $2`,
      [parent.tenant_id, parent.event_id, JSON.stringify(meta)],
    );
    return { applied: true, venueBefore: before, venueAfter: payload };
  }

  private async applySpecialRequirement(
    client: PoolClient,
    parent: ParentRow,
    payload: Record<string, unknown>,
    actorUserId: string,
  ) {
    const text = String(payload.requirement ?? '').trim();
    const meta =
      parent.metadata && typeof parent.metadata === 'object' && !Array.isArray(parent.metadata)
        ? { ...(parent.metadata as Record<string, unknown>) }
        : {};
    const list = Array.isArray(meta.specialRequirements)
      ? [...(meta.specialRequirements as unknown[])]
      : [];
    list.push({
      text,
      acceptedAt: new Date().toISOString(),
      acceptedByUserId: actorUserId,
    });
    meta.specialRequirements = list;
    await client.query(
      `UPDATE vendor_event_requests
       SET metadata = $3::jsonb, updated_at = now()
       WHERE tenant_id = $1 AND id = $2`,
      [parent.tenant_id, parent.id, JSON.stringify(meta)],
    );
    await client.query(
      `INSERT INTO vendor_request_stage_history
         (tenant_id, request_id, from_stage, to_stage, actor_type, actor_user_id, note)
       VALUES ($1,$2,$3,$3,'vendor',$4,$5)`,
      [
        parent.tenant_id,
        parent.id,
        parent.stage,
        actorUserId,
        `Special requirement accepted: ${text.slice(0, 500)}`,
      ],
    );
    return { applied: true, requirement: text };
  }

  private async validateAndNormalizePayload(
    actor: CommerceActor,
    parent: ParentRow,
    type: ChangeRequestType,
    body: Record<string, unknown>,
    event: { starts_at: Date; ends_at: Date | null; metadata: Record<string, unknown> },
  ): Promise<Record<string, unknown>> {
    const payload =
      body.payload && typeof body.payload === 'object' && !Array.isArray(body.payload)
        ? (body.payload as Record<string, unknown>)
        : body;

    switch (type) {
      case 'ADD_CAPABILITY': {
        const key = normalizeCapabilityKey(String(payload.capabilityKey ?? payload.key ?? ''));
        if (!key) {
          throw new BadRequestException({
            code: 'CAPABILITY_REQUIRED',
            message: 'capabilityKey required',
          });
        }
        const selected = await this.resolveAllowedCapability(actor, parent, key);
        return { capabilityKey: selected.key, capabilityLabel: selected.label };
      }
      case 'REMOVE_CAPABILITY': {
        const key = normalizeCapabilityKey(String(payload.capabilityKey ?? payload.key ?? ''));
        if (!key) {
          throw new BadRequestException({
            code: 'CAPABILITY_REQUIRED',
            message: 'capabilityKey required',
          });
        }
        const current = parseSelectedCapabilities(
          parent.metadata && typeof parent.metadata === 'object'
            ? (parent.metadata as Record<string, unknown>).selectedCapabilities
            : [],
        );
        const found = current.find((c) => c.key === key);
        if (!found) {
          throw new BadRequestException({
            code: 'CAPABILITY_NOT_SELECTED',
            message: 'Capability is not part of the current booking',
          });
        }
        return { capabilityKey: found.key, capabilityLabel: found.label };
      }
      case 'CHANGE_DATE':
      case 'CHANGE_TIME': {
        const startsAt = new Date(String(payload.startsAt ?? payload.starts_at ?? ''));
        let endsAt = new Date(String(payload.endsAt ?? payload.ends_at ?? ''));
        if (Number.isNaN(startsAt.getTime())) {
          throw new BadRequestException({
            code: 'INVALID_WINDOW',
            message: 'startsAt required',
          });
        }
        if (Number.isNaN(endsAt.getTime())) {
          // Preserve duration from current event window when only start changes.
          const current = resolveEventWindow(event.starts_at, event.ends_at);
          const duration = current.end.getTime() - current.start.getTime();
          endsAt = new Date(startsAt.getTime() + duration);
        }
        if (endsAt < startsAt) {
          throw new BadRequestException({
            code: 'INVALID_WINDOW',
            message: 'endsAt must be >= startsAt',
          });
        }
        // Soft check at create time (acceptance re-validates).
        try {
          await this.availability.assertServiceWindowBookable({
            tenantId: actor.tenantId,
            vendorId: parent.vendor_id,
            vendorServiceId: parent.vendor_service_id,
            serviceKey: parent.service_key,
            window: { start: startsAt, end: endsAt },
            offerActive: true,
            excludeRequestId: parent.id,
          });
        } catch (e) {
          // Allow create even if currently conflicting? Spec for create doesn't require
          // soft fail — better to reject early if already known conflict.
          throw e;
        }
        return {
          startsAt: startsAt.toISOString(),
          endsAt: endsAt.toISOString(),
        };
      }
      case 'CHANGE_VENUE': {
        const venueName = String(payload.venueName ?? payload.venue ?? '').trim();
        if (!venueName) {
          throw new BadRequestException({
            code: 'VENUE_REQUIRED',
            message: 'venueName required',
          });
        }
        return {
          venue: venueName,
          venueName,
          venueAddress: payload.venueAddress ? String(payload.venueAddress) : null,
          city: payload.city ? String(payload.city) : null,
          state: payload.state ? String(payload.state) : null,
        };
      }
      case 'SPECIAL_REQUIREMENT': {
        const requirement = String(payload.requirement ?? payload.text ?? body.message ?? '').trim();
        if (!requirement || requirement.length < 3) {
          throw new BadRequestException({
            code: 'REQUIREMENT_REQUIRED',
            message: 'requirement text required',
          });
        }
        if (requirement.length > 2000) {
          throw new BadRequestException({
            code: 'REQUIREMENT_TOO_LONG',
            message: 'requirement must be <= 2000 characters',
          });
        }
        return { requirement };
      }
      default:
        throw new BadRequestException({ code: 'TYPE_UNSUPPORTED', message: 'Unknown type' });
    }
  }

  private async resolveAllowedCapability(
    actor: CommerceActor,
    parent: ParentRow,
    key: string,
  ): Promise<SelectedCapability> {
    if (!parent.vendor_service_id || !this.vendorServices) {
      throw new BadRequestException({
        code: 'VENDOR_SERVICE_REQUIRED',
        message: 'Parent request has no linked vendor service',
      });
    }
    const vs = await this.vendorServices.getById(
      actor.tenantId,
      parent.vendor_id,
      parent.vendor_service_id,
    );
    if (!vs || vs.status !== 'active') {
      throw new UnprocessableEntityException({
        code: 'VENDOR_SERVICE_INACTIVE',
        message: 'Vendor service is not active',
      });
    }
    const adminMap = await this.vendorServices.allowedCapabilityKeys(
      actor.tenantId,
      vs.serviceKey,
      vs.serviceName,
    );
    const adminEnabled = [...adminMap.entries()].map(([k, label]) => ({
      key: k,
      label,
      enabled: true,
      // Intersection uses enabled ∩ provided only; tier is Admin catalogue metadata.
      tier: 'core' as const,
    }));
    const allowed = allowedCapabilitySet(adminEnabled, parseVendorCapabilities(vs.capabilities));
    const validated = validateSelectedCapabilities([{ key, label: key }], allowed);
    if (!validated.ok) {
      throw new BadRequestException({
        code: 'CAPABILITY_INVALID',
        message: 'Capability is not admin-enabled and vendor-provided for this service',
        invalidKeys: validated.invalidKeys,
      });
    }
    return validated.snapshot[0]!;
  }

  private buildOriginalSnapshot(
    parent: ParentRow,
    event: { starts_at: Date; ends_at: Date | null; metadata: Record<string, unknown> },
  ) {
    const meta =
      parent.metadata && typeof parent.metadata === 'object' && !Array.isArray(parent.metadata)
        ? (parent.metadata as Record<string, unknown>)
        : {};
    return {
      vendorRequestId: parent.id,
      stage: parent.stage,
      serviceKey: parent.service_key,
      serviceLabel: parent.service_label,
      selectedCapabilities: parseSelectedCapabilities(meta.selectedCapabilities),
      scheduledAt: parent.scheduled_at?.toISOString() ?? null,
      scheduledEnd: parent.scheduled_end?.toISOString() ?? null,
      eventStartsAt: event.starts_at.toISOString(),
      eventEndsAt: event.ends_at?.toISOString() ?? null,
      venue: event.metadata.venue ?? event.metadata.venueName ?? null,
      venueName: event.metadata.venueName ?? null,
      venueAddress: event.metadata.venueAddress ?? null,
      city: event.metadata.city ?? null,
      state: event.metadata.state ?? null,
    };
  }

  private async loadParentAuthorized(
    actor: CommerceActor,
    requestId: string,
    mode: 'read' | 'organizer',
  ): Promise<ParentRow> {
    const parent = await this.loadParent(actor.tenantId, requestId);
    if (mode === 'organizer') {
      await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, parent.event_id);
      return parent;
    }
    try {
      await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, parent.event_id);
      return parent;
    } catch {
      const vendorId = await this.access.resolveVendorId(actor.tenantId, actor.userId);
      if (vendorId !== parent.vendor_id) {
        throw new ForbiddenException({ code: 'ACCESS_DENIED', message: 'Not a participant' });
      }
      return parent;
    }
  }

  private async loadParent(tenantId: string, requestId: string): Promise<ParentRow> {
    const { rows } = await this.pool.query<ParentRow>(
      `SELECT id, tenant_id, event_id, vendor_id, organizer_id, stage, service_key, service_label,
              vendor_service_id, metadata, scheduled_at, scheduled_end
       FROM vendor_event_requests
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, requestId],
    );
    if (!rows[0]) {
      throw new NotFoundException({ code: 'REQUEST_NOT_FOUND', message: 'Vendor request not found' });
    }
    return rows[0];
  }

  private async loadEvent(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query<{
      starts_at: Date;
      ends_at: Date | null;
      metadata: Record<string, unknown>;
    }>(
      `SELECT starts_at, ends_at, metadata FROM events WHERE tenant_id = $1 AND id = $2`,
      [tenantId, eventId],
    );
    if (!rows[0]) {
      throw new NotFoundException({ code: 'EVENT_NOT_FOUND', message: 'Event not found' });
    }
    return rows[0];
  }

  private async lockChange(client: PoolClient, tenantId: string, changeId: string): Promise<ChangeRow> {
    const { rows } = await client.query<ChangeRow>(
      `SELECT * FROM vendor_request_change_requests
       WHERE tenant_id = $1 AND id = $2
       FOR UPDATE`,
      [tenantId, changeId],
    );
    if (!rows[0]) {
      throw new NotFoundException({
        code: 'CHANGE_REQUEST_NOT_FOUND',
        message: 'Change request not found',
      });
    }
    return rows[0];
  }

  private async lockParent(client: PoolClient, tenantId: string, requestId: string): Promise<ParentRow> {
    const { rows } = await client.query<ParentRow>(
      `SELECT id, tenant_id, event_id, vendor_id, organizer_id, stage, service_key, service_label,
              vendor_service_id, metadata, scheduled_at, scheduled_end
       FROM vendor_event_requests
       WHERE tenant_id = $1 AND id = $2
       FOR UPDATE`,
      [tenantId, requestId],
    );
    if (!rows[0]) {
      throw new NotFoundException({ code: 'REQUEST_NOT_FOUND', message: 'Vendor request not found' });
    }
    return rows[0];
  }

  private async assertOrganizerOnParent(actor: CommerceActor, requestId: string) {
    const parent = await this.loadParent(actor.tenantId, requestId);
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, parent.event_id);
  }

  private async assertVendorOnParent(actor: CommerceActor, vendorId: string) {
    const owned = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    if (owned !== vendorId) {
      throw new ForbiddenException({ code: 'ACCESS_DENIED', message: 'Not vendor owner' });
    }
  }

  private assertType(raw: string): ChangeRequestType {
    if (!(CHANGE_REQUEST_TYPES as readonly string[]).includes(raw)) {
      throw new BadRequestException({
        code: 'INVALID_CHANGE_TYPE',
        message: `type must be one of ${CHANGE_REQUEST_TYPES.join(', ')}`,
      });
    }
    return raw as ChangeRequestType;
  }

  private toView(row: ChangeRow) {
    return {
      id: row.id,
      vendorRequestId: row.vendor_request_id,
      eventId: row.event_id,
      vendorId: row.vendor_id,
      organizerId: row.organizer_id,
      requestedByUserId: row.requested_by_user_id,
      respondedByUserId: row.responded_by_user_id,
      type: row.type,
      status: row.status,
      originalSnapshot: row.original_snapshot,
      requestedPayload: row.requested_payload,
      responsePayload: row.response_payload,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
      resolvedAt: row.resolved_at?.toISOString() ?? null,
    };
  }

  private async emitToVendor(
    parent: ParentRow,
    type: string,
    change: ChangeRow,
  ): Promise<void> {
    const { rows } = await this.pool.query<{ owner_user_id: string }>(
      `SELECT owner_user_id FROM vendors WHERE tenant_id = $1 AND id = $2`,
      [parent.tenant_id, parent.vendor_id],
    );
    this.emit(rows[0]?.owner_user_id, parent, type, change);
  }

  private async emitToOrganizer(
    parent: ParentRow,
    type: string,
    change: ChangeRow,
  ): Promise<void> {
    const { rows } = await this.pool.query<{ owner_user_id: string }>(
      `SELECT owner_user_id FROM organizers WHERE tenant_id = $1 AND id = $2`,
      [parent.tenant_id, parent.organizer_id],
    );
    this.emit(rows[0]?.owner_user_id, parent, type, change);
  }

  private emit(
    recipientUserId: string | undefined,
    parent: ParentRow,
    type: string,
    change: ChangeRow,
  ): void {
    if (!this.crmRealtime?.isEnabled() || !recipientUserId) return;
    try {
      this.crmRealtime.publishToUser(recipientUserId, {
        type,
        tenantId: parent.tenant_id,
        resource: { type: 'vendor_change_request', id: change.id },
        revision: change.updated_at.toISOString(),
        updatedAt: change.updated_at.toISOString(),
        dedupeKey: `vendor_change_request:${change.id}:${change.status}`,
        meta: {
          eventId: parent.event_id,
          vendorId: parent.vendor_id,
          vendorRequestId: parent.id,
          changeType: change.type,
          stage: change.status,
        },
      });
    } catch {
      /* never roll back business */
    }
  }
}
