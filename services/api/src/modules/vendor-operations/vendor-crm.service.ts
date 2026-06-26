import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';
import { VendorCalendarService } from './vendor-calendar.service';

export const VENDOR_REQUEST_STAGES = [
  'new',
  'negotiating',
  'accepted',
  'scheduled',
  'arrived',
  'completed',
  'declined',
  'cancelled',
] as const;
export type VendorRequestStage = (typeof VENDOR_REQUEST_STAGES)[number];

export type VendorRequestView = {
  id: string;
  eventId: string;
  vendorId: string;
  organizerId: string;
  stage: VendorRequestStage;
  serviceLabel: string | null;
  message: string;
  negotiationId: string | null;
  scheduledAt: string | null;
  scheduledEnd: string | null;
  arrivedAt: string | null;
  completedAt: string | null;
  source: string;
  vendorName: string | null;
  eventTitle: string | null;
  createdAt: string;
  updatedAt: string;
};

export type VendorPipelineStats = {
  new: number;
  negotiating: number;
  accepted: number;
  scheduled: number;
  arrived: number;
  completed: number;
  declined: number;
  cancelled: number;
  total: number;
};

const STAGE_TRANSITIONS: Record<VendorRequestStage, VendorRequestStage[]> = {
  new: ['negotiating', 'accepted', 'declined', 'cancelled'],
  negotiating: ['accepted', 'declined', 'cancelled'],
  accepted: ['scheduled', 'declined', 'cancelled'],
  scheduled: ['arrived', 'cancelled'],
  arrived: ['completed', 'cancelled'],
  completed: [],
  declined: [],
  cancelled: [],
};

