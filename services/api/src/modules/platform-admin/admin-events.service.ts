import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';

@Injectable()
export class AdminEventsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
  ) {}

  async list(tenantId: string, query?: string, status?: string) {
    const params: unknown[] = [tenantId];
    let where = 'WHERE e.tenant_id = $1';
    if (status && status !== 'all') {
      params.push(status);
      where += ` AND e.status::text = $${params.length}`;
    }
    if (query?.trim()) {
      params.push(`%${query.trim().toLowerCase()}%`);
      where += ` AND (lower(e.title) LIKE $${params.length} OR lower(e.external_ref) LIKE $${params.length})`;
    }
    const { rows } = await this.pool.query<{
      id: string;
      external_ref: string | null;
      title: string;
      status: string;
      starts_at: Date;
      organizer_name: string;
      tickets_sold: string;
    }>(
      `SELECT e.id, e.external_ref, e.title, e.status::text, e.starts_at,
              o.display_name AS organizer_name,
              COALESCE((
                SELECT SUM(tol.quantity)::text FROM ticket_order_lines tol
                INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
                WHERE tord.event_id = e.id AND tord.status IN ('fulfilled', 'confirmed')
              ), '0') AS tickets_sold
       FROM events e
       INNER JOIN organizers o ON o.id = e.organizer_id
       ${where}
       ORDER BY e.starts_at DESC
       LIMIT 200`,
      params,
    );
    return {
      items: rows.map((r) => ({
        id: r.external_ref ?? r.id,
        eventId: r.id,
        title: r.title,
        status: r.status,
        startsAt: r.starts_at.toISOString(),
        organizerName: r.organizer_name,
        ticketsSold: Number(r.tickets_sold),
      })),
    };
  }

  async getDetail(tenantId: string, eventKey: string) {
    const event = await this.resolveEvent(tenantId, eventKey);
    const [finance, operations, vendors, attendees] = await Promise.all([
      this.eventFinance(tenantId, event.id),
      this.eventOperations(tenantId, event.id),
      this.eventVendors(tenantId, event.id),
      this.eventAttendees(tenantId, event.id),
    ]);
    const health = this.computeHealth(operations.openIncidents, operations.checkInRate);
    return {
      overview: {
        id: event.external_ref ?? event.id,
        eventId: event.id,
        title: event.title,
        status: event.status,
        startsAt: event.starts_at.toISOString(),
        endsAt: event.ends_at?.toISOString() ?? null,
        organizerName: event.organizer_name,
        city: event.metadata?.city ?? '',
        venue: event.metadata?.venue ?? '',
      },
      health,
      finance,
      operations,
      vendors,
      attendees,
    };
  }

  async forceClose(tenantId: string, actorUserId: string, eventKey: string) {
    const event = await this.resolveEvent(tenantId, eventKey);
    await this.pool.query(
      `UPDATE events SET status = 'completed', updated_at = now() WHERE id = $1 AND tenant_id = $2`,
      [event.id, tenantId],
    );
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: 'event_force_closed',
      resourceType: 'event',
      resourceId: event.id,
      metadata: { title: event.title, previousStatus: event.status },
    });
    return { ok: true, status: 'completed' };
  }

  private async eventFinance(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query<{ revenue_minor: string; orders: string }>(
      `SELECT COALESCE(SUM(tol.quantity * tol.unit_price_minor), 0)::text AS revenue_minor,
              COUNT(DISTINCT tord.id)::text AS orders
       FROM ticket_order_lines tol
       INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
       WHERE tord.tenant_id = $1 AND tord.event_id = $2 AND tord.status IN ('fulfilled', 'confirmed')`,
      [tenantId, eventId],
    );
    return {
      ticketRevenueMinor: rows[0]?.revenue_minor ?? '0',
      fulfilledOrders: Number(rows[0]?.orders ?? 0),
    };
  }

  private async eventOperations(tenantId: string, eventId: string) {
    const [checkIns, incidents, feed] = await Promise.all([
      this.pool.query<{ total: string; checked: string }>(
        `SELECT
           (SELECT COUNT(*)::text FROM ticket_entitlements WHERE tenant_id = $1 AND event_id = $2 AND status IN ('issued', 'checked_in')) AS total,
           (SELECT COUNT(*)::text FROM event_check_ins WHERE tenant_id = $1 AND event_id = $2) AS checked`,
        [tenantId, eventId],
      ),
      this.pool.query(
        `SELECT id, title, status::text, priority::text, created_at FROM event_incidents
         WHERE tenant_id = $1 AND event_id = $2 ORDER BY created_at DESC LIMIT 20`,
        [tenantId, eventId],
      ),
      this.pool.query(
        `SELECT id, feed_type, headline, detail, created_at FROM event_feed_items
         WHERE tenant_id = $1 AND event_id = $2 ORDER BY created_at DESC LIMIT 30`,
        [tenantId, eventId],
      ),
    ]);
    const total = Number(checkIns.rows[0]?.total ?? 0);
    const checked = Number(checkIns.rows[0]?.checked ?? 0);
    const openIncidents = incidents.rows.filter((i) => i.status === 'open').length;
    return {
      checkInRate: total === 0 ? 0 : checked / total,
      checkedIn: checked,
      registered: total,
      openIncidents,
      incidents: incidents.rows.map((i) => ({
        id: i.id,
        title: i.title,
        status: i.status,
        priority: i.priority,
        createdAt: i.created_at.toISOString(),
      })),
      feed: feed.rows.map((f) => ({
        id: f.id,
        type: f.feed_type,
        headline: f.headline,
        detail: f.detail,
        timestamp: f.created_at.toISOString(),
      })),
    };
  }

  private async eventVendors(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query(
      `SELECT vep.id, vep.status::text, v.business_name, vep.booth_label
       FROM vendor_event_participations vep
       INNER JOIN vendors v ON v.id = vep.vendor_id
       WHERE vep.tenant_id = $1 AND vep.event_id = $2
       ORDER BY vep.created_at DESC`,
      [tenantId, eventId],
    );
    return rows.map((r) => ({
      id: r.id,
      businessName: r.business_name,
      status: r.status,
      boothLabel: r.booth_label,
    }));
  }

  private async eventAttendees(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query(
      `SELECT te.id, te.ticket_code, te.status::text, u.email, u.display_name
       FROM ticket_entitlements te
       INNER JOIN users u ON u.id = te.holder_user_id
       WHERE te.tenant_id = $1 AND te.event_id = $2
       ORDER BY te.issued_at DESC LIMIT 100`,
      [tenantId, eventId],
    );
    return rows.map((r) => ({
      id: r.id,
      ticketCode: r.ticket_code,
      status: r.status,
      name: r.display_name ?? r.email,
      email: r.email,
    }));
  }

  private computeHealth(openIncidents: number, checkInRate: number) {
    if (openIncidents > 3) return { level: 'critical', summary: `${openIncidents} open incidents` };
    if (openIncidents > 0) return { level: 'warning', summary: `${openIncidents} open incident(s)` };
    if (checkInRate > 0 && checkInRate < 0.2) return { level: 'warning', summary: 'Low check-in rate' };
    return { level: 'healthy', summary: 'Event health nominal' };
  }

  private async resolveEvent(tenantId: string, eventKey: string) {
    const { rows } = await this.pool.query<{
      id: string;
      external_ref: string | null;
      title: string;
      status: string;
      starts_at: Date;
      ends_at: Date | null;
      metadata: Record<string, unknown>;
      organizer_name: string;
    }>(
      `SELECT e.id, e.external_ref, e.title, e.status::text, e.starts_at, e.ends_at, e.metadata,
              o.display_name AS organizer_name
       FROM events e
       INNER JOIN organizers o ON o.id = e.organizer_id
       WHERE e.tenant_id = $1
         AND (e.id::text = $2 OR e.external_ref = $2 OR e.slug = $2)
       LIMIT 1`,
      [tenantId, eventKey],
    );
    if (!rows[0]) throw new NotFoundException({ code: 'EVENT_NOT_FOUND', message: 'Event not found' });
    return rows[0];
  }
}
