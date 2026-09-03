import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Inject,
  NotFoundException,
  Optional,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';
import { VendorServicesService } from '../vendors/vendor-services.service';
import { VendorCalendarService } from './vendor-calendar.service';
import { VendorAvailabilityService } from './vendor-availability.service';
import {
  allowedCapabilitySet,
  parseSelectedCapabilities,
  parseVendorCapabilities,
  validateSelectedCapabilities,
  type SelectedCapability,
} from './vendor-capability.util';
import { NotificationService } from '../../integrations/notifications/notification.service';
import { CrmRealtimeBroadcastService } from '../../integrations/realtime/crm-realtime-broadcast.service';
import { DomainEventsService } from '../domain-events/domain-events.service';
import { DOMAIN_EVENTS } from '../domain-events/domain-event.types';
import { detectPlatformBypass } from './vendor-message-guard';
import {
  EventVendorFundsService,
  VendorPricingRulesService,
} from './vendor-pricing-funds.service';
import {
  customerPriceFromVendorPayout,
  normalizeServiceKey,
  vendorPayoutFromCustomerPrice,
} from './vendor-pricing.util';
import { isSelfServiceProcurement } from './vendor-crm-buyer.util';

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
  serviceKey: string;
  /** First-class vendor_services.id when linked (additive; nullable). */
  vendorServiceId: string | null;
  /** Human-facing vendor service code (VS-000001). */
  serviceCode: string | null;
  /** Unread conversation messages for the current viewer (participant-scoped). */
  unreadCount: number;
  message: string;
  negotiationId: string | null;
  scheduledAt: string | null;
  scheduledEnd: string | null;
  arrivedAt: string | null;
  completedAt: string | null;
  source: string;
  vendorName: string | null;
  eventTitle: string | null;
  organizerName: string | null;
  buyerKind?: 'organizer' | 'vendor';
  buyerVendorId?: string | null;
  buyerVendorName?: string | null;
  createdAt: string;
  updatedAt: string;
  /** Derived from pipeline stage — not a separate contract store */
  contractStatus: 'draft' | 'pending' | 'accepted' | 'rejected' | 'completed';
  assignmentStatus: 'unassigned' | 'assigned' | 'in_progress' | 'done' | 'closed';
  latestOfferMinor: string | null;
  /**
   * Party-scoped commercial fields.
   * Organizer sees servicePriceMinor (organizer-facing).
   * Vendor sees vendorPayoutMinor only — never organizer price or markup.
   */
  servicePriceMinor?: string | null;
  vendorPayoutMinor?: string | null;
  /** Markup bps snapshotted at request creation (organizer/internal; omitted for vendor audience). */
  pricingMarkupBps?: number | null;
  fundingStatus: string;
  /** Escrow status — prefers funded allocations, else derived from stage. */
  escrowStatus: 'unfunded' | 'pending' | 'funded' | 'released' | 'cancelled' | 'held';
  /** events.external_ref — bridges Event Ops evt_* keys to CRM UUID eventId. */
  eventExternalRef?: string | null;
  /** Resolved from events row + metadata via eventId (not duplicated into the request). */
  eventStartsAt?: string | null;
  eventEndsAt?: string | null;
  eventType?: string | null;
  eventLocation?: string | null;
  expectedAttendees?: number | null;
  eventDescription?: string | null;
  requiredServices?: string[] | null;
  venueName?: string | null;
  venueAddress?: string | null;
  /** Frozen organizer-selected capabilities (from metadata.selectedCapabilities). */
  selectedCapabilities?: SelectedCapability[];
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
    private readonly notifications: NotificationService,
    private readonly domainEvents: DomainEventsService,
    private readonly pricingRules: VendorPricingRulesService,
    private readonly eventFunds: EventVendorFundsService,
    private readonly availability: VendorAvailabilityService,
    @Optional() private readonly vendorServices?: VendorServicesService,
    @Optional() private readonly crmRealtime?: CrmRealtimeBroadcastService,
  ) {}

  /**
   * Phase 3A/3B — publish CRM SSE signal after successful persistence.
   * Never throws; REST remains authoritative if delivery fails.
   */
  private emitCrmRealtime(opts: {
    recipientUserId: string | null | undefined;
    tenantId: string;
    type:
      | 'vendor_request_incoming'
      | 'vendor_request_update'
      | 'vendor_request_message'
      | 'vendor_service_complete';
    requestId: string;
    dedupeKey: string;
    updatedAt?: string;
    eventId?: string;
    vendorId?: string;
    stage?: string;
  }): void {
    if (!this.crmRealtime?.isEnabled() || !opts.recipientUserId) return;
    try {
      this.crmRealtime.publishToUser(opts.recipientUserId, {
        type: opts.type,
        tenantId: opts.tenantId,
        resource: { type: 'vendor_request', id: opts.requestId },
        revision: opts.updatedAt ?? new Date().toISOString(),
        updatedAt: opts.updatedAt ?? new Date().toISOString(),
        dedupeKey: opts.dedupeKey,
        meta: {
          eventId: opts.eventId,
          vendorId: opts.vendorId,
          stage: opts.stage,
        },
      });
    } catch {
      /* delivery must never affect business response */
    }
  }

  private async enqueueInAppNotification(
    tenantId: string,
    userId: string,
    kind: string,
    title: string,
    body: string,
    dedupeKey: string,
    data: Record<string, unknown>,
  ) {
    await this.pool.query(
      `INSERT INTO notifications (tenant_id, user_id, channel, status, kind, title, body, data, dedupe_key, sent_at, delivered_at)
       VALUES ($1, $2, 'in_app', 'delivered', $3, $4, $5, $6::jsonb, $7, now(), now())
       ON CONFLICT (tenant_id, user_id, dedupe_key) DO UPDATE
         SET title = EXCLUDED.title,
             body = EXCLUDED.body,
             data = EXCLUDED.data,
             status = 'delivered',
             updated_at = now()`,
      [tenantId, userId, kind, title, body, JSON.stringify(data), dedupeKey],
    );
  }

  private async resolveOrganizerOwnerUserId(tenantId: string, organizerId: string): Promise<string | null> {
    const { rows } = await this.pool.query<{ owner_user_id: string }>(
      `SELECT owner_user_id FROM organizers WHERE tenant_id = $1 AND id = $2`,
      [tenantId, organizerId],
    );
    return rows[0]?.owner_user_id ?? null;
  }

  private async resolveVendorOwnerUserId(tenantId: string, vendorId: string): Promise<string | null> {
    const { rows } = await this.pool.query<{ owner_user_id: string }>(
      `SELECT owner_user_id FROM vendors WHERE tenant_id = $1 AND id = $2`,
      [tenantId, vendorId],
    );
    return rows[0]?.owner_user_id ?? null;
  }

  private async assertRequestDatesAvailable(
    tenantId: string,
    row: {
      event_id: string;
      vendor_id: string;
      vendor_service_id?: string | null;
      service_key?: string | null;
      service_label?: string | null;
    },
    requestId: string,
  ) {
    const window = await this.availability.eventWindowForId(tenantId, row.event_id);
    if (!window) return;
    const serviceKey = normalizeServiceKey(row.service_key ?? row.service_label);
    await this.availability.assertServiceWindowBookable({
      tenantId,
      vendorId: row.vendor_id,
      vendorServiceId: row.vendor_service_id ?? null,
      serviceKey,
      window,
      offerActive: true,
      excludeRequestId: requestId,
    });
  }

  private async ensureParticipationOnAccept(tenantId: string, vendorId: string, eventId: string) {
    await this.pool.query(
      `INSERT INTO vendor_event_participations (
         tenant_id, vendor_id, event_id, status, booth_label, expected_payout_minor
       ) VALUES ($1, $2, $3, 'approved', 'Vendor village', 25000000)
       ON CONFLICT (vendor_id, event_id) DO UPDATE
         SET status = 'approved', updated_at = now()`,
      [tenantId, vendorId, eventId],
    );
  }

  private assertStage(raw: string): VendorRequestStage {
    if (!VENDOR_REQUEST_STAGES.includes(raw as VendorRequestStage)) {
      throw new BadRequestException({ code: 'INVALID_STAGE', message: 'Unknown pipeline stage' });
    }
    return raw as VendorRequestStage;
  }

  private deriveContractStatus(stage: VendorRequestStage): VendorRequestView['contractStatus'] {
    switch (stage) {
      case 'new':
        return 'draft';
      case 'negotiating':
        return 'pending';
      case 'accepted':
      case 'scheduled':
      case 'arrived':
        return 'accepted';
      case 'declined':
      case 'cancelled':
        return 'rejected';
      case 'completed':
        return 'completed';
    }
  }

  private deriveAssignmentStatus(stage: VendorRequestStage): VendorRequestView['assignmentStatus'] {
    switch (stage) {
      case 'new':
      case 'negotiating':
        return 'unassigned';
      case 'accepted':
        return 'assigned';
      case 'scheduled':
      case 'arrived':
        return 'in_progress';
      case 'completed':
        return 'done';
      case 'declined':
      case 'cancelled':
        return 'closed';
    }
  }

  private deriveEscrowStatus(
    stage: VendorRequestStage,
    fundingStatus?: string | null,
  ): VendorRequestView['escrowStatus'] {
    if (fundingStatus === 'funded') return 'funded';
    if (fundingStatus === 'released') return 'released';
    if (fundingStatus === 'held') return 'held';
    if (fundingStatus === 'reserved') return 'pending';
    switch (stage) {
      case 'new':
      case 'negotiating':
        return 'unfunded';
      case 'accepted':
        return 'pending';
      case 'scheduled':
      case 'arrived':
        return 'funded';
      case 'completed':
        return 'released';
      case 'declined':
      case 'cancelled':
        return 'cancelled';
    }
  }

  private eventContextFromJoin(row: {
    event_starts_at?: Date | null;
    event_ends_at?: Date | null;
    event_metadata?: Record<string, unknown> | null;
  }): Pick<
    VendorRequestView,
    | 'eventStartsAt'
    | 'eventEndsAt'
    | 'eventType'
    | 'eventLocation'
    | 'expectedAttendees'
    | 'eventDescription'
    | 'requiredServices'
    | 'venueName'
    | 'venueAddress'
  > {
    const meta =
      row.event_metadata && typeof row.event_metadata === 'object' ? row.event_metadata : {};
    const venueName = String(meta.venueName ?? meta.venue ?? '').trim() || null;
    const venueAddress = String(meta.venueAddress ?? '').trim() || null;
    const city = String(meta.city ?? '').trim();
    const state = String(meta.state ?? '').trim();
    const locationParts = [venueName, city || state].filter(Boolean);
    const expectedRaw = meta.expectedGuests;
    const expectedAttendees =
      typeof expectedRaw === 'number'
        ? expectedRaw
        : expectedRaw != null && String(expectedRaw).trim() !== ''
          ? Number(expectedRaw)
          : null;
    const required = meta.requiredServices;
    return {
      eventStartsAt: row.event_starts_at?.toISOString?.() ?? null,
      eventEndsAt: row.event_ends_at?.toISOString?.() ?? null,
      eventType: String(meta.category ?? meta.categorySlug ?? '').trim() || null,
      eventLocation: locationParts.length ? locationParts.join(', ') : city || state || null,
      expectedAttendees:
        expectedAttendees != null && Number.isFinite(expectedAttendees)
          ? expectedAttendees
          : null,
      eventDescription: String(meta.description ?? '').trim() || null,
      requiredServices: Array.isArray(required)
        ? required.map((s) => String(s)).filter(Boolean)
        : null,
      venueName,
      venueAddress,
    };
  }

  private rowToView(
    row: {
      id: string;
      event_id: string;
      vendor_id: string;
      organizer_id: string;
      stage: string;
      service_label: string | null;
      service_key?: string | null;
      vendor_service_id?: string | null;
      service_code?: string | null;
      unread_count?: number | string | null;
      message: string;
      negotiation_id: string | null;
      scheduled_at: Date | null;
      scheduled_end: Date | null;
      arrived_at: Date | null;
      completed_at: Date | null;
      source: string;
      vendor_name?: string | null;
      event_title?: string | null;
      organizer_name?: string | null;
      buyer_kind?: string | null;
      buyer_vendor_id?: string | null;
      buyer_vendor_name?: string | null;
      latest_offer_minor?: string | null;
      customer_price_minor?: string | null;
      vendor_payout_minor?: string | null;
      pricing_markup_bps?: number | null;
      funding_status?: string | null;
      event_external_ref?: string | null;
      event_starts_at?: Date | null;
      event_ends_at?: Date | null;
      event_metadata?: Record<string, unknown> | null;
      metadata?: unknown;
      created_at: Date;
      updated_at: Date;
    },
    audience: 'organizer' | 'vendor' | 'neutral' = 'neutral',
  ): VendorRequestView {
    const stage = row.stage as VendorRequestStage;
    const customer = row.customer_price_minor ?? null;
    const payout = row.vendor_payout_minor ?? null;
    const offer = row.latest_offer_minor ?? customer ?? payout ?? null;
    const fundingStatus = row.funding_status ?? 'unfunded';
    const markupBps =
      row.pricing_markup_bps == null || row.pricing_markup_bps === ('' as unknown)
        ? null
        : Number(row.pricing_markup_bps);
    const eventCtx = this.eventContextFromJoin(row);
    const meta =
      row.metadata && typeof row.metadata === 'object' && !Array.isArray(row.metadata)
        ? (row.metadata as Record<string, unknown>)
        : {};
    const base: VendorRequestView = {
      id: row.id,
      eventId: row.event_id,
      vendorId: row.vendor_id,
      organizerId: row.organizer_id,
      stage,
      serviceLabel: row.service_label,
      serviceKey: row.service_key ?? normalizeServiceKey(row.service_label),
      vendorServiceId: row.vendor_service_id ?? null,
      serviceCode: row.service_code ?? null,
      unreadCount: Number(row.unread_count ?? 0),
      message: row.message,
      negotiationId: row.negotiation_id,
      scheduledAt: row.scheduled_at?.toISOString() ?? null,
      scheduledEnd: row.scheduled_end?.toISOString() ?? null,
      arrivedAt: row.arrived_at?.toISOString() ?? null,
      completedAt: row.completed_at?.toISOString() ?? null,
      source: row.source,
      vendorName: row.vendor_name ?? null,
      eventTitle: row.event_title ?? null,
      organizerName: row.organizer_name ?? null,
      buyerKind: row.buyer_kind === 'vendor' ? 'vendor' : 'organizer',
      buyerVendorId: row.buyer_vendor_id ?? null,
      buyerVendorName: row.buyer_vendor_name ?? null,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
      contractStatus: this.deriveContractStatus(stage),
      assignmentStatus: this.deriveAssignmentStatus(stage),
      latestOfferMinor: offer,
      fundingStatus,
      escrowStatus: this.deriveEscrowStatus(stage, fundingStatus),
      eventExternalRef: row.event_external_ref ?? null,
      pricingMarkupBps: markupBps,
      selectedCapabilities: parseSelectedCapabilities(meta.selectedCapabilities),
      ...eventCtx,
    };
    if (audience === 'organizer') {
      return {
        ...base,
        servicePriceMinor: customer ?? offer,
        vendorPayoutMinor: undefined,
      };
    }
    if (audience === 'vendor') {
      return {
        ...base,
        vendorPayoutMinor: payout ?? offer,
        servicePriceMinor: undefined,
        pricingMarkupBps: undefined,
      };
    }
    return base;
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
      buyer_vendor_id?: string | null;
      buyer_kind?: string | null;
    }>(
      `SELECT r.* FROM vendor_event_requests r WHERE r.tenant_id = $1 AND r.id = $2`,
      [tenantId, requestId],
    );
    if (!rows.length) throw new NotFoundException({ code: 'REQUEST_NOT_FOUND', message: 'Vendor request not found' });
    return rows[0]!;
  }

  private async actorRoleOnRequest(
    actor: CommerceActor,
    row: { event_id: string; vendor_id: string; buyer_vendor_id?: string | null },
  ): Promise<'organizer' | 'vendor'> {
    try {
      await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
      return 'organizer';
    } catch {
      const vendorId = await this.access.resolveVendorId(actor.tenantId, actor.userId);
      if (vendorId === row.vendor_id) return 'vendor';
      if (row.buyer_vendor_id && vendorId === row.buyer_vendor_id) return 'organizer';
      throw new ForbiddenException({ code: 'ACCESS_DENIED' });
    }
  }

  private async resolveBuyerNotifyUserId(
    tenantId: string,
    row: { organizer_id: string; buyer_vendor_id?: string | null },
  ): Promise<string | null> {
    if (row.buyer_vendor_id) {
      return this.resolveVendorOwnerUserId(tenantId, row.buyer_vendor_id);
    }
    return this.resolveOrganizerOwnerUserId(tenantId, row.organizer_id);
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
    const event = await this.access.assertEventCapability(
      actor.tenantId,
      actor.userId,
      eventKey,
      'vendors.read',
    );
    const { rows } = await this.pool.query(
      `SELECT r.*, v.business_name AS vendor_name, e.title AS event_title, e.external_ref AS event_external_ref,
              e.starts_at AS event_starts_at, e.ends_at AS event_ends_at, e.metadata AS event_metadata,
              o.display_name AS organizer_name,
              r.buyer_kind, r.buyer_vendor_id, bv.business_name AS buyer_vendor_name,
              vs.service_code AS service_code,
              (
                SELECT o2.amount_minor::text
                FROM vendor_negotiation_offers o2
                WHERE o2.negotiation_id = r.negotiation_id
                ORDER BY o2.created_at DESC
                LIMIT 1
              ) AS latest_offer_minor,
              (
                SELECT COUNT(*)::int
                FROM vendor_request_stage_history h
                WHERE h.request_id = r.id
                  AND h.from_stage IS NOT DISTINCT FROM h.to_stage
                  AND h.note IS NOT NULL AND length(trim(h.note)) > 0
                  AND h.actor_user_id IS DISTINCT FROM $3
                  AND h.created_at > COALESCE(
                    (SELECT last_read_at FROM vendor_request_conversation_reads
                     WHERE request_id = r.id AND user_id = $3),
                    'epoch'::timestamptz
                  )
              ) AS unread_count
       FROM vendor_event_requests r
       JOIN vendors v ON v.id = r.vendor_id
       JOIN events e ON e.id = r.event_id
       JOIN organizers o ON o.id = r.organizer_id
       LEFT JOIN vendors bv ON bv.id = r.buyer_vendor_id
       LEFT JOIN vendor_services vs ON vs.id = r.vendor_service_id
       WHERE r.tenant_id = $1 AND r.event_id = $2
       ORDER BY r.updated_at DESC`,
      [actor.tenantId, event.id, actor.userId],
    );
    const items = rows.map((r) => this.rowToView(r, 'organizer'));
    return { items, stats: this.buildStats(items), insights: this.buildInsights(items) };
  }

  async listForVendor(actor: CommerceActor, vendorId: string) {
    const ownedVendorId = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    if (ownedVendorId !== vendorId) {
      throw new ForbiddenException({ code: 'ACCESS_DENIED', message: 'Not vendor owner' });
    }
    const { rows } = await this.pool.query(
      `SELECT r.*, v.business_name AS vendor_name, e.title AS event_title, e.external_ref AS event_external_ref,
              e.starts_at AS event_starts_at, e.ends_at AS event_ends_at, e.metadata AS event_metadata,
              o.display_name AS organizer_name,
              r.buyer_kind, r.buyer_vendor_id, bv.business_name AS buyer_vendor_name,
              vs.service_code AS service_code,
              (
                SELECT o2.amount_minor::text
                FROM vendor_negotiation_offers o2
                WHERE o2.negotiation_id = r.negotiation_id
                ORDER BY o2.created_at DESC
                LIMIT 1
              ) AS latest_offer_minor,
              (
                SELECT COUNT(*)::int
                FROM vendor_request_stage_history h
                WHERE h.request_id = r.id
                  AND h.from_stage IS NOT DISTINCT FROM h.to_stage
                  AND h.note IS NOT NULL AND length(trim(h.note)) > 0
                  AND h.actor_user_id IS DISTINCT FROM $3
                  AND h.created_at > COALESCE(
                    (SELECT last_read_at FROM vendor_request_conversation_reads
                     WHERE request_id = r.id AND user_id = $3),
                    'epoch'::timestamptz
                  )
              ) AS unread_count
       FROM vendor_event_requests r
       JOIN vendors v ON v.id = r.vendor_id
       JOIN events e ON e.id = r.event_id
       JOIN organizers o ON o.id = r.organizer_id
       LEFT JOIN vendors bv ON bv.id = r.buyer_vendor_id
       LEFT JOIN vendor_services vs ON vs.id = r.vendor_service_id
       WHERE r.tenant_id = $1 AND r.vendor_id = $2
       ORDER BY r.updated_at DESC`,
      [actor.tenantId, vendorId, actor.userId],
    );
    const items = rows.map((r) => this.rowToView(r, 'vendor'));
    return { items, stats: this.buildStats(items), insights: this.buildInsights(items) };
  }

  private buildInsights(items: VendorRequestView[]) {
    const active = items.filter((i) =>
      ['accepted', 'scheduled', 'arrived', 'completed'].includes(i.stage),
    );
    const completed = items.filter((i) => i.stage === 'completed');
    const spend = active.reduce((sum, i) => sum + BigInt(i.latestOfferMinor ?? '0'), 0n);
    const completionPct =
      active.length === 0 ? 0 : Math.round((completed.length / active.length) * 1000) / 10;
    return {
      attachedVendors: items.filter((i) => !['declined', 'cancelled'].includes(i.stage)).length,
      vendorSpendMinor: spend.toString(),
      completedCount: completed.length,
      completionPct,
      negotiatingCount: items.filter((i) => i.stage === 'negotiating').length,
    };
  }

  async getTimeline(actor: CommerceActor, requestId: string) {
    const row = await this.loadRequest(actor.tenantId, requestId);
    let audience: 'organizer' | 'vendor' = await this.actorRoleOnRequest(actor, row);

    const { rows: history } = await this.pool.query<{
      id: string;
      from_stage: string | null;
      to_stage: string;
      actor_type: string;
      note: string | null;
      created_at: Date;
    }>(
      `SELECT id, from_stage, to_stage, actor_type, note, created_at
       FROM vendor_request_stage_history
       WHERE tenant_id = $1 AND request_id = $2
       ORDER BY created_at ASC`,
      [actor.tenantId, requestId],
    );

    let offers: Array<{
      id: string;
      actorType: string;
      amountMinor: string;
      message: string | null;
      status: string;
      createdAt: string;
    }> = [];
    if (row.negotiation_id) {
      const { rows: offerRows } = await this.pool.query<{
        id: string;
        actor_type: string;
        amount_minor: string;
        message: string | null;
        status: string;
        created_at: Date;
      }>(
        `SELECT id, actor_type, amount_minor::text, message, status::text, created_at
         FROM vendor_negotiation_offers
         WHERE negotiation_id = $1
         ORDER BY created_at ASC`,
        [row.negotiation_id],
      );
      offers = offerRows.map((o) => ({
        id: o.id,
        actorType: o.actor_type,
        // Party-scoped amount label lives on the client; never include margin.
        amountMinor: o.amount_minor,
        message: o.message,
        status: o.status,
        createdAt: o.created_at.toISOString(),
      }));
    }

    const { rows: named } = await this.pool.query<{
      vendor_name: string | null;
      event_title: string | null;
      organizer_name: string | null;
      event_external_ref: string | null;
      event_starts_at: Date | null;
      event_ends_at: Date | null;
      event_metadata: Record<string, unknown> | null;
    }>(
      `SELECT v.business_name AS vendor_name, e.title AS event_title, e.external_ref AS event_external_ref,
              e.starts_at AS event_starts_at, e.ends_at AS event_ends_at, e.metadata AS event_metadata,
              o.display_name AS organizer_name,
              r.buyer_kind, r.buyer_vendor_id, bv.business_name AS buyer_vendor_name,
              vs.service_code AS service_code
       FROM vendor_event_requests r
       JOIN vendors v ON v.id = r.vendor_id
       JOIN events e ON e.id = r.event_id
       JOIN organizers o ON o.id = r.organizer_id
       LEFT JOIN vendors bv ON bv.id = r.buyer_vendor_id
       LEFT JOIN vendor_services vs ON vs.id = r.vendor_service_id
       WHERE r.id = $1`,
      [requestId],
    );

    const view = this.rowToView(
      {
        ...row,
        vendor_name: named[0]?.vendor_name,
        event_title: named[0]?.event_title,
        organizer_name: named[0]?.organizer_name,
        event_external_ref: named[0]?.event_external_ref,
        event_starts_at: named[0]?.event_starts_at,
        event_ends_at: named[0]?.event_ends_at,
        event_metadata: named[0]?.event_metadata,
        service_code: (named[0] as { service_code?: string | null } | undefined)?.service_code,
        latest_offer_minor: offers.length ? offers[offers.length - 1]!.amountMinor : null,
      },
      audience,
    );

    await this.pool.query(
      `INSERT INTO vendor_request_conversation_reads (tenant_id, request_id, user_id, last_read_at)
       VALUES ($1, $2, $3, now())
       ON CONFLICT (request_id, user_id) DO UPDATE SET
         last_read_at = now(),
         updated_at = now()`,
      [actor.tenantId, requestId, actor.userId],
    );

    return {
      request: { ...view, unreadCount: 0 },
      history: history.map((h) => ({
        id: h.id,
        fromStage: h.from_stage,
        toStage: h.to_stage,
        actorType: h.actor_type,
        note: h.note,
        createdAt: h.created_at.toISOString(),
      })),
      offers,
      contractStatus: view.contractStatus,
      assignmentStatus: view.assignmentStatus,
      escrowStatus: view.escrowStatus,
    };
  }

  async createRequest(actor: CommerceActor, eventKey: string, body: Record<string, unknown>) {
    return this.createRequestWithBuyer(actor, eventKey, body, 'organizer');
  }

  async createVendorBuyerRequest(actor: CommerceActor, eventKey: string, body: Record<string, unknown>) {
    return this.createRequestWithBuyer(actor, eventKey, body, 'vendor');
  }

  async listOutgoingForVendor(actor: CommerceActor, vendorId: string) {
    const owned = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    if (owned !== vendorId) {
      throw new ForbiddenException({ code: 'ACCESS_DENIED', message: 'Not vendor owner' });
    }
    const { rows } = await this.pool.query(
      `SELECT r.*, v.business_name AS vendor_name, e.title AS event_title, e.external_ref AS event_external_ref,
              e.starts_at AS event_starts_at, e.ends_at AS event_ends_at, e.metadata AS event_metadata,
              o.display_name AS organizer_name,
              r.buyer_kind, r.buyer_vendor_id, bv.business_name AS buyer_vendor_name,
              vs.service_code AS service_code,
              (
                SELECT o2.amount_minor::text
                FROM vendor_negotiation_offers o2
                WHERE o2.negotiation_id = r.negotiation_id
                ORDER BY o2.created_at DESC
                LIMIT 1
              ) AS latest_offer_minor,
              0 AS unread_count
       FROM vendor_event_requests r
       JOIN vendors v ON v.id = r.vendor_id
       JOIN events e ON e.id = r.event_id
       JOIN organizers o ON o.id = r.organizer_id
       LEFT JOIN vendors bv ON bv.id = r.buyer_vendor_id
       LEFT JOIN vendor_services vs ON vs.id = r.vendor_service_id
       WHERE r.tenant_id = $1 AND r.buyer_vendor_id = $2::uuid
       ORDER BY r.updated_at DESC`,
      [actor.tenantId, vendorId],
    );
    const items = rows.map((r) => this.rowToView(r, 'organizer'));
    return { items, stats: this.buildStats(items), insights: this.buildInsights(items) };
  }

  private async createRequestWithBuyer(
    actor: CommerceActor,
    eventKey: string,
    body: Record<string, unknown>,
    mode: 'organizer' | 'vendor',
  ) {
    let event: Awaited<ReturnType<EventsAccessService['resolveEventRow']>>;
    let organizerId: string;
    let buyerVendorId: string | null = null;
    if (mode === 'organizer') {
      event = await this.access.assertEventCapability(
        actor.tenantId,
        actor.userId,
        eventKey,
        'vendors.read',
      );
      organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    } else {
      const assoc = await this.access.assertVendorAssociatedWithEvent(
        actor.tenantId,
        actor.userId,
        eventKey,
      );
      event = assoc.event;
      organizerId = event.organizer_id;
      buyerVendorId = assoc.vendorId;
    }
    const vendorId = String(body.vendorId ?? '').trim();
    if (!vendorId) throw new BadRequestException({ code: 'VENDOR_REQUIRED', message: 'vendorId required' });
    const uuidRe =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRe.test(vendorId)) {
      throw new BadRequestException({
        code: 'VENDOR_ID_INVALID',
        message: 'vendorId must be a vendors.id UUID (canonical Vendor Identity)',
      });
    }

    const { rows: vendorRows } = await this.pool.query(
      `SELECT id FROM vendors WHERE tenant_id = $1 AND id = $2 AND owner_user_id IS NOT NULL`,
      [actor.tenantId, vendorId],
    );
    if (!vendorRows.length) throw new NotFoundException({ code: 'VENDOR_NOT_FOUND', message: 'Vendor not found' });
    if (mode === 'vendor' && buyerVendorId && isSelfServiceProcurement(buyerVendorId, vendorId)) {
      throw new ForbiddenException({
        code: 'SELF_PROCUREMENT_FORBIDDEN',
        message: 'A vendor cannot request its own service',
      });
    }

    const message = String(body.message ?? '');
    let serviceLabel = body.serviceLabel ? String(body.serviceLabel) : null;
    let serviceKey = normalizeServiceKey(
      body.serviceKey ? String(body.serviceKey) : serviceLabel,
    );
    let vendorServiceId: string | null = body.vendorServiceId
      ? String(body.vendorServiceId).trim()
      : null;

    if (vendorServiceId) {
      const vsRow = this.vendorServices
        ? await this.vendorServices.getById(actor.tenantId, vendorId, vendorServiceId)
        : null;
      if (!vsRow) {
        throw new BadRequestException({
          code: 'VENDOR_SERVICE_INVALID',
          message: 'vendorServiceId does not belong to this vendor',
        });
      }
      if (vsRow.status !== 'active') {
        throw new UnprocessableEntityException({
          code: 'VENDOR_SERVICE_INACTIVE',
          message: 'This service is not accepting new requests',
        });
      }
      serviceKey = vsRow.serviceKey;
      if (!serviceLabel) serviceLabel = vsRow.serviceName;
    } else {
      if (!serviceKey || serviceKey === 'general') {
        throw new BadRequestException({
          code: 'VENDOR_SERVICE_REQUIRED',
          message: 'Select an active vendor service before sending a request',
        });
      }
      if (!this.vendorServices) {
        throw new BadRequestException({
          code: 'VENDOR_SERVICE_REQUIRED',
          message: 'Select an active vendor service before sending a request',
        });
      }
      const ensured = await this.vendorServices.ensureForBooking(
        actor.tenantId,
        vendorId,
        serviceKey,
        serviceLabel,
      );
      if (!ensured) {
        throw new BadRequestException({
          code: 'VENDOR_SERVICE_REQUIRED',
          message: 'Select an active vendor service before sending a request',
        });
      }
      if (ensured.status !== 'active') {
        throw new UnprocessableEntityException({
          code: 'VENDOR_SERVICE_INACTIVE',
          message: 'This service is not accepting new requests',
        });
      }
      vendorServiceId = ensured.id;
      const vsRow = await this.vendorServices.getById(actor.tenantId, vendorId, vendorServiceId);
      if (vsRow && !serviceLabel) serviceLabel = vsRow.serviceName;
      if (vsRow) serviceKey = vsRow.serviceKey;
    }

    const vsForCaps = vendorServiceId && this.vendorServices
      ? await this.vendorServices.getById(actor.tenantId, vendorId, vendorServiceId)
      : null;
    const selectedIn = parseSelectedCapabilities(body.selectedCapabilities);
    let capabilitySnapshot: SelectedCapability[] = [];
    if (vsForCaps && this.vendorServices) {
      const adminMap = await this.vendorServices.allowedCapabilityKeys(
        actor.tenantId,
        vsForCaps.serviceKey,
        vsForCaps.serviceName,
      );
      const adminEnabled = [...adminMap.entries()].map(([key, label]) => ({
        key,
        label,
        enabled: true,
        // Intersection uses enabled ∩ provided only; tier is Admin catalogue metadata.
        tier: 'core' as const,
      }));
      const allowed = allowedCapabilitySet(adminEnabled, parseVendorCapabilities(vsForCaps.capabilities));
      const validated = validateSelectedCapabilities(selectedIn, allowed);
      if (!validated.ok) {
        throw new BadRequestException({
          code: 'CAPABILITY_INVALID',
          message: 'One or more selected capabilities are not provided for this service',
          invalidKeys: validated.invalidKeys,
        });
      }
      capabilitySnapshot = validated.snapshot;
    } else if (selectedIn.length > 0) {
      throw new BadRequestException({
        code: 'CAPABILITY_INVALID',
        message: 'Capabilities cannot be selected without an active vendor service',
      });
    }

    const eventWindow = await this.availability.eventWindowForId(actor.tenantId, event.id);
    if (eventWindow) {
      await this.availability.assertServiceWindowBookable({
        tenantId: actor.tenantId,
        vendorId,
        vendorServiceId,
        serviceKey,
        window: eventWindow,
        offerActive: true,
      });
    }

    let stage: VendorRequestStage = 'new';

    // Resolve listed commercial snapshot (vendor base → markup → organizer price).
    let snapshotCustomer: bigint | null = null;
    let snapshotPayout: bigint | null = null;
    let snapshotMargin: bigint | null = null;
    let snapshotMarkupBps: number | null = null;

    if (body.amountMinor != null) {
      const amount = BigInt(String(body.amountMinor));
      const markupBps = await this.pricingRules.resolveMarkupBps(
        actor.tenantId,
        serviceKey,
        vendorId,
      );
      const split = vendorPayoutFromCustomerPrice(amount, markupBps);
      snapshotCustomer = amount;
      snapshotPayout = split.vendorPayoutMinor;
      snapshotMargin = split.platformMarginMinor;
      snapshotMarkupBps = markupBps;
    } else if (this.vendorServices) {
      const resolved = await this.vendorServices.resolveBasePayoutMinor(actor.tenantId, vendorId, {
        vendorServiceId,
        serviceKey,
        serviceName: serviceLabel,
      });
      if (resolved && resolved.basePayoutMinor > 0) {
        const payout = BigInt(resolved.basePayoutMinor);
        const markupBps = await this.pricingRules.resolveMarkupBps(
          actor.tenantId,
          serviceKey,
          vendorId,
        );
        const split = customerPriceFromVendorPayout(payout, markupBps);
        snapshotPayout = payout;
        snapshotCustomer = split.customerPriceMinor;
        snapshotMargin = split.platformMarginMinor;
        snapshotMarkupBps = markupBps;
        if (!vendorServiceId && resolved.vendorServiceId) {
          vendorServiceId = resolved.vendorServiceId;
        }
      }
    }

    const conflictSql =
      mode === 'organizer'
        ? `ON CONFLICT (event_id, vendor_id, service_key) DO UPDATE
         SET message = EXCLUDED.message,
             service_label = COALESCE(EXCLUDED.service_label, vendor_event_requests.service_label),
             vendor_service_id = COALESCE(
               EXCLUDED.vendor_service_id,
               vendor_event_requests.vendor_service_id
             ),
             customer_price_minor = COALESCE(
               EXCLUDED.customer_price_minor,
               vendor_event_requests.customer_price_minor
             ),
             vendor_payout_minor = COALESCE(
               EXCLUDED.vendor_payout_minor,
               vendor_event_requests.vendor_payout_minor
             ),
             platform_margin_minor = COALESCE(
               EXCLUDED.platform_margin_minor,
               vendor_event_requests.platform_margin_minor
             ),
             pricing_markup_bps = COALESCE(
               EXCLUDED.pricing_markup_bps,
               vendor_event_requests.pricing_markup_bps
             ),
             metadata = vendor_event_requests.metadata || EXCLUDED.metadata,
             updated_at = now()`
        : `ON CONFLICT (event_id, vendor_id, service_key) DO NOTHING`;

    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO vendor_event_requests (
         tenant_id, event_id, vendor_id, organizer_id, stage, service_label, service_key,
         vendor_service_id, message, source,
         customer_price_minor, vendor_payout_minor, platform_margin_minor, pricing_markup_bps,
         metadata, buyer_kind, buyer_vendor_id
       ) VALUES (
         $1, $2, $3, $4, 'new', $5, $6, $7, $8, $9,
         $10::bigint, $11::bigint, $12::bigint, $13,
         $14::jsonb, $15, $16::uuid
       )
       ${conflictSql}
       RETURNING id`,
      [
        actor.tenantId,
        event.id,
        vendorId,
        organizerId,
        serviceLabel,
        serviceKey,
        vendorServiceId,
        message,
        String(body.source ?? 'marketplace'),
        snapshotCustomer?.toString() ?? null,
        snapshotPayout?.toString() ?? null,
        snapshotMargin?.toString() ?? null,
        snapshotMarkupBps,
        JSON.stringify({ selectedCapabilities: capabilitySnapshot }),
        mode === 'vendor' ? 'vendor' : 'organizer',
        buyerVendorId,
      ],
    );
    if (!rows[0]) {
      throw new UnprocessableEntityException({
        code: 'REQUEST_EXISTS',
        message: 'A request for this vendor service already exists on this event',
      });
    }
    const requestId = rows[0]!.id;

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
      { requestId, stage, vendorId, eventId: event.id, correlationId: requestId },
    );

    const vendorOwnerId = await this.resolveVendorOwnerUserId(actor.tenantId, vendorId);
    if (vendorOwnerId) {
      const eventTitle = event.title ?? 'your event';
      await this.enqueueInAppNotification(
        actor.tenantId,
        vendorOwnerId,
        'vendor_request_incoming',
        'Incoming vendor request',
        `New request for ${eventTitle}${serviceLabel ? ` · ${serviceLabel}` : ''}`,
        `vendor_request:${requestId}:new`,
        { requestId, eventId: event.id, vendorId, stage },
      );
      await this.notifications.send({
        tenantId: actor.tenantId,
        channel: 'push',
        template: 'vendor_request_incoming',
        recipient: vendorOwnerId,
        body: `New vendor request for ${eventTitle}`,
        metadata: { requestId, eventId: event.id },
      });
      this.emitCrmRealtime({
        recipientUserId: vendorOwnerId,
        tenantId: actor.tenantId,
        type: 'vendor_request_incoming',
        requestId,
        dedupeKey: `vendor_request:${requestId}:new`,
        eventId: event.id,
        vendorId,
        stage: 'new',
      });
    }

    if (mode === 'vendor' && buyerVendorId) {
      return this.listOutgoingForVendor(actor, buyerVendorId);
    }
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

    const actorType = await this.actorRoleOnRequest(actor, row);

    // Ownership: organizer creates/withdraws/operates post-accept; vendor alone accepts/declines.
    // Negotiation is out of scope for this phase (status may exist historically).
    if (toStage === 'negotiating') {
      throw new ForbiddenException({
        code: 'NEGOTIATION_DISABLED',
        message: 'Price negotiation is not available for this request flow',
      });
    }
    if (actorType === 'organizer') {
      if (toStage === 'accepted' || toStage === 'declined') {
        throw new ForbiddenException({
          code: 'ORGANIZER_CANNOT_DECIDE',
          message: 'Only the vendor can accept or decline this request',
        });
      }
      const organizerAllowed: VendorRequestStage[] = ['cancelled', 'scheduled', 'arrived', 'completed'];
      if (!organizerAllowed.includes(toStage)) {
        throw new ForbiddenException({
          code: 'ORGANIZER_STAGE_DENIED',
          message: 'Organizer cannot set this stage',
        });
      }
    } else {
      const vendorAllowed: VendorRequestStage[] = ['accepted', 'declined', 'arrived', 'completed'];
      if (!vendorAllowed.includes(toStage)) {
        throw new ForbiddenException({
          code: 'VENDOR_STAGE_DENIED',
          message: 'Vendor cannot set this stage',
        });
      }
    }

    const scheduledAt = body.scheduledAt ? new Date(String(body.scheduledAt)) : null;
    const scheduledEnd = body.scheduledEnd ? new Date(String(body.scheduledEnd)) : null;

    let start: Date | null = scheduledAt ?? row.scheduled_at;
    let end: Date | null = scheduledEnd ?? row.scheduled_end;

    if (toStage === 'accepted') {
      await this.assertRequestDatesAvailable(actor.tenantId, row, requestId);
    }

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

    if (toStage === 'accepted') {
      await this.ensureParticipationOnAccept(actor.tenantId, row.vendor_id, row.event_id);
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
      vendorId: row.vendor_id,
      correlationId: requestId,
    });

    const organizerOwnerId = await this.resolveBuyerNotifyUserId(actor.tenantId, row);
    const vendorOwnerId = await this.resolveVendorOwnerUserId(actor.tenantId, row.vendor_id);
    const notifyUserId = actorType === 'vendor' ? organizerOwnerId : vendorOwnerId;
    if (notifyUserId) {
      const title = actorType === 'vendor' ? 'Vendor responded' : 'Organizer updated request';
      const bodyText = `${feedHeadline}${body.note ? ` — ${String(body.note)}` : ''}`;
      await this.enqueueInAppNotification(
        actor.tenantId,
        notifyUserId,
        'vendor_request_update',
        title,
        bodyText,
        `vendor_request:${requestId}:${toStage}:${actorType}`,
        { requestId, fromStage, toStage, eventId: row.event_id, vendorId: row.vendor_id },
      );
      await this.notifications.send({
        tenantId: actor.tenantId,
        channel: 'push',
        template: 'vendor_request_update',
        recipient: notifyUserId,
        body: bodyText,
        metadata: { requestId, toStage },
      });
      this.emitCrmRealtime({
        recipientUserId: notifyUserId,
        tenantId: actor.tenantId,
        type: 'vendor_request_update',
        requestId,
        dedupeKey: `vendor_request:${requestId}:${toStage}:${actorType}`,
        eventId: row.event_id,
        vendorId: row.vendor_id,
        stage: toStage,
      });
    }

    this.domainEvents.emit(DOMAIN_EVENTS.VENDOR_STAGE_CHANGED, {
      tenantId: actor.tenantId,
      organizerId: row.organizer_id,
      eventId: row.event_id,
      entityId: requestId,
      actorUserId: actor.userId,
      data: {
        fromStage,
        toStage,
        vendorId: row.vendor_id,
        summary: `Vendor request ${fromStage} → ${toStage}`,
      },
    });

    if (actorType === 'vendor') {
      return this.listForVendor(actor, row.vendor_id);
    }
    return this.listAfterBuyerMutation(actor, row);
  }

  private async listAfterBuyerMutation(
    actor: CommerceActor,
    row: { event_id: string; vendor_id: string; buyer_vendor_id?: string | null },
  ) {
    try {
      return await this.listForEvent(actor, row.event_id);
    } catch {
      if (row.buyer_vendor_id) {
        return this.listOutgoingForVendor(actor, row.buyer_vendor_id);
      }
      throw new ForbiddenException({ code: 'ACCESS_DENIED' });
    }
  }

  async patchRequest(actor: CommerceActor, requestId: string, body: Record<string, unknown>) {
    const row = await this.loadRequest(actor.tenantId, requestId);
    const role = await this.actorRoleOnRequest(actor, row);
    if (role !== 'organizer') throw new ForbiddenException({ code: 'ACCESS_DENIED' });

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
      const vendorOwnerId = await this.resolveVendorOwnerUserId(actor.tenantId, row.vendor_id);
      this.emitCrmRealtime({
        recipientUserId: vendorOwnerId,
        tenantId: actor.tenantId,
        type: 'vendor_request_update',
        requestId,
        dedupeKey: `vendor_request:${requestId}:patch:${Date.now()}`,
        eventId: row.event_id,
        vendorId: row.vendor_id,
        stage: row.stage,
      });
    }
    const event = await this.access.resolveEventRow(actor.tenantId, row.event_id);
    return this.listForEvent(actor, event.id);
  }

  async counterOffer(_actor: CommerceActor, _requestId: string, _body: Record<string, unknown>) {
    throw new ForbiddenException({
      code: 'NEGOTIATION_DISABLED',
      message: 'Price negotiation is not available for this request flow',
    });
  }

  /** Organizer confirms agreed terms (customer-facing). Does not credit vendor wallet. */
  async confirmAgreement(actor: CommerceActor, requestId: string) {
    const row = await this.loadRequest(actor.tenantId, requestId);
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    const fromStage = row.stage as VendorRequestStage;
    if (!['new', 'negotiating', 'accepted'].includes(fromStage)) {
      throw new UnprocessableEntityException({
        code: 'INVALID_TRANSITION',
        message: `Cannot confirm agreement from ${fromStage}`,
      });
    }
    if (!(row as { customer_price_minor?: string | null }).customer_price_minor &&
        !(row as { vendor_payout_minor?: string | null }).vendor_payout_minor) {
      throw new BadRequestException({
        code: 'PRICE_REQUIRED',
        message: 'Negotiate a price before confirming agreement',
      });
    }
    if (fromStage !== 'accepted') {
      await this.assertRequestDatesAvailable(actor.tenantId, row, requestId);
    }
    await this.pool.query(
      `UPDATE vendor_event_requests
       SET stage = 'accepted',
           agreement_confirmed_at = now(),
           updated_at = now()
       WHERE tenant_id = $1 AND id = $2`,
      [actor.tenantId, requestId],
    );
    await this.writeHistory(
      actor.tenantId,
      requestId,
      fromStage,
      'accepted',
      'organizer',
      actor.userId,
      'Agreement confirmed',
    );
    await this.ensureParticipationOnAccept(actor.tenantId, row.vendor_id, row.event_id);
    const vendorOwnerId = await this.resolveVendorOwnerUserId(actor.tenantId, row.vendor_id);
    this.emitCrmRealtime({
      recipientUserId: vendorOwnerId,
      tenantId: actor.tenantId,
      type: 'vendor_request_update',
      requestId,
      dedupeKey: `vendor_request:${requestId}:agreement_confirmed`,
      eventId: row.event_id,
      vendorId: row.vendor_id,
      stage: 'accepted',
    });
    return this.listForEvent(actor, row.event_id);
  }

  async markServiceComplete(actor: CommerceActor, requestId: string) {
    const row = await this.loadRequest(actor.tenantId, requestId);
    const vendorId = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    if (vendorId !== row.vendor_id) throw new ForbiddenException({ code: 'ACCESS_DENIED' });
    await this.pool.query(
      `UPDATE vendor_event_requests
       SET completion_requested_at = now(), stage = 'arrived', updated_at = now()
       WHERE tenant_id = $1 AND id = $2`,
      [actor.tenantId, requestId],
    );
    await this.writeHistory(
      actor.tenantId,
      requestId,
      row.stage,
      'arrived',
      'vendor',
      actor.userId,
      'Service marked complete — awaiting organizer confirmation',
    );
    const organizerOwnerId = await this.resolveOrganizerOwnerUserId(actor.tenantId, row.organizer_id);
    if (organizerOwnerId) {
      await this.enqueueInAppNotification(
        actor.tenantId,
        organizerOwnerId,
        'vendor_service_complete',
        'Vendor marked service complete',
        `${row.service_label ?? 'Vendor'} is awaiting your confirmation`,
        `vendor_request:${requestId}:complete_req`,
        { requestId, eventId: row.event_id },
      );
      this.emitCrmRealtime({
        recipientUserId: organizerOwnerId,
        tenantId: actor.tenantId,
        type: 'vendor_service_complete',
        requestId,
        dedupeKey: `vendor_request:${requestId}:complete_req`,
        eventId: row.event_id,
        vendorId: row.vendor_id,
        stage: 'arrived',
      });
    }
    return this.listForVendor(actor, row.vendor_id);
  }

  async confirmServiceCompletion(actor: CommerceActor, requestId: string) {
    const row = await this.loadRequest(actor.tenantId, requestId);
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    await this.eventFunds.releaseOnCompletion(actor, requestId);
    await this.pool.query(
      `UPDATE vendor_event_requests
       SET stage = 'completed', completed_at = now(), updated_at = now()
       WHERE tenant_id = $1 AND id = $2`,
      [actor.tenantId, requestId],
    );
    await this.writeHistory(
      actor.tenantId,
      requestId,
      row.stage,
      'completed',
      'organizer',
      actor.userId,
      'Organizer confirmed completion — escrow release initiated',
    );
    const vendorOwnerId = await this.resolveVendorOwnerUserId(actor.tenantId, row.vendor_id);
    this.emitCrmRealtime({
      recipientUserId: vendorOwnerId,
      tenantId: actor.tenantId,
      type: 'vendor_request_update',
      requestId,
      dedupeKey: `vendor_request:${requestId}:completed:organizer`,
      eventId: row.event_id,
      vendorId: row.vendor_id,
      stage: 'completed',
    });
    return this.listForEvent(actor, row.event_id);
  }

  async reportServiceIssue(actor: CommerceActor, requestId: string, body: Record<string, unknown>) {
    const row = await this.loadRequest(actor.tenantId, requestId);
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    const note = String(body.note ?? body.message ?? 'Issue reported').trim();
    await this.eventFunds.holdOnIssue(actor, requestId);
    await this.writeHistory(
      actor.tenantId,
      requestId,
      row.stage,
      row.stage,
      'organizer',
      actor.userId,
      `Issue reported: ${note}`,
    );
    await this.writeFeed(
      actor.tenantId,
      row.event_id,
      'Vendor service issue reported',
      note,
      { requestId, correlationId: requestId },
    );
    const vendorOwnerId = await this.resolveVendorOwnerUserId(actor.tenantId, row.vendor_id);
    this.emitCrmRealtime({
      recipientUserId: vendorOwnerId,
      tenantId: actor.tenantId,
      type: 'vendor_request_update',
      requestId,
      dedupeKey: `vendor_request:${requestId}:issue:${Date.now()}`,
      eventId: row.event_id,
      vendorId: row.vendor_id,
      stage: row.stage,
    });
    return this.listForEvent(actor, row.event_id);
  }

  async postMessage(actor: CommerceActor, requestId: string, body: Record<string, unknown>) {
    const row = await this.loadRequest(actor.tenantId, requestId);
    const message = String(body.message ?? '').trim();
    if (!message) throw new BadRequestException({ code: 'MESSAGE_REQUIRED', message: 'message required' });

    // Conversation opens only after the vendor accepts (service-specific request thread).
    const messagingStages: VendorRequestStage[] = ['accepted', 'scheduled', 'arrived'];
    if (!messagingStages.includes(row.stage as VendorRequestStage)) {
      throw new UnprocessableEntityException({
        code: 'CONVERSATION_NOT_AVAILABLE',
        message:
          row.stage === 'completed'
            ? 'This request is completed; conversation is read-only'
            : 'Conversation opens only after the vendor accepts this request',
      });
    }

    const bypass = detectPlatformBypass(message);
    if (bypass.blocked) {
      throw new UnprocessableEntityException({
        code: 'PLATFORM_BYPASS_BLOCKED',
        message: bypass.reason,
      });
    }

    const actorType = await this.actorRoleOnRequest(actor, row);

    await this.writeHistory(
      actor.tenantId,
      requestId,
      row.stage,
      row.stage,
      actorType,
      actor.userId,
      message,
    );
    await this.writeFeed(
      actor.tenantId,
      row.event_id,
      `${actorType === 'vendor' ? 'Vendor' : 'Organizer'} message`,
      message,
      { requestId, actorType, correlationId: requestId },
    );

    const recipientId =
      actorType === 'vendor'
        ? await this.resolveOrganizerOwnerUserId(actor.tenantId, row.organizer_id)
        : await this.resolveVendorOwnerUserId(actor.tenantId, row.vendor_id);
    if (recipientId) {
      const dedupeKey = `vendor_request:${requestId}:msg:${Date.now()}`;
      await this.enqueueInAppNotification(
        actor.tenantId,
        recipientId,
        'vendor_request_message',
        'New vendor request message',
        message,
        dedupeKey,
        { requestId, actorType, eventId: row.event_id },
      );
      this.emitCrmRealtime({
        recipientUserId: recipientId,
        tenantId: actor.tenantId,
        type: 'vendor_request_message',
        requestId,
        dedupeKey,
        eventId: row.event_id,
        vendorId: row.vendor_id,
        stage: row.stage,
      });
    }

    if (actorType === 'vendor') {
      return this.listForVendor(actor, row.vendor_id);
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
