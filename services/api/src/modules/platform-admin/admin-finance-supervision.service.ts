import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

@Injectable()
export class AdminFinanceSupervisionService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getSupervision(tenantId: string) {
    const { rows } = await this.pool.query<{
      ticket_volume_minor: string;
      ticket_orders: string;
      ticket_refunds_open: string;
      organizer_payouts_pending: string;
      booking_volume_minor: string;
      booking_payments: string;
      vendor_payouts_pending: string;
      open_recon: string;
    }>(
      `SELECT
         COALESCE((
           SELECT SUM(tol.quantity * tol.unit_price_minor)::text
           FROM ticket_order_lines tol
           INNER JOIN ticket_orders tord ON tord.id = tol.ticket_order_id
           WHERE tord.tenant_id = $1 AND tord.status IN ('fulfilled', 'confirmed')
         ), '0') AS ticket_volume_minor,
         (SELECT COUNT(*)::text FROM ticket_orders WHERE tenant_id = $1 AND status IN ('fulfilled', 'confirmed')) AS ticket_orders,
         (SELECT COUNT(*)::text FROM ticket_refund_cases WHERE tenant_id = $1 AND status::text IN ('requested', 'under_review')) AS ticket_refunds_open,
         (SELECT COUNT(*)::text FROM organizer_payouts WHERE tenant_id = $1 AND status::text IN ('pending', 'processing')) AS organizer_payouts_pending,
         COALESCE((
           SELECT SUM(amount_captured_minor)::text FROM payments
           WHERE tenant_id = $1 AND status::text IN ('captured', 'partially_refunded', 'refunded')
         ), '0') AS booking_volume_minor,
         (SELECT COUNT(*)::text FROM payments WHERE tenant_id = $1 AND status::text IN ('captured', 'partially_refunded', 'refunded')) AS booking_payments,
         (SELECT COUNT(*)::text FROM payouts WHERE tenant_id = $1 AND status::text IN ('pending', 'processing')) AS vendor_payouts_pending,
         (SELECT COUNT(*)::text FROM reconciliation_reports WHERE tenant_id = $1 AND resolution_status::text = 'open') AS open_recon`,
      [tenantId],
    );
    const s = rows[0]!;
    return {
      ticketRail: {
        volumeMinor: s.ticket_volume_minor,
        orderCount: Number(s.ticket_orders),
        openRefunds: Number(s.ticket_refunds_open),
        pendingOrganizerPayouts: Number(s.organizer_payouts_pending),
      },
      bookingRail: {
        volumeMinor: s.booking_volume_minor,
        paymentCount: Number(s.booking_payments),
        pendingVendorPayouts: Number(s.vendor_payouts_pending),
      },
      reconciliation: {
        openIssues: Number(s.open_recon),
      },
      totalVolumeMinor: String(
        BigInt(s.ticket_volume_minor) + BigInt(s.booking_volume_minor),
      ),
    };
  }
}
