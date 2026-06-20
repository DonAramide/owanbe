import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

@Injectable()
export class SuperAdminFinanceService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getPlatformFinance(drill?: string, drillId?: string) {
    const summary = await this.globalSummary();
    if (!drill || !drillId) {
      return { summary, drillDown: null };
    }
    const drillDown = await this.drillDown(drill, drillId);
    return { summary, drillDown };
  }

  private async globalSummary() {
    const { rows } = await this.pool.query<{
      ticket_revenue: string;
      booking_revenue: string;
      platform_fees: string;
      refund_volume: string;
      payout_volume: string;
    }>(
      `SELECT
         COALESCE((SELECT SUM(tol.quantity * tol.unit_price_minor)::text
           FROM ticket_order_lines tol INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
           WHERE tord.status IN ('fulfilled', 'confirmed')), '0') AS ticket_revenue,
         COALESCE((SELECT SUM(amount_captured_minor)::text FROM payments
           WHERE status::text IN ('captured', 'partially_refunded', 'refunded')), '0') AS booking_revenue,
         COALESCE((
           COALESCE((SELECT SUM((tol.quantity * tol.unit_price_minor * COALESCE(tfs.ticket_platform_fee_bps, 500)) / 10000)
             FROM ticket_order_lines tol INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
             INNER JOIN tenant_finance_settings tfs ON tfs.tenant_id = tord.tenant_id
             WHERE tord.status IN ('fulfilled', 'confirmed')), 0)
           + COALESCE((SELECT SUM((p.amount_captured_minor * COALESCE(tfs.vendor_platform_fee_bps, 500)) / 10000)
             FROM payments p INNER JOIN tenant_finance_settings tfs ON tfs.tenant_id = p.tenant_id
             WHERE p.status::text IN ('captured', 'partially_refunded', 'refunded')), 0)
         )::text, '0') AS platform_fees,
         COALESCE((SELECT SUM(amount_minor)::text FROM ticket_refund_cases
           WHERE status::text IN ('approved', 'completed', 'processing')), '0') AS refund_volume,
         COALESCE((
           COALESCE((SELECT SUM(amount_minor) FROM organizer_payouts WHERE status::text IN ('completed', 'processing', 'pending')), 0)
           + COALESCE((SELECT SUM(amount_minor) FROM payouts WHERE status::text IN ('completed', 'processing', 'pending')), 0)
         )::text, '0') AS payout_volume`,
    );
    const s = rows[0]!;
    return {
      ticketRevenueMinor: s.ticket_revenue,
      bookingRevenueMinor: s.booking_revenue,
      platformFeesMinor: s.platform_fees,
      refundVolumeMinor: s.refund_volume,
      payoutVolumeMinor: s.payout_volume,
      totalVolumeMinor: String(BigInt(s.ticket_revenue) + BigInt(s.booking_revenue)),
    };
  }

  private async drillDown(drill: string, drillId: string) {
    switch (drill) {
      case 'tenant':
        return this.tenantDrill(drillId);
      case 'event':
        return this.eventDrill(drillId);
      case 'organizer':
        return this.organizerDrill(drillId);
      case 'vendor':
        return this.vendorDrill(drillId);
      default:
        return null;
    }
  }

  private async tenantDrill(tenantId: string) {
    const { rows } = await this.pool.query(
      `SELECT t.name, t.slug,
              COALESCE((SELECT SUM(tol.quantity * tol.unit_price_minor)::text
                FROM ticket_order_lines tol INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
                WHERE tord.tenant_id = t.id AND tord.status IN ('fulfilled', 'confirmed')), '0') AS ticket_minor,
              COALESCE((SELECT SUM(amount_captured_minor)::text FROM payments WHERE tenant_id = t.id
                AND status::text IN ('captured', 'partially_refunded', 'refunded')), '0') AS booking_minor
       FROM tenants t WHERE t.id = $1`,
      [tenantId],
    );
    return rows[0] ?? null;
  }

  private async eventDrill(eventKey: string) {
    const { rows } = await this.pool.query(
      `SELECT e.title, e.external_ref,
              COALESCE((SELECT SUM(tol.quantity * tol.unit_price_minor)::text
                FROM ticket_order_lines tol INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
                WHERE tord.event_id = e.id AND tord.status IN ('fulfilled', 'confirmed')), '0') AS ticket_minor
       FROM events e WHERE e.id::text = $1 OR e.external_ref = $1 LIMIT 1`,
      [eventKey],
    );
    return rows[0] ?? null;
  }

  private async organizerDrill(organizerId: string) {
    const { rows } = await this.pool.query(
      `SELECT o.display_name,
              COALESCE((SELECT SUM(tol.quantity * tol.unit_price_minor)::text
                FROM ticket_order_lines tol INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
                WHERE tord.organizer_id = o.id AND tord.status IN ('fulfilled', 'confirmed')), '0') AS ticket_minor
       FROM organizers o WHERE o.id = $1`,
      [organizerId],
    );
    return rows[0] ?? null;
  }

  private async vendorDrill(vendorId: string) {
    const { rows } = await this.pool.query(
      `SELECT v.business_name,
              COALESCE((SELECT SUM(p.amount_captured_minor)::text
                FROM payments p INNER JOIN bookings b ON b.id = p.booking_id
                WHERE b.vendor_id = v.id AND p.status::text IN ('captured', 'partially_refunded', 'refunded')), '0') AS booking_minor
       FROM vendors v WHERE v.id = $1`,
      [vendorId],
    );
    return rows[0] ?? null;
  }
}
