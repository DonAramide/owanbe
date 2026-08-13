import { Injectable, Inject, forwardRef } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { OrganizerFinanceService } from '../commerce/organizer-finance.service';
import { EventsAccessService } from './events-access.service';
import { sqlOrganizerOwnerOrMember } from './organizer-access.sql';

export type AnalyticsPeriod = 'daily' | 'weekly' | 'monthly';

/**
 * Phase 18 — read-only Event Intelligence.
 * Composes orders, entitlements, check-ins, invitations, and finance tables.
 * Never invents metrics (e.g. page views) when instrumentation does not exist.
 * Phase 25: monetary KPIs consume OrganizerFinanceService (finance owns truth).
 */
@Injectable()
export class OrganizerAnalyticsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    @Inject(forwardRef(() => OrganizerFinanceService))
    private readonly finance: OrganizerFinanceService,
  ) {}

  async getEventIntelligence(actor: CommerceActor, eventKey: string, days = 30) {
    const event = await this.access.assertEventCapability(
      actor.tenantId,
      actor.userId,
      eventKey,
      'analytics.read',
    );
    const windowDays = Math.min(Math.max(days, 1), 90);

    const sales = await this.salesSnapshot(actor.tenantId, event.id);
    const attendance = await this.attendanceSnapshot(actor.tenantId, event.id);
    const invitations = await this.invitationSnapshot(actor.tenantId, event.id);
    const finance = await this.financeSnapshotFromFinance(actor, eventKey);
    const series = await this.seriesBundle(actor.tenantId, event.id, windowDays);
    const tiers = await this.tierPerformance(actor.tenantId, event.id);
    const intelligence = this.deriveIntelligence(sales, attendance, series, tiers);

    return {
      eventId: event.id,
      eventTitle: event.title,
      organizerId: event.organizer_id,
      generatedAt: new Date().toISOString(),
      /** Explicitly unavailable — no page-view instrumentation */
      pageViews: null as null,
      pageViewsAvailable: false,
      trafficSourcesAvailable: false,
      sales,
      attendance,
      invitations,
      finance,
      series,
      tiers,
      intelligence,
    };
  }

  async getPortfolio(actor: CommerceActor) {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    await this.access.assertOrgCapability(actor.tenantId, actor.userId, organizerId, 'analytics.read');
    const { rows: orgs } = await this.pool.query<{ id: string }>(
      `SELECT id FROM organizers o
       WHERE o.tenant_id = $1 AND o.status = 'active'
         AND ${sqlOrganizerOwnerOrMember('$2')}`,
      [actor.tenantId, actor.userId],
    );
    const orgIds = orgs.map((o) => o.id);
    if (orgIds.length === 0) {
      return { items: [], totals: this.emptyPortfolioTotals() };
    }

    const { rows } = await this.pool.query<{
      event_id: string;
      title: string;
      status: string;
      starts_at: Date | null;
      tickets_sold: string;
      revenue_minor: string;
      checked_in: string;
      issued: string;
    }>(
      `SELECT e.id AS event_id, e.title, e.status::text, e.starts_at,
              (
                SELECT COUNT(*)::text FROM ticket_entitlements te
                WHERE te.tenant_id = e.tenant_id AND te.event_id = e.id
                  AND te.status::text IN ('issued', 'checked_in')
              ) AS tickets_sold,
              (
                SELECT COALESCE(SUM(o.subtotal_minor), 0)::text FROM ticket_orders o
                WHERE o.tenant_id = e.tenant_id AND o.event_id = e.id
                  AND o.status::text IN ('fulfilled', 'confirmed')
              ) AS revenue_minor,
              (
                SELECT COUNT(*)::text FROM ticket_entitlements te
                WHERE te.tenant_id = e.tenant_id AND te.event_id = e.id AND te.status = 'checked_in'
              ) AS checked_in,
              (
                SELECT COUNT(*)::text FROM ticket_entitlements te
                WHERE te.tenant_id = e.tenant_id AND te.event_id = e.id AND te.status = 'issued'
              ) AS issued
       FROM events e
       WHERE e.tenant_id = $1 AND e.organizer_id = ANY($2::uuid[])
       ORDER BY COALESCE(e.starts_at, e.created_at) DESC
       LIMIT 50`,
      [actor.tenantId, orgIds],
    );

    const items = rows.map((r) => {
      const sold = parseInt(r.tickets_sold, 10);
      const checkedIn = parseInt(r.checked_in, 10);
      const issued = parseInt(r.issued, 10);
      const registered = sold;
      const attendancePct = registered === 0 ? 0 : Math.round((checkedIn / registered) * 1000) / 10;
      return {
        eventId: r.event_id,
        title: r.title,
        status: r.status,
        startsAt: r.starts_at?.toISOString() ?? null,
        ticketsSold: sold,
        revenueMinor: r.revenue_minor,
        checkedIn,
        noShows: issued,
        attendancePct,
      };
    });

    const totals = {
      events: items.length,
      ticketsSold: items.reduce((a, i) => a + i.ticketsSold, 0),
      revenueMinor: items.reduce((a, i) => a + BigInt(i.revenueMinor), 0n).toString(),
      checkedIn: items.reduce((a, i) => a + i.checkedIn, 0),
    };

    return { items, totals };
  }

  async exportEventCsv(actor: CommerceActor, eventKey: string): Promise<{ filename: string; body: string }> {
    const intel = await this.getEventIntelligence(actor, eventKey, 30);
    const lines = [
      'section,metric,value',
      `sales,orders,${intel.sales.ordersCount}`,
      `sales,tickets_sold,${intel.sales.ticketsSold}`,
      `sales,revenue_minor,${intel.sales.revenueMinor}`,
      `sales,paid_tickets,${intel.sales.paidTickets}`,
      `sales,complimentary_tickets,${intel.sales.complimentaryTickets}`,
      `attendance,registered,${intel.attendance.registered}`,
      `attendance,checked_in,${intel.attendance.checkedIn}`,
      `attendance,no_shows,${intel.attendance.noShows}`,
      `attendance,attendance_pct,${intel.attendance.attendancePct}`,
      `invitations,sent,${intel.invitations.sent}`,
      `invitations,pending,${intel.invitations.pending}`,
      `invitations,accepted,${intel.invitations.accepted}`,
      `invitations,declined,${intel.invitations.declined}`,
      `invitations,rsvp_conversion_pct,${intel.invitations.rsvpConversionPct}`,
      `finance,gross_minor,${intel.finance.grossCollectedMinor}`,
      `finance,net_minor,${intel.finance.netEarningsMinor}`,
      `finance,fees_minor,${intel.finance.platformFeeMinor}`,
      `finance,refunded_minor,${intel.finance.refundedTotalMinor}`,
      `finance,settlement_status,${intel.finance.settlementStatus}`,
      `intelligence,best_selling_tier,${intel.intelligence.bestSellingTier ?? ''}`,
      `intelligence,peak_attendance_hour,${intel.intelligence.peakAttendanceHour ?? ''}`,
    ];
    for (const t of intel.tiers) {
      lines.push(`tier,${JSON.stringify(t.name)},${t.sold}`);
    }
    const stamp = new Date().toISOString().slice(0, 10);
    return {
      filename: `owanbe-analytics-${eventKey}-${stamp}.csv`,
      body: lines.join('\n'),
    };
  }

  private emptyPortfolioTotals() {
    return { events: 0, ticketsSold: 0, revenueMinor: '0', checkedIn: 0 };
  }

  private async salesSnapshot(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query<{
      orders_count: string;
      revenue_minor: string;
      tickets_sold: string;
      paid: string;
      complimentary: string;
    }>(
      `SELECT
         (
           SELECT COUNT(*)::text FROM ticket_orders o
           WHERE o.tenant_id = $1 AND o.event_id = $2
             AND o.status::text IN ('fulfilled', 'confirmed')
         ) AS orders_count,
         (
           SELECT COALESCE(SUM(o.subtotal_minor), 0)::text FROM ticket_orders o
           WHERE o.tenant_id = $1 AND o.event_id = $2
             AND o.status::text IN ('fulfilled', 'confirmed')
         ) AS revenue_minor,
         (
           SELECT COUNT(*)::text FROM ticket_entitlements te
           WHERE te.tenant_id = $1 AND te.event_id = $2
             AND te.status::text IN ('issued', 'checked_in')
         ) AS tickets_sold,
         (
           SELECT COUNT(*)::text FROM ticket_entitlements te
           WHERE te.tenant_id = $1 AND te.event_id = $2
             AND te.status::text IN ('issued', 'checked_in')
             AND NOT (
               COALESCE((te.metadata->>'source'), '') IN ('invitation', 'complimentary', 'comp')
               OR EXISTS (
                 SELECT 1 FROM ticket_orders o
                 WHERE o.id = te.ticket_order_id AND o.tenant_id = te.tenant_id AND o.total_minor = 0
               )
             )
         ) AS paid,
         (
           SELECT COUNT(*)::text FROM ticket_entitlements te
           WHERE te.tenant_id = $1 AND te.event_id = $2
             AND te.status::text IN ('issued', 'checked_in')
             AND (
               COALESCE((te.metadata->>'source'), '') IN ('invitation', 'complimentary', 'comp')
               OR EXISTS (
                 SELECT 1 FROM ticket_orders o
                 WHERE o.id = te.ticket_order_id AND o.tenant_id = te.tenant_id AND o.total_minor = 0
               )
             )
         ) AS complimentary`,
      [tenantId, eventId],
    );
    const r = rows[0]!;
    return {
      ordersCount: parseInt(r.orders_count, 10),
      revenueMinor: r.revenue_minor,
      ticketsSold: parseInt(r.tickets_sold, 10),
      paidTickets: parseInt(r.paid, 10),
      complimentaryTickets: parseInt(r.complimentary, 10),
    };
  }

  private async attendanceSnapshot(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query<{
      issued: string;
      checked_in: string;
    }>(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'issued')::text AS issued,
         COUNT(*) FILTER (WHERE status = 'checked_in')::text AS checked_in
       FROM ticket_entitlements
       WHERE tenant_id = $1 AND event_id = $2
         AND status::text IN ('issued', 'checked_in')`,
      [tenantId, eventId],
    );
    const issued = parseInt(rows[0]?.issued ?? '0', 10);
    const checkedIn = parseInt(rows[0]?.checked_in ?? '0', 10);
    const registered = issued + checkedIn;
    const attendancePct = registered === 0 ? 0 : Math.round((checkedIn / registered) * 1000) / 10;
    const noShowPct = registered === 0 ? 0 : Math.round((issued / registered) * 1000) / 10;
    return {
      registered,
      checkedIn,
      noShows: issued,
      attendancePct,
      noShowPct,
      checkInRate: registered === 0 ? 0 : checkedIn / registered,
    };
  }

  private async invitationSnapshot(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query<{
      sent: string;
      pending: string;
      accepted: string;
      declined: string;
      guests: string;
    }>(
      `SELECT
         (
           SELECT COUNT(*)::text FROM event_invitations i
           WHERE i.tenant_id = $1 AND i.event_id = $2
             AND i.status::text IN ('queued', 'sent', 'delivered', 'opened')
         ) AS sent,
         (
           SELECT COUNT(*)::text FROM event_guests g
           WHERE g.tenant_id = $1 AND g.event_id = $2
             AND g.rsvp_status::text IN ('invited', 'pending')
         ) AS pending,
         (
           SELECT COUNT(*)::text FROM event_guests g
           WHERE g.tenant_id = $1 AND g.event_id = $2 AND g.rsvp_status::text = 'confirmed'
         ) AS accepted,
         (
           SELECT COUNT(*)::text FROM event_guests g
           WHERE g.tenant_id = $1 AND g.event_id = $2 AND g.rsvp_status::text = 'declined'
         ) AS declined,
         (
           SELECT COUNT(*)::text FROM event_guests g
           WHERE g.tenant_id = $1 AND g.event_id = $2
         ) AS guests`,
      [tenantId, eventId],
    );
    const sent = parseInt(rows[0]?.sent ?? '0', 10);
    const pending = parseInt(rows[0]?.pending ?? '0', 10);
    const accepted = parseInt(rows[0]?.accepted ?? '0', 10);
    const declined = parseInt(rows[0]?.declined ?? '0', 10);
    const guests = parseInt(rows[0]?.guests ?? '0', 10);
    const denom = sent > 0 ? sent : guests;
    const rsvpConversionPct = denom === 0 ? 0 : Math.round((accepted / denom) * 1000) / 10;
    return {
      sent,
      pending,
      accepted,
      declined,
      guestCount: guests,
      rsvpConversionPct,
      available: guests > 0 || sent > 0,
    };
  }

  private async financeSnapshotFromFinance(actor: CommerceActor, eventKey: string) {
    const summary = await this.finance.getEventMonetaryTruth(actor, eventKey);
    return {
      grossCollectedMinor: summary.grossCollectedMinor,
      netEarningsMinor: summary.netEarningsMinor,
      platformFeeMinor: summary.platformFeeMinor,
      refundedTotalMinor: summary.refundedTotalMinor,
      heldInEscrowMinor: summary.heldInEscrowMinor,
      pendingPayoutMinor: summary.pendingPayoutMinor,
      availableForPayoutMinor: summary.availableForPayoutMinor,
      settlementStatus: summary.settlementStatus,
      currency: summary.currency,
      /** Phase 25 — monetary fields sourced from Finance, not recomputed here */
      monetarySource: 'organizer_finance' as const,
    };
  }

  private async seriesBundle(tenantId: string, eventId: string, days: number) {
    const salesDaily = await this.bucketOrders(tenantId, eventId, days, 'day');
    const revenueDaily = await this.bucketRevenue(tenantId, eventId, days, 'day');
    const checkInsHourly = await this.bucketCheckInsHourly(tenantId, eventId);
    const checkInsDaily = await this.bucketCheckInsDaily(tenantId, eventId, days);
    const refundsDaily = await this.bucketRefunds(tenantId, eventId, days);

    return {
      salesDaily,
      revenueDaily,
      checkInsDaily,
      checkInsHourly,
      refundsDaily,
      /** Weekly/monthly are rollups of real daily buckets — not invented curves */
      salesWeekly: this.rollup(salesDaily, 7),
      salesMonthly: this.rollup(salesDaily, 30),
      revenueWeekly: this.rollup(revenueDaily, 7),
      revenueMonthly: this.rollup(revenueDaily, 30),
    };
  }

  private async bucketOrders(tenantId: string, eventId: string, days: number, _granularity: string) {
    const { rows } = await this.pool.query<{ day: string; qty: string }>(
      `SELECT to_char(date_trunc('day', o.created_at AT TIME ZONE 'UTC'), 'YYYY-MM-DD') AS day,
              COUNT(*)::text AS qty
       FROM ticket_orders o
       WHERE o.tenant_id = $1 AND o.event_id = $2
         AND o.status::text IN ('fulfilled', 'confirmed')
         AND o.created_at >= now() - ($3::text || ' days')::interval
       GROUP BY 1
       ORDER BY 1 ASC`,
      [tenantId, eventId, String(days)],
    );
    return this.fillDays(
      days,
      rows.map((r) => ({ key: r.day, value: parseInt(r.qty, 10) })),
    );
  }

  private async bucketRevenue(tenantId: string, eventId: string, days: number, _granularity: string) {
    const { rows } = await this.pool.query<{ day: string; amount: string }>(
      `SELECT to_char(date_trunc('day', o.created_at AT TIME ZONE 'UTC'), 'YYYY-MM-DD') AS day,
              COALESCE(SUM(o.subtotal_minor), 0)::text AS amount
       FROM ticket_orders o
       WHERE o.tenant_id = $1 AND o.event_id = $2
         AND o.status::text IN ('fulfilled', 'confirmed')
         AND o.created_at >= now() - ($3::text || ' days')::interval
       GROUP BY 1
       ORDER BY 1 ASC`,
      [tenantId, eventId, String(days)],
    );
    return this.fillDays(
      days,
      rows.map((r) => ({ key: r.day, value: Number(r.amount) })),
    );
  }

  private async bucketCheckInsDaily(tenantId: string, eventId: string, days: number) {
    const { rows } = await this.pool.query<{ day: string; qty: string }>(
      `SELECT to_char(date_trunc('day', c.checked_in_at AT TIME ZONE 'UTC'), 'YYYY-MM-DD') AS day,
              COUNT(*)::text AS qty
       FROM event_check_ins c
       WHERE c.tenant_id = $1 AND c.event_id = $2
         AND c.checked_in_at >= now() - ($3::text || ' days')::interval
       GROUP BY 1
       ORDER BY 1 ASC`,
      [tenantId, eventId, String(days)],
    );
    return this.fillDays(
      days,
      rows.map((r) => ({ key: r.day, value: parseInt(r.qty, 10) })),
    );
  }

  private async bucketCheckInsHourly(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query<{ hour: string; qty: string }>(
      `SELECT EXTRACT(HOUR FROM c.checked_in_at AT TIME ZONE 'UTC')::int::text AS hour,
              COUNT(*)::text AS qty
       FROM event_check_ins c
       WHERE c.tenant_id = $1 AND c.event_id = $2
       GROUP BY 1
       ORDER BY 1 ASC`,
      [tenantId, eventId],
    );
    const map = new Map(rows.map((r) => [parseInt(r.hour, 10), parseInt(r.qty, 10)]));
    return Array.from({ length: 24 }, (_, h) => ({
      label: `${String(h).padStart(2, '0')}:00`,
      value: map.get(h) ?? 0,
    }));
  }

  private async bucketRefunds(tenantId: string, eventId: string, days: number) {
    const { rows } = await this.pool.query<{ day: string; amount: string }>(
      `SELECT to_char(date_trunc('day', trc.created_at AT TIME ZONE 'UTC'), 'YYYY-MM-DD') AS day,
              COALESCE(SUM(trc.amount_minor), 0)::text AS amount
       FROM ticket_refund_cases trc
       INNER JOIN ticket_orders o ON o.id = trc.ticket_order_id
       WHERE trc.tenant_id = $1 AND o.event_id = $2
         AND trc.created_at >= now() - ($3::text || ' days')::interval
       GROUP BY 1
       ORDER BY 1 ASC`,
      [tenantId, eventId, String(days)],
    );
    return this.fillDays(
      days,
      rows.map((r) => ({ key: r.day, value: Number(r.amount) })),
    );
  }

  private async tierPerformance(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query<{
      tier_name: string;
      sold: string;
      revenue_minor: string;
    }>(
      `SELECT COALESCE(te.metadata->>'tier_name', tol.tier_name, 'General') AS tier_name,
              COUNT(*)::text AS sold,
              COALESCE(SUM(tol.unit_price_minor), 0)::text AS revenue_minor
       FROM ticket_entitlements te
       LEFT JOIN ticket_order_lines tol ON tol.id = te.ticket_order_line_id
       WHERE te.tenant_id = $1 AND te.event_id = $2
         AND te.status::text IN ('issued', 'checked_in')
       GROUP BY 1
       ORDER BY COUNT(*) DESC`,
      [tenantId, eventId],
    );
    return rows.map((r) => ({
      name: r.tier_name,
      sold: parseInt(r.sold, 10),
      revenueMinor: r.revenue_minor,
    }));
  }

  private deriveIntelligence(
    sales: { ticketsSold: number; complimentaryTickets: number; paidTickets: number },
    attendance: { attendancePct: number; checkedIn: number },
    series: { checkInsHourly: { label: string; value: number }[] },
    tiers: { name: string; sold: number }[],
  ) {
    const best = tiers[0] ?? null;
    let peak: { label: string; value: number } | null = null;
    for (const h of series.checkInsHourly) {
      if (!peak || h.value > peak.value) peak = h;
    }
    return {
      bestSellingTier: best && best.sold > 0 ? best.name : null,
      bestSellingTierSold: best?.sold ?? 0,
      peakAttendanceHour: peak && peak.value > 0 ? peak.label : null,
      peakAttendanceCount: peak?.value ?? 0,
      engagementSummary: this.engagementCopy(sales, attendance),
    };
  }

  private engagementCopy(
    sales: { ticketsSold: number; complimentaryTickets: number; paidTickets: number },
    attendance: { attendancePct: number; checkedIn: number },
  ): string {
    if (sales.ticketsSold === 0 && attendance.checkedIn === 0) {
      return 'No ticket or check-in activity yet.';
    }
    const parts = [
      `${sales.paidTickets} paid`,
      `${sales.complimentaryTickets} complimentary`,
      `${attendance.attendancePct}% attendance`,
    ];
    return parts.join(' · ');
  }

  private fillDays(days: number, points: { key: string; value: number }[]) {
    const map = new Map(points.map((p) => [p.key, p.value]));
    const out: { label: string; value: number }[] = [];
    const now = new Date();
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
      d.setUTCDate(d.getUTCDate() - i);
      const key = d.toISOString().slice(0, 10);
      out.push({ label: key.slice(5), value: map.get(key) ?? 0 });
    }
    return out;
  }

  private rollup(daily: { label: string; value: number }[], bucketSize: number) {
    if (daily.length === 0) return [] as { label: string; value: number }[];
    const out: { label: string; value: number }[] = [];
    for (let i = 0; i < daily.length; i += bucketSize) {
      const slice = daily.slice(i, i + bucketSize);
      out.push({
        label: slice[0]?.label ?? `${i}`,
        value: slice.reduce((a, p) => a + p.value, 0),
      });
    }
    return out;
  }
}
