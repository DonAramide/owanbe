import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

const RANGE_DAYS: Record<string, number> = {
  '7d': 7,
  '30d': 30,
  '90d': 90,
  '365d': 365,
};

@Injectable()
export class SuperAdminAnalyticsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getAnalytics(range = '30d') {
    const days = RANGE_DAYS[range] ?? 30;
    const { rows } = await this.pool.query<{
      revenue_minor: string;
      prev_revenue_minor: string;
      events: string;
      prev_events: string;
      vendors: string;
      prev_vendors: string;
      attendees: string;
      prev_attendees: string;
    }>(
      `WITH bounds AS (
         SELECT now() AS end_at, now() - ($1::int || ' days')::interval AS start_at,
                now() - ($1::int * 2 || ' days')::interval AS prev_start_at
       ),
       cur_rev AS (
         SELECT COALESCE(SUM(tol.quantity * tol.unit_price_minor), 0)::bigint AS minor
         FROM ticket_order_lines tol
         INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id, bounds b
         WHERE tord.status IN ('fulfilled', 'confirmed') AND tord.created_at >= b.start_at
       ),
       prev_rev AS (
         SELECT COALESCE(SUM(tol.quantity * tol.unit_price_minor), 0)::bigint AS minor
         FROM ticket_order_lines tol
         INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id, bounds b
         WHERE tord.status IN ('fulfilled', 'confirmed')
           AND tord.created_at >= b.prev_start_at AND tord.created_at < b.start_at
       )
       SELECT
         (SELECT minor::text FROM cur_rev) AS revenue_minor,
         (SELECT minor::text FROM prev_rev) AS prev_revenue_minor,
         (SELECT COUNT(*)::text FROM events e, bounds b WHERE e.created_at >= b.start_at) AS events,
         (SELECT COUNT(*)::text FROM events e, bounds b
           WHERE e.created_at >= b.prev_start_at AND e.created_at < b.start_at) AS prev_events,
         (SELECT COUNT(*)::text FROM vendors v, bounds b WHERE v.created_at >= b.start_at) AS vendors,
         (SELECT COUNT(*)::text FROM vendors v, bounds b
           WHERE v.created_at >= b.prev_start_at AND v.created_at < b.start_at) AS prev_vendors,
         (SELECT COUNT(*)::text FROM ticket_entitlements te, bounds b WHERE te.issued_at >= b.start_at) AS attendees,
         (SELECT COUNT(*)::text FROM ticket_entitlements te, bounds b
           WHERE te.issued_at >= b.prev_start_at AND te.issued_at < b.start_at) AS prev_attendees`,
      [days],
    );
    const s = rows[0]!;
    return {
      range,
      days,
      revenueGrowth: this.growthPct(s.revenue_minor, s.prev_revenue_minor),
      eventGrowth: this.growthPct(s.events, s.prev_events),
      vendorGrowth: this.growthPct(s.vendors, s.prev_vendors),
      attendeeGrowth: this.growthPct(s.attendees, s.prev_attendees),
      current: {
        revenueMinor: s.revenue_minor,
        events: Number(s.events),
        vendors: Number(s.vendors),
        attendees: Number(s.attendees),
      },
      previous: {
        revenueMinor: s.prev_revenue_minor,
        events: Number(s.prev_events),
        vendors: Number(s.prev_vendors),
        attendees: Number(s.prev_attendees),
      },
    };
  }

  private growthPct(current: string, previous: string): number {
    const c = Number(current);
    const p = Number(previous);
    if (p === 0) return c > 0 ? 100 : 0;
    return Math.round(((c - p) / p) * 1000) / 10;
  }
}
