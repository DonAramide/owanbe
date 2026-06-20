import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';

@Injectable()
export class AdminOrganizersService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
  ) {}

  async list(tenantId: string, query?: string, status?: string) {
    const params: unknown[] = [tenantId];
    let where = 'WHERE o.tenant_id = $1';
    if (status && status !== 'all') {
      params.push(status);
      where += ` AND o.status::text = $${params.length}`;
    }
    if (query?.trim()) {
      params.push(`%${query.trim().toLowerCase()}%`);
      where += ` AND (lower(o.display_name) LIKE $${params.length} OR lower(o.slug) LIKE $${params.length})`;
    }
    const { rows } = await this.pool.query<{
      id: string;
      display_name: string;
      slug: string;
      status: string;
      owner_user_id: string;
      event_count: string;
      revenue_minor: string;
    }>(
      `SELECT o.id, o.display_name, o.slug, o.status::text, o.owner_user_id,
              (SELECT COUNT(*)::text FROM events e WHERE e.organizer_id = o.id) AS event_count,
              COALESCE((
                SELECT SUM(tol.quantity * tol.unit_price_minor)::text
                FROM ticket_order_lines tol
                INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
                WHERE tord.organizer_id = o.id AND tord.status IN ('fulfilled', 'confirmed')
              ), '0') AS revenue_minor
       FROM organizers o
       ${where}
       ORDER BY o.created_at DESC
       LIMIT 200`,
      params,
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        displayName: r.display_name,
        slug: r.slug,
        status: r.status,
        ownerUserId: r.owner_user_id,
        eventCount: Number(r.event_count),
        revenueMinor: r.revenue_minor,
      })),
    };
  }

  async getDetail(tenantId: string, organizerId: string) {
    const org = await this.getOrganizer(tenantId, organizerId);
    const [events, revenue, payouts, incidents] = await Promise.all([
      this.pool.query(
        `SELECT id, external_ref, title, status::text, starts_at
         FROM events WHERE tenant_id = $1 AND organizer_id = $2 ORDER BY starts_at DESC LIMIT 50`,
        [tenantId, organizerId],
      ),
      this.organizerRevenue(tenantId, organizerId),
      this.pool.query(
        `SELECT id, amount_minor::text, status::text, created_at
         FROM organizer_payouts WHERE tenant_id = $1 AND organizer_id = $2 ORDER BY created_at DESC LIMIT 50`,
        [tenantId, organizerId],
      ),
      this.pool.query(
        `SELECT ei.id, ei.title, ei.status::text, ei.created_at, e.title AS event_title
         FROM event_incidents ei
         INNER JOIN events e ON e.id = ei.event_id
         WHERE ei.tenant_id = $1 AND e.organizer_id = $2
         ORDER BY ei.created_at DESC LIMIT 50`,
        [tenantId, organizerId],
      ),
    ]);
    return {
      profile: {
        id: org.id,
        displayName: org.display_name,
        slug: org.slug,
        status: org.status,
        ownerUserId: org.owner_user_id,
        createdAt: org.created_at.toISOString(),
      },
      events: events.rows.map((e) => ({
        id: e.external_ref ?? e.id,
        eventId: e.id,
        title: e.title,
        status: e.status,
        startsAt: e.starts_at.toISOString(),
      })),
      revenue,
      payouts: payouts.rows.map((p) => ({
        id: p.id,
        amountMinor: p.amount_minor,
        status: p.status,
        createdAt: p.created_at.toISOString(),
      })),
      incidents: incidents.rows.map((i) => ({
        id: i.id,
        title: i.title,
        status: i.status,
        eventTitle: i.event_title,
        createdAt: i.created_at.toISOString(),
      })),
    };
  }

  async setStatus(
    tenantId: string,
    actorUserId: string,
    organizerId: string,
    status: 'suspended' | 'active',
  ) {
    const org = await this.getOrganizer(tenantId, organizerId);
    await this.pool.query(
      `UPDATE organizers SET status = $3::organizer_status, updated_at = now() WHERE id = $1 AND tenant_id = $2`,
      [organizerId, tenantId, status],
    );
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: status === 'suspended' ? 'organizer_suspended' : 'organizer_reactivated',
      resourceType: 'organizer',
      resourceId: organizerId,
      metadata: { previousStatus: org.status, displayName: org.display_name },
    });
    return { ok: true, status };
  }

  private async organizerRevenue(tenantId: string, organizerId: string) {
    const { rows } = await this.pool.query<{ ticket_minor: string; booking_minor: string }>(
      `SELECT
         COALESCE((
           SELECT SUM(tol.quantity * tol.unit_price_minor)::text
           FROM ticket_order_lines tol
           INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
           WHERE tord.tenant_id = $1 AND tord.organizer_id = $2 AND tord.status IN ('fulfilled', 'confirmed')
         ), '0') AS ticket_minor,
         COALESCE((
           SELECT SUM(p.amount_captured_minor)::text
           FROM payments p
           INNER JOIN bookings b ON b.id = p.booking_id
           WHERE p.tenant_id = $1 AND b.vendor_id IN (
             SELECT v.id FROM vendors v WHERE v.owner_user_id = (SELECT owner_user_id FROM organizers WHERE id = $2)
           ) AND p.status::text IN ('captured', 'partially_refunded', 'refunded')
         ), '0') AS booking_minor`,
      [tenantId, organizerId],
    );
    const r = rows[0]!;
    return {
      ticketRevenueMinor: r.ticket_minor,
      bookingRevenueMinor: r.booking_minor,
      totalMinor: String(BigInt(r.ticket_minor) + BigInt(r.booking_minor)),
    };
  }

  private async getOrganizer(tenantId: string, organizerId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      display_name: string;
      slug: string;
      status: string;
      owner_user_id: string;
      created_at: Date;
    }>(
      `SELECT id, display_name, slug, status::text, owner_user_id, created_at
       FROM organizers WHERE tenant_id = $1 AND id = $2`,
      [tenantId, organizerId],
    );
    if (!rows[0]) throw new NotFoundException({ code: 'ORGANIZER_NOT_FOUND', message: 'Organizer not found' });
    return rows[0];
  }
}
