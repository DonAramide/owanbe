import { Injectable, Inject, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';
import { RealtimeBroadcastService } from '../../integrations/realtime/realtime-broadcast.service';

/** Extract ticket_code from OWANBE QR payloads or return raw input. */
export function resolveDoorTicketCode(raw?: string | null): string | undefined {
  const value = raw?.trim();
  if (!value) return undefined;
  if (/^OWANBE:/i.test(value)) {
    const parts = value.split(':').map((p) => p.trim()).filter(Boolean);
    // OWANBE:{eventId}:{tierOrInvitation}:{ticketCode}
    if (parts.length >= 4) return parts[parts.length - 1];
    if (parts.length === 3) return parts[2];
  }
  return value;
}

function isUuid(value?: string | null): boolean {
  if (!value) return false;
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

@Injectable()
export class EventOperationsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly realtime: RealtimeBroadcastService,
  ) {}

  async listCheckIns(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows: checked } = await this.pool.query<{
      id: string;
      entitlement_id: string | null;
      ticket_code: string;
      holder_name: string;
      tier_name: string;
      checked_in_at: Date;
      source: string;
    }>(
      `SELECT id, entitlement_id, ticket_code, holder_name, tier_name, checked_in_at, source
       FROM event_check_ins WHERE tenant_id = $1 AND event_id = $2 ORDER BY checked_in_at DESC`,
      [actor.tenantId, event.id],
    );

    const { rows: pending } = await this.pool.query<{
      id: string;
      ticket_code: string;
      tier_name: string;
      holder_email: string | null;
      guest_name: string | null;
      source: string | null;
      issued_at: Date;
    }>(
      `SELECT te.id, te.ticket_code,
              COALESCE(te.metadata->>'tier_name', 'General') AS tier_name,
              u.email AS holder_email,
              te.metadata->>'guestName' AS guest_name,
              te.metadata->>'source' AS source,
              te.issued_at
       FROM ticket_entitlements te
       LEFT JOIN users u ON u.id = te.holder_user_id
       WHERE te.tenant_id = $1 AND te.event_id = $2 AND te.status = 'issued'
       ORDER BY te.issued_at ASC`,
      [actor.tenantId, event.id],
    );

    return {
      checkedIn: checked.map((r) => ({
        id: r.entitlement_id ?? r.id,
        ticketId: r.ticket_code,
        name: r.holder_name,
        tierName: r.tier_name,
        checkedIn: true,
        checkedInAt: r.checked_in_at.toISOString(),
        source: r.source,
        doorStatus: 'inside',
        entitlementStatus: 'checked_in',
      })),
      pending: pending.map((r) => ({
        id: r.id,
        ticketId: r.ticket_code,
        name: r.guest_name || r.holder_email || 'Guest',
        tierName: r.tier_name,
        checkedIn: false,
        source: r.source ?? undefined,
        doorStatus: 'registered',
        entitlementStatus: 'issued',
        issuedAt: r.issued_at.toISOString(),
      })),
    };
  }

  /**
   * Live door KPIs from entitlements + tier capacity + recent check-ins.
   */
  async doorSummary(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);

    const { rows: counts } = await this.pool.query<{
      issued: string;
      checked_in: string;
      voided: string;
      refunded: string;
    }>(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'issued')::text AS issued,
         COUNT(*) FILTER (WHERE status = 'checked_in')::text AS checked_in,
         COUNT(*) FILTER (WHERE status = 'voided')::text AS voided,
         COUNT(*) FILTER (WHERE status = 'refunded')::text AS refunded
       FROM ticket_entitlements
       WHERE tenant_id = $1 AND event_id = $2`,
      [actor.tenantId, event.id],
    );

    const { rows: inv } = await this.pool.query<{ remaining: string; capacity: string }>(
      `SELECT COALESCE(SUM(remaining), 0)::text AS remaining,
              COALESCE(SUM(capacity), 0)::text AS capacity
       FROM event_ticket_tiers
       WHERE tenant_id = $1 AND event_id = $2
         AND COALESCE((metadata->>'archived')::boolean, false) = false`,
      [actor.tenantId, event.id],
    );

    const { rows: throughput } = await this.pool.query<{ last_15m: string; last_60m: string }>(
      `SELECT
         COUNT(*) FILTER (WHERE checked_in_at >= now() - interval '15 minutes')::text AS last_15m,
         COUNT(*) FILTER (WHERE checked_in_at >= now() - interval '60 minutes')::text AS last_60m
       FROM event_check_ins
       WHERE tenant_id = $1 AND event_id = $2`,
      [actor.tenantId, event.id],
    );

    const { rows: recent } = await this.pool.query<{
      ticket_code: string;
      holder_name: string;
      tier_name: string;
      source: string;
      checked_in_at: Date;
    }>(
      `SELECT ticket_code, holder_name, tier_name, source, checked_in_at
       FROM event_check_ins
       WHERE tenant_id = $1 AND event_id = $2
       ORDER BY checked_in_at DESC
       LIMIT 12`,
      [actor.tenantId, event.id],
    );

    const issued = parseInt(counts[0]?.issued ?? '0', 10);
    const checkedIn = parseInt(counts[0]?.checked_in ?? '0', 10);
    const totalActive = issued + checkedIn;
    const tierCapacity = parseInt(inv[0]?.capacity ?? '0', 10);
    const capacity = tierCapacity > 0 ? tierCapacity : totalActive;
    const remaining = issued;
    const noShows = issued;
    const attendancePct = totalActive === 0 ? 0 : Math.round((checkedIn / totalActive) * 1000) / 10;
    const capacityPct = capacity === 0 ? 0 : Math.round((checkedIn / capacity) * 1000) / 10;
    const checkInsLast15m = parseInt(throughput[0]?.last_15m ?? '0', 10);
    const checkInsLast60m = parseInt(throughput[0]?.last_60m ?? '0', 10);
    const queueState =
      checkInsLast15m >= 40 ? 'heavy' : checkInsLast15m >= 15 ? 'busy' : checkInsLast15m >= 1 ? 'steady' : 'quiet';

    return {
      checkedIn,
      remaining,
      capacity,
      noShows,
      attendancePct,
      capacityPct,
      totalActive,
      issued,
      voided: parseInt(counts[0]?.voided ?? '0', 10),
      refunded: parseInt(counts[0]?.refunded ?? '0', 10),
      checkInsLast15m,
      checkInsLast60m,
      checkInThroughputPerHour: checkInsLast60m,
      queueState,
      eventStatus: event.status ?? 'published',
      recentArrivals: recent.map((r) => ({
        ticketCode: r.ticket_code,
        name: r.holder_name,
        tierName: r.tier_name,
        source: r.source,
        checkedInAt: r.checked_in_at.toISOString(),
      })),
    };
  }

  async checkIn(
    actor: CommerceActor,
    eventKey: string,
    body: { ticketCode?: string; entitlementId?: string; source?: string },
  ) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const rawEntitlementId = body.entitlementId?.trim() || undefined;
    const entitlementId = isUuid(rawEntitlementId) ? rawEntitlementId : undefined;
    const rawTicketInput = body.ticketCode?.trim() || (!entitlementId ? rawEntitlementId : undefined);
    const ticketCode = resolveDoorTicketCode(rawTicketInput);
    if (!ticketCode && !entitlementId) {
      throw new UnprocessableEntityException({
        code: 'TICKET_REQUIRED',
        message: 'ticketCode or entitlementId required',
      });
    }

    const ent = await this.pool.query<{
      id: string;
      ticket_code: string;
      status: string;
      holder_user_id: string | null;
      metadata: Record<string, unknown> | null;
    }>(
      `SELECT te.id, te.ticket_code, te.status::text, te.holder_user_id, te.metadata
       FROM ticket_entitlements te
       WHERE te.tenant_id = $1 AND te.event_id = $2
         AND (
           ($3::uuid IS NOT NULL AND te.id = $3::uuid)
           OR ($4::text IS NOT NULL AND lower(te.ticket_code) = lower($4::text))
           OR ($5::text IS NOT NULL AND lower(COALESCE(te.metadata->>'qr_payload', '')) = lower($5::text))
         )
       LIMIT 1`,
      [
        actor.tenantId,
        event.id,
        entitlementId ?? null,
        ticketCode ?? null,
        rawTicketInput ?? null,
      ],
    );
    const row = ent.rows[0];
    const source = body.source ?? 'manual';

    if (!row) {
      await this.appendFeed(actor.tenantId, event.id, 'check_in_invalid', 'Invalid ticket attempt', ticketCode ?? entitlementId ?? 'unknown', {
        source,
      });
      throw new NotFoundException({ code: 'TICKET_NOT_FOUND', message: 'Ticket not recognized' });
    }

    if (row.status === 'checked_in') {
      await this.appendFeed(
        actor.tenantId,
        event.id,
        'check_in_duplicate',
        `Duplicate check-in: ${row.ticket_code}`,
        `${source}`,
        { source, ticketCode: row.ticket_code },
      );
      return {
        ok: true,
        duplicate: true,
        ticketCode: row.ticket_code,
        holderName: await this.resolveHolderName(row),
        tierName: String(row.metadata?.tier_name ?? 'General'),
        entitlementStatus: 'checked_in',
        doorStatus: 'inside',
      };
    }

    if (row.status === 'voided' || row.status === 'refunded') {
      await this.appendFeed(
        actor.tenantId,
        event.id,
        'check_in_invalid',
        `Cancelled ticket: ${row.ticket_code}`,
        `status=${row.status} · ${source}`,
        { source, ticketCode: row.ticket_code, status: row.status },
      );
      throw new UnprocessableEntityException({
        code: 'TICKET_CANCELLED',
        message: `Ticket is ${row.status} and cannot be checked in`,
      });
    }

    if (row.status !== 'issued') {
      await this.appendFeed(
        actor.tenantId,
        event.id,
        'check_in_invalid',
        `Invalid ticket: ${row.ticket_code}`,
        `status=${row.status} · ${source}`,
        { source, ticketCode: row.ticket_code, status: row.status },
      );
      throw new UnprocessableEntityException({
        code: 'TICKET_INVALID',
        message: `Ticket status: ${row.status}`,
      });
    }

    const holderName = await this.resolveHolderName(row);
    const tierName = String(row.metadata?.tier_name ?? 'General');
    const inviteArrival = String(row.metadata?.source ?? '') === 'invitation';
    const feedType = inviteArrival ? 'invitation_arrival' : 'guest_checked_in';
    const headline = inviteArrival ? `${holderName} arrived (invitation)` : `${holderName} checked in`;

    await this.pool.query('BEGIN');
    try {
      await this.pool.query(
        `UPDATE ticket_entitlements SET status = 'checked_in', checked_in_at = now() WHERE id = $1`,
        [row.id],
      );
      await this.pool.query(
        `INSERT INTO event_check_ins (
           tenant_id, event_id, entitlement_id, ticket_code, holder_name, tier_name,
           checked_in_by_user_id, source
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (event_id, ticket_code) DO NOTHING`,
        [actor.tenantId, event.id, row.id, row.ticket_code, holderName, tierName, actor.userId, source],
      );
      await this.pool.query(
        `INSERT INTO event_feed_items (tenant_id, event_id, feed_type, headline, detail)
         VALUES ($1, $2, $3, $4, $5)`,
        [actor.tenantId, event.id, feedType, headline, `${tierName} · ${source}`],
      );
      await this.pool.query('COMMIT');
    } catch (e) {
      await this.pool.query('ROLLBACK');
      throw e;
    }
    this.realtime.publish({
      tenantId: actor.tenantId,
      eventId: event.id,
      feedType,
      headline,
      detail: `${tierName} · ${source}`,
      timestamp: new Date().toISOString(),
    });
    return {
      ok: true,
      ticketCode: row.ticket_code,
      holderName,
      tierName,
      entitlementStatus: 'checked_in',
      doorStatus: 'inside',
      invitation: inviteArrival,
    };
  }

  async listIncidents(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      id: string;
      title: string;
      category: string;
      priority: string;
      status: string;
      reporter: string;
      description: string;
      created_at: Date;
    }>(
      `SELECT id, title, category::text, priority::text, status::text, reporter, description, created_at
       FROM event_incidents WHERE tenant_id = $1 AND event_id = $2 ORDER BY created_at DESC`,
      [actor.tenantId, event.id],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        title: r.title,
        category: r.category,
        priority: r.priority,
        status: r.status,
        reporter: r.reporter,
        description: r.description,
        createdAt: r.created_at.toISOString(),
      })),
    };
  }

  async createIncident(
    actor: CommerceActor,
    eventKey: string,
    body: { title: string; category?: string; priority?: string; reporter?: string; description?: string },
  ) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO event_incidents (tenant_id, event_id, title, category, priority, reporter, description)
       VALUES ($1, $2, $3, $4::event_incident_category, $5::event_incident_priority, $6, $7)
       RETURNING id`,
      [
        actor.tenantId,
        event.id,
        body.title,
        body.category ?? 'other',
        body.priority ?? 'medium',
        body.reporter ?? actor.email ?? 'staff',
        body.description ?? '',
      ],
    );
    await this.appendFeed(actor.tenantId, event.id, 'incident_logged', `Incident: ${body.title}`, body.category ?? 'other');
    return { id: rows[0]!.id };
  }

  async updateIncidentStatus(
    actor: CommerceActor,
    eventKey: string,
    incidentId: string,
    status: string,
  ) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const normalized = status === 'investigating' ? 'escalated' : status;
    if (!['open', 'resolved', 'escalated'].includes(normalized)) {
      throw new UnprocessableEntityException({
        code: 'INCIDENT_STATUS_INVALID',
        message: 'status must be open, investigating/escalated, or resolved',
      });
    }
    const { rows } = await this.pool.query<{
      id: string;
      title: string;
      category: string;
      priority: string;
      status: string;
      reporter: string;
      description: string;
      created_at: Date;
    }>(
      `UPDATE event_incidents
       SET status = $4::event_incident_status
       WHERE tenant_id = $1 AND event_id = $2 AND id = $3
       RETURNING id, title, category::text, priority::text, status::text, reporter, description, created_at`,
      [actor.tenantId, event.id, incidentId, normalized],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'INCIDENT_NOT_FOUND', message: 'Incident not found' });
    }
    await this.appendFeed(
      actor.tenantId,
      event.id,
      'incident_updated',
      `Incident ${normalized}: ${row.title}`,
      row.category,
    );
    return {
      id: row.id,
      title: row.title,
      category: row.category,
      priority: row.priority,
      status: row.status,
      reporter: row.reporter,
      description: row.description,
      createdAt: row.created_at.toISOString(),
    };
  }

  async listFeed(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      id: string;
      feed_type: string;
      headline: string;
      detail: string;
      created_at: Date;
    }>(
      `SELECT id, feed_type, headline, detail, created_at
       FROM event_feed_items WHERE tenant_id = $1 AND event_id = $2 ORDER BY created_at DESC LIMIT 200`,
      [actor.tenantId, event.id],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        type: r.feed_type,
        headline: r.headline,
        detail: r.detail,
        timestamp: r.created_at.toISOString(),
      })),
    };
  }

  /**
   * Attendee-safe live updates — program / schedule / venue / alert feed items only.
   * Does not require organizer ownership (Phase 7).
   */
  async listLiveUpdatesForAttendees(tenantId: string, eventKey: string) {
    const event = await this.access.resolveEventRow(tenantId, eventKey, true);
    const { rows } = await this.pool.query<{
      id: string;
      feed_type: string;
      headline: string;
      detail: string;
      created_at: Date;
    }>(
      `SELECT id, feed_type, headline, detail, created_at
       FROM event_feed_items
       WHERE tenant_id = $1 AND event_id = $2
         AND (
           feed_type LIKE 'program_%'
           OR feed_type IN (
             'announcement', 'schedule_change', 'venue_change', 'speaker_update',
             'emergency', 'alert', 'live_alert', 'general'
           )
         )
       ORDER BY created_at DESC
       LIMIT 80`,
      [tenantId, event.id],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        type: r.feed_type,
        headline: r.headline,
        detail: r.detail,
        timestamp: r.created_at.toISOString(),
        severity: this.severityForFeedType(r.feed_type),
      })),
    };
  }

  private async resolveHolderName(row: {
    holder_user_id: string | null;
    metadata: Record<string, unknown> | null;
  }): Promise<string> {
    const guestName = row.metadata?.guestName;
    if (typeof guestName === 'string' && guestName.trim()) return guestName.trim();
    if (!row.holder_user_id) return 'Guest';
    const holder = await this.pool.query<{ email: string; display_name: string | null }>(
      `SELECT email, display_name FROM users WHERE id = $1`,
      [row.holder_user_id],
    );
    return holder.rows[0]?.display_name ?? holder.rows[0]?.email ?? 'Guest';
  }

  private async appendFeed(
    tenantId: string,
    eventId: string,
    feedType: string,
    headline: string,
    detail: string,
    _meta?: Record<string, unknown>,
  ) {
    await this.pool.query(
      `INSERT INTO event_feed_items (tenant_id, event_id, feed_type, headline, detail)
       VALUES ($1, $2, $3, $4, $5)`,
      [tenantId, eventId, feedType, headline, detail],
    );
    this.realtime.publish({
      tenantId,
      eventId,
      feedType,
      headline,
      detail,
      timestamp: new Date().toISOString(),
    });
  }

  private severityForFeedType(type: string): 'info' | 'warning' | 'critical' {
    const t = type.toLowerCase();
    if (t.includes('emergency') || t === 'critical') return 'critical';
    if (t.includes('alert') || t.includes('delayed') || t.includes('change') || t.includes('invalid') || t.includes('duplicate')) {
      return 'warning';
    }
    return 'info';
  }
}