@Injectable()
export class VendorCrmService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly calendar: VendorCalendarService,
  ) {}

  private assertStage(raw: string): VendorRequestStage {
    if (!VENDOR_REQUEST_STAGES.includes(raw as VendorRequestStage)) {
      throw new BadRequestException({ code: 'INVALID_STAGE', message: 'Unknown pipeline stage' });
    }
    return raw as VendorRequestStage;
  }

  private rowToView(row: {
    id: string;
    event_id: string;
    vendor_id: string;
    organizer_id: string;
    stage: string;
    service_label: string | null;
    message: string;
    negotiation_id: string | null;
    scheduled_at: Date | null;
    scheduled_end: Date | null;
    arrived_at: Date | null;
    completed_at: Date | null;
    source: string;
    vendor_name?: string | null;
    event_title?: string | null;
    created_at: Date;
    updated_at: Date;
  }): VendorRequestView {
    return {
      id: row.id,
      eventId: row.event_id,
      vendorId: row.vendor_id,
      organizerId: row.organizer_id,
      stage: row.stage as VendorRequestStage,
      serviceLabel: row.service_label,
      message: row.message,
      negotiationId: row.negotiation_id,
      scheduledAt: row.scheduled_at?.toISOString() ?? null,
      scheduledEnd: row.scheduled_end?.toISOString() ?? null,
      arrivedAt: row.arrived_at?.toISOString() ?? null,
      completedAt: row.completed_at?.toISOString() ?? null,
      source: row.source,
      vendorName: row.vendor_name ?? null,
      eventTitle: row.event_title ?? null,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
    };
  }

  private async loadRequest(tenantId: string, requestId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      event_id: string;
      vendor_id: string;
      organizer_id: string;
      stage: string;
      service_label: string | null;
      message: string;
      negotiation_id: string | null;
      scheduled_at: Date | null;
      scheduled_end: Date | null;
      arrived_at: Date | null;
      completed_at: Date | null;
      source: string;
      created_at: Date;
      updated_at: Date;
    }>(
      `SELECT r.* FROM vendor_event_requests r WHERE r.tenant_id = $1 AND r.id = $2`,
      [tenantId, requestId],
    );
    if (!rows.length) throw new NotFoundException({ code: 'REQUEST_NOT_FOUND', message: 'Vendor request not found' });
    return rows[0]!;
  }

  private async writeHistory(
    tenantId: string,
    requestId: string,
    fromStage: string | null,
    toStage: string,
    actorType: string,
    actorUserId: string | null,
    note?: string,
  ) {
    await this.pool.query(
      `INSERT INTO vendor_request_stage_history
         (tenant_id, request_id, from_stage, to_stage, actor_type, actor_user_id, note)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [tenantId, requestId, fromStage, toStage, actorType, actorUserId, note ?? null],
    );
  }

  private async writeFeed(tenantId: string, eventId: string, headline: string, detail: string, metadata: Record<string, unknown>) {
    await this.pool.query(
      `INSERT INTO event_feed_items (tenant_id, event_id, feed_type, headline, detail, metadata)
       VALUES ($1, $2, 'vendor_crm', $3, $4, $5::jsonb)`,
      [tenantId, eventId, headline, detail, JSON.stringify(metadata)],
    );
  }

  private buildStats(items: VendorRequestView[]): VendorPipelineStats {
    const stats: VendorPipelineStats = {
      new: 0,
      negotiating: 0,
      accepted: 0,
      scheduled: 0,
      arrived: 0,
      completed: 0,
      declined: 0,
      cancelled: 0,
      total: items.length,
    };
    for (const item of items) {
      if (item.stage in stats) (stats as Record<string, number>)[item.stage]++;
    }
    return stats;
  }

  async listForEvent(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query(
      `SELECT r.*, v.business_name AS vendor_name, e.title AS event_title
       FROM vendor_event_requests r
       JOIN vendors v ON v.id = r.vendor_id
       JOIN events e ON e.id = r.event_id
       WHERE r.tenant_id = $1 AND r.event_id = $2
       ORDER BY r.updated_at DESC`,
      [actor.tenantId, event.id],
    );
    const items = rows.map((r) => this.rowToView(r));
    return { items, stats: this.buildStats(items) };
  }

  async listForVendor(actor: CommerceActor, vendorId: string) {
    const ownedVendorId = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    if (ownedVendorId !== vendorId) {
      throw new ForbiddenException({ code: 'ACCESS_DENIED', message: 'Not vendor owner' });
    }
    const { rows } = await this.pool.query(
      `SELECT r.*, v.business_name AS vendor_name, e.title AS event_title
       FROM vendor_event_requests r
       JOIN vendors v ON v.id = r.vendor_id
       JOIN events e ON e.id = r.event_id
       WHERE r.tenant_id = $1 AND r.vendor_id = $2
       ORDER BY r.updated_at DESC`,
      [actor.tenantId, vendorId],
    );
    const items = rows.map((r) => this.rowToView(r));
    return { items, stats: this.buildStats(items) };
  }

  async createRequest(actor: CommerceActor, eventKey: string, body: Record<string, unknown>) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    const vendorId = String(body.vendorId ?? '').trim();
    if (!vendorId) throw new BadRequestException({ code: 'VENDOR_REQUIRED', message: 'vendorId required' });

    const { rows: vendorRows } = await this.pool.query(`SELECT id FROM vendors WHERE tenant_id = $1 AND id = $2`, [
      actor.tenantId,
      vendorId,
    ]);
    if (!vendorRows.length) throw new NotFoundException({ code: 'VENDOR_NOT_FOUND', message: 'Vendor not found' });

    const message = String(body.message ?? '');
    const serviceLabel = body.serviceLabel ? String(body.serviceLabel) : null;
    let stage: VendorRequestStage = 'new';
    let negotiationId: string | null = null;

    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO vendor_event_requests (
         tenant_id, event_id, vendor_id, organizer_id, stage, service_label, message, source
       ) VALUES ($1, $2, $3, $4, 'new', $5, $6, $7)
       ON CONFLICT (event_id, vendor_id) DO UPDATE
         SET message = EXCLUDED.message,
             service_label = COALESCE(EXCLUDED.service_label, vendor_event_requests.service_label),
             updated_at = now()
       RETURNING id`,
      [actor.tenantId, event.id, vendorId, organizerId, serviceLabel, message, String(body.source ?? 'marketplace')],
    );
    const requestId = rows[0]!.id;

    if (body.amountMinor != null) {
      const { rows: negRows } = await this.pool.query<{ id: string }>(
        `INSERT INTO vendor_negotiations (tenant_id, event_id, vendor_id, organizer_id, service_label, status, vendor_request_id)
         VALUES ($1, $2, $3, $4, $5, 'pending', $6)
         RETURNING id`,
        [actor.tenantId, event.id, vendorId, organizerId, serviceLabel, requestId],
      );
      negotiationId = negRows[0]!.id;
      await this.pool.query(
        `INSERT INTO vendor_negotiation_offers
           (negotiation_id, actor_type, actor_user_id, amount_minor, message, status)
         VALUES ($1, 'organizer', $2, $3::bigint, $4, 'pending')`,
        [negotiationId, actor.userId, String(body.amountMinor), message],
      );
      stage = 'negotiating';
      await this.pool.query(
        `UPDATE vendor_event_requests SET stage = 'negotiating', negotiation_id = $3, updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [actor.tenantId, requestId, negotiationId],
      );
    }

    await this.writeHistory(actor.tenantId, requestId, null, stage, 'organizer', actor.userId, 'Request created');
    const { rows: vendorName } = await this.pool.query<{ business_name: string }>(
      `SELECT business_name FROM vendors WHERE id = $1`,
      [vendorId],
    );
    await this.writeFeed(
      actor.tenantId,
      event.id,
      `Vendor request: ${vendorName[0]?.business_name ?? 'vendor'}`,
      message || 'New marketplace request',
      { requestId, stage },
    );

    return this.listForEvent(actor, event.id);
  }

  async transitionStage(
    actor: CommerceActor,
    requestId: string,
    toStageRaw: string,
    body: Record<string, unknown> = {},
  ) {
    const toStage = this.assertStage(toStageRaw);
    const row = await this.loadRequest(actor.tenantId, requestId);
    const fromStage = row.stage as VendorRequestStage;
    const allowed = STAGE_TRANSITIONS[fromStage] ?? [];
    if (!allowed.includes(toStage)) {
      throw new UnprocessableEntityException({
        code: 'INVALID_TRANSITION',
        message: `Cannot move from ${fromStage} to ${toStage}`,
      });
    }

    let actorType: 'organizer' | 'vendor' = 'organizer';
    try {
      await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    } catch {
      const vendorId = await this.access.resolveVendorId(actor.tenantId, actor.userId);
      if (vendorId !== row.vendor_id) throw new ForbiddenException({ code: 'ACCESS_DENIED' });
      actorType = 'vendor';
      if (!['negotiating', 'accepted', 'arrived', 'completed'].includes(toStage) && toStage !== 'declined') {
        throw new ForbiddenException({ code: 'VENDOR_STAGE_DENIED', message: 'Vendor cannot set this stage' });
      }
    }

    const scheduledAt = body.scheduledAt ? new Date(String(body.scheduledAt)) : null;
    const scheduledEnd = body.scheduledEnd ? new Date(String(body.scheduledEnd)) : null;

    let start: Date | null = scheduledAt ?? row.scheduled_at;
    let end: Date | null = scheduledEnd ?? row.scheduled_end;

    if (toStage === 'scheduled') {
      if (!start) {
        const { rows: ev } = await this.pool.query<{ starts_at: Date; ends_at: Date | null }>(
          `SELECT starts_at, ends_at FROM events WHERE id = $1`,
          [row.event_id],
        );
        start = ev[0]?.starts_at ?? new Date();
        end = ev[0]?.ends_at ?? new Date(start.getTime() + 4 * 60 * 60_000);
      } else if (!end) {
        end = new Date(start.getTime() + 4 * 60 * 60_000);
      }
      await this.calendar.assertAvailable(actor.tenantId, row.vendor_id, start, end);
      await this.calendar.syncCrmBlock(actor.tenantId, row.vendor_id, requestId, start, end);
    }

    const sets = ['stage = $3', 'updated_at = now()'];
    const params: unknown[] = [actor.tenantId, requestId, toStage];
    if (toStage === 'arrived') sets.push('arrived_at = now()');
    if (toStage === 'completed') sets.push('completed_at = now()');
    if (toStage === 'scheduled' && start && end) {
      sets.push(`scheduled_at = $${params.length + 1}`);
      params.push(start);
      sets.push(`scheduled_end = $${params.length + 1}`);
      params.push(end);
    } else {
      if (scheduledAt) {
        sets.push(`scheduled_at = $${params.length + 1}`);
        params.push(scheduledAt);
      }
      if (scheduledEnd) {
        sets.push(`scheduled_end = $${params.length + 1}`);
        params.push(scheduledEnd);
      }
    }

    await this.pool.query(
      `UPDATE vendor_event_requests SET ${sets.join(', ')} WHERE tenant_id = $1 AND id = $2`,
      params,
    );

    if (toStage === 'accepted' && row.negotiation_id) {
      await this.pool.query(
        `UPDATE vendor_negotiations SET status = 'accepted', updated_at = now() WHERE id = $1`,
        [row.negotiation_id],
      );
    }

    await this.writeHistory(
      actor.tenantId,
      requestId,
      fromStage,
      toStage,
      actorType,
      actor.userId,
      body.note ? String(body.note) : undefined,
    );

    const feedHeadline = switchStageFeed(toStage, row.service_label);
    await this.writeFeed(actor.tenantId, row.event_id, feedHeadline, String(body.note ?? ''), {
      requestId,
      fromStage,
      toStage,
    });

    const event = await this.access.resolveEventRow(actor.tenantId, row.event_id);
    return this.listForEvent(actor, event.id);
  }

  async patchRequest(actor: CommerceActor, requestId: string, body: Record<string, unknown>) {
    const row = await this.loadRequest(actor.tenantId, requestId);
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);

    const fields: Array<[string, unknown]> = [
      ['service_label', body.serviceLabel],
      ['message', body.message],
      ['scheduled_at', body.scheduledAt ? new Date(String(body.scheduledAt)) : undefined],
      ['scheduled_end', body.scheduledEnd ? new Date(String(body.scheduledEnd)) : undefined],
    ];
    const sets: string[] = [];
    const params: unknown[] = [actor.tenantId, requestId];
    for (const [col, val] of fields) {
      if (val !== undefined) {
        params.push(val);
        sets.push(`${col} = $${params.length}`);
      }
    }
    if (sets.length) {
      sets.push('updated_at = now()');
      await this.pool.query(
        `UPDATE vendor_event_requests SET ${sets.join(', ')} WHERE tenant_id = $1 AND id = $2`,
        params,
      );
    }
    const event = await this.access.resolveEventRow(actor.tenantId, row.event_id);
    return this.listForEvent(actor, event.id);
  }
}

function switchStageFeed(stage: VendorRequestStage, serviceLabel: string | null): string {
  const label = serviceLabel ?? 'Vendor';
  switch (stage) {
    case 'negotiating':
      return `${label}: negotiating`;
    case 'accepted':
      return `${label}: accepted`;
    case 'scheduled':
      return `${label}: scheduled`;
    case 'arrived':
      return `${label} arrived on site`;
    case 'completed':
      return `${label}: completed`;
    case 'declined':
      return `${label}: declined`;
    case 'cancelled':
      return `${label}: cancelled`;
    default:
      return `${label}: ${stage}`;
  }
}
