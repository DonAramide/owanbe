import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';

@Injectable()
export class OrganizerPortalService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  async getMe(actor: CommerceActor) {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    const { rows } = await this.pool.query<{
      id: string;
      display_name: string;
      slug: string;
      status: string;
    }>(
      `SELECT id, display_name, slug, status::text FROM organizers WHERE id = $1`,
      [organizerId],
    );
    const o = rows[0]!;
    return {
      id: o.id,
      displayName: o.display_name,
      slug: o.slug,
      status: o.status,
      ownerUserId: actor.userId,
    };
  }

  async getMyEvents(actor: CommerceActor) {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    const { rows } = await this.pool.query<{
      id: string;
      external_ref: string | null;
      title: string;
      status: string;
      starts_at: Date;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, external_ref, title, status::text, starts_at, metadata
       FROM events WHERE tenant_id = $1 AND organizer_id = $2 ORDER BY created_at DESC`,
      [actor.tenantId, organizerId],
    );
    return {
      items: rows.map((r) => ({
        id: r.external_ref ?? r.id,
        eventId: r.id,
        title: r.title,
        status: r.status,
        startsAt: r.starts_at.toISOString(),
        city: String(r.metadata?.city ?? ''),
      })),
    };
  }

  async getDashboard(actor: CommerceActor) {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    const stats = await this.pool.query<{
      active_events: string;
      upcoming_events: string;
      tickets_sold: string;
      revenue_minor: string;
      vendor_count: string;
      attendee_count: string;
    }>(
      `WITH ev AS (
         SELECT id, status::text FROM events WHERE tenant_id = $1 AND organizer_id = $2
       ),
       sales AS (
         SELECT COALESCE(SUM(tol.quantity), 0)::text AS tickets_sold,
                COALESCE(SUM(tol.quantity * ett.price_minor), 0)::text AS revenue_minor
         FROM ticket_order_lines tol
         INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
         INNER JOIN event_ticket_tiers ett ON ett.event_id = tord.event_id
           AND ett.external_tier_id = tol.tier_id
         WHERE tord.tenant_id = $1 AND tord.organizer_id = $2
           AND tord.status IN ('fulfilled', 'confirmed')
       ),
       parts AS (
         SELECT COUNT(*)::text AS vendor_count FROM vendor_event_participations vep
         INNER JOIN ev ON ev.id = vep.event_id
         WHERE vep.tenant_id = $1 AND vep.status IN ('approved', 'live', 'completed')
       ),
       att AS (
         SELECT COUNT(*)::text AS attendee_count FROM ticket_entitlements te
         INNER JOIN ev ON ev.id = te.event_id
         WHERE te.tenant_id = $1 AND te.status IN ('issued', 'checked_in')
       )
       SELECT
         (SELECT COUNT(*)::text FROM ev WHERE status IN ('published', 'live')) AS active_events,
         (SELECT COUNT(*)::text FROM ev WHERE status IN ('draft', 'published')) AS upcoming_events,
         (SELECT tickets_sold FROM sales),
         (SELECT revenue_minor FROM sales),
         (SELECT vendor_count FROM parts),
         (SELECT attendee_count FROM att)`,
      [actor.tenantId, organizerId],
    );
    const s = stats.rows[0]!;
    return {
      activeEvents: Number(s.active_events),
      upcomingEvents: Number(s.upcoming_events),
      ticketsSold: Number(s.tickets_sold),
      revenueMinor: s.revenue_minor,
      vendorCount: Number(s.vendor_count),
      attendeeCount: Number(s.attendee_count),
    };
  }
}
