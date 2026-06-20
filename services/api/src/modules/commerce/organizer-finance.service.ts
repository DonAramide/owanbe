import {
  ForbiddenException,
  Injectable,
  Inject,
  NotFoundException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from './commerce-auth.service';

export interface OrganizerEventFinanceSummary {
  eventId: string;
  eventTitle: string;
  organizerId: string;
  currency: string;
  ticketRevenueMinor: string;
  platformFeeMinor: string;
  grossCollectedMinor: string;
  netEarningsMinor: string;
  heldInEscrowMinor: string;
  availableForPayoutMinor: string;
  pendingPayoutMinor: string;
  openRefundRequests: number;
  fulfilledOrderCount: number;
  payoutEligible: boolean;
  payoutEligibilityReason: string | null;
}

export interface OrganizerFinanceTransaction {
  occurredAt: string;
  type: string;
  status: string;
  amountMinor: string;
  currency: string;
  ticketOrderId: string | null;
  orderReference: string | null;
  reason: string | null;
  timestampMs: number;
}

@Injectable()
export class OrganizerFinanceService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  private async resolveEventScope(
    tenantId: string,
    userId: string,
    eventKey: string,
  ): Promise<{ eventId: string; eventTitle: string; organizerId: string }> {
    const { rows } = await this.pool.query<{
      event_id: string;
      title: string;
      organizer_id: string;
    }>(
      `SELECT e.id AS event_id, e.title, e.organizer_id
       FROM events e
       INNER JOIN organizers o ON o.id = e.organizer_id AND o.tenant_id = e.tenant_id
       WHERE e.tenant_id = $1
         AND o.owner_user_id = $2
         AND (e.id::text = $3 OR e.external_ref = $3 OR e.slug = $3)
       LIMIT 1`,
      [tenantId, userId, eventKey],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'EVENT_NOT_FOUND', message: 'Event not found or access denied' });
    }
    return { eventId: row.event_id, eventTitle: row.title, organizerId: row.organizer_id };
  }

  private async managedOrganizerIds(tenantId: string, userId: string): Promise<string[]> {
    const { rows } = await this.pool.query<{ id: string }>(
      `SELECT id FROM organizers WHERE tenant_id = $1 AND owner_user_id = $2 AND status = 'active'`,
      [tenantId, userId],
    );
    return rows.map((r) => r.id);
  }

  async getEventSummary(actor: CommerceActor, eventKey: string): Promise<OrganizerEventFinanceSummary> {
    const scope = await this.resolveEventScope(actor.tenantId, actor.userId, eventKey);

    const orderAgg = await this.pool.query<{
      ticket_revenue_minor: string;
      platform_fee_minor: string;
      gross_minor: string;
      order_count: string;
      currency: string;
      held_minor: string;
    }>(
      `SELECT
         COALESCE(SUM(tord.subtotal_minor), 0)::text AS ticket_revenue_minor,
         COALESCE(SUM(tord.platform_fee_minor), 0)::text AS platform_fee_minor,
         COALESCE(SUM(tord.total_minor), 0)::text AS gross_minor,
         COUNT(*)::text AS order_count,
         COALESCE(MAX(tord.currency), 'NGN') AS currency,
         COALESCE(SUM(
           CASE
             WHEN tord.escrow_release_not_before IS NOT NULL AND tord.escrow_release_not_before > now()
               THEN tord.subtotal_minor
             WHEN tord.escrow_release_not_before IS NULL
               AND tord.completed_at IS NOT NULL
               AND tord.completed_at + (COALESCE(tfs.escrow_release_delay_hours, 48) || ' hours')::interval > now()
               THEN tord.subtotal_minor
             ELSE 0
           END
         ), 0)::text AS held_minor
       FROM ticket_orders tord
       LEFT JOIN tenant_finance_settings tfs ON tfs.tenant_id = tord.tenant_id
       WHERE tord.tenant_id = $1
         AND tord.event_id = $2
         AND tord.status IN ('fulfilled', 'confirmed')`,
      [actor.tenantId, scope.eventId],
    );
    const orders = orderAgg.rows[0] ?? {
      ticket_revenue_minor: '0',
      platform_fee_minor: '0',
      gross_minor: '0',
      order_count: '0',
      currency: 'NGN',
      held_minor: '0',
    };

    const ledgerBal = await this.pool.query<{
      net_organizer_payable_minor: string;
    }>(
      `SELECT COALESCE(SUM(
         CASE WHEN ll.direction = 'credit' THEN ll.amount_minor ELSE -ll.amount_minor END
       ), 0)::text AS net_organizer_payable_minor
       FROM ledger_accounts la
       INNER JOIN ledger_lines ll ON ll.account_id = la.id
       INNER JOIN ledger_transactions lt ON lt.id = ll.transaction_id
       WHERE la.tenant_id = $1
         AND la.kind = 'organizer_payable'
         AND la.organizer_id = $2
         AND lt.reason IN ('payment_capture_ticket', 'payment_refund_ticket', 'payout_organizer_release')`,
      [actor.tenantId, scope.organizerId],
    );
    const netOrganizerPayable = BigInt(ledgerBal.rows[0]?.net_organizer_payable_minor ?? '0');

    const pendingPayout = await this.pool.query<{ pending_minor: string }>(
      `SELECT COALESCE(SUM(amount_minor), 0)::text AS pending_minor
       FROM organizer_payouts
       WHERE tenant_id = $1 AND organizer_id = $2 AND status::text IN ('pending', 'processing')`,
      [actor.tenantId, scope.organizerId],
    );
    const pendingPayoutMinor = BigInt(pendingPayout.rows[0]?.pending_minor ?? '0');

    const heldMinor = BigInt(orders.held_minor);
    const available = netOrganizerPayable - pendingPayoutMinor - heldMinor;
    const availableClamped = available > 0n ? available : 0n;

    const refunds = await this.pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n
       FROM ticket_refund_cases trc
       INNER JOIN ticket_orders tord ON tord.id = trc.ticket_order_id
       WHERE trc.tenant_id = $1
         AND tord.event_id = $2
         AND trc.status::text IN ('requested', 'under_review', 'approved', 'processing')`,
      [actor.tenantId, scope.eventId],
    );

    const payoutEligible = availableClamped > 0n;
    const payoutEligibilityReason = payoutEligible
      ? null
      : heldMinor > 0n
        ? 'Earnings still in escrow hold period'
        : pendingPayoutMinor >= netOrganizerPayable
          ? 'Pending payout in progress'
          : 'No available balance';

    return {
      eventId: scope.eventId,
      eventTitle: scope.eventTitle,
      organizerId: scope.organizerId,
      currency: orders.currency,
      ticketRevenueMinor: orders.ticket_revenue_minor,
      platformFeeMinor: orders.platform_fee_minor,
      grossCollectedMinor: orders.gross_minor,
      netEarningsMinor: orders.ticket_revenue_minor,
      heldInEscrowMinor: orders.held_minor,
      availableForPayoutMinor: availableClamped.toString(),
      pendingPayoutMinor: pendingPayoutMinor.toString(),
      openRefundRequests: parseInt(refunds.rows[0]?.n ?? '0', 10),
      fulfilledOrderCount: parseInt(orders.order_count, 10),
      payoutEligible,
      payoutEligibilityReason,
    };
  }

  async getEventTransactions(
    actor: CommerceActor,
    eventKey: string,
    limit = 100,
  ): Promise<{ items: OrganizerFinanceTransaction[] }> {
    const scope = await this.resolveEventScope(actor.tenantId, actor.userId, eventKey);
    const n = Math.min(200, Math.max(1, limit));

    const { rows } = await this.pool.query<{
      occurred_at: Date;
      type: string;
      status: string;
      amount_minor: string;
      currency: string;
      ticket_order_id: string | null;
      order_ref: string | null;
      event_reason: string | null;
    }>(
      `WITH event_orders AS (
         SELECT id FROM ticket_orders WHERE tenant_id = $1 AND event_id = $2
       ),
       capture_rows AS (
         SELECT lt.created_at AS occurred_at,
                'ticket_sale'::text AS type,
                'posted'::text AS status,
                SUM(CASE WHEN ll.direction = 'credit' THEN ll.amount_minor ELSE -ll.amount_minor END)::bigint AS amount_minor,
                ll.currency,
                lt.ticket_order_id,
                NULL::text AS event_reason
         FROM ledger_transactions lt
         INNER JOIN ledger_lines ll ON ll.transaction_id = lt.id
         INNER JOIN ledger_accounts la ON la.id = ll.account_id AND la.kind = 'organizer_payable'
         INNER JOIN event_orders eo ON eo.id = lt.ticket_order_id
         WHERE lt.tenant_id = $1 AND lt.reason = 'payment_capture_ticket'
         GROUP BY lt.id, lt.created_at, ll.currency, lt.ticket_order_id
       ),
       fee_rows AS (
         SELECT lt.created_at AS occurred_at,
                'platform_fee'::text AS type,
                'posted'::text AS status,
                (0 - SUM(CASE WHEN ll.direction = 'credit' THEN ll.amount_minor ELSE -ll.amount_minor END))::bigint AS amount_minor,
                ll.currency,
                lt.ticket_order_id,
                'Platform fee on ticket sale'::text AS event_reason
         FROM ledger_transactions lt
         INNER JOIN ledger_lines ll ON ll.transaction_id = lt.id
         INNER JOIN ledger_accounts la ON la.id = ll.account_id AND la.kind = 'platform_fees'
         INNER JOIN event_orders eo ON eo.id = lt.ticket_order_id
         WHERE lt.tenant_id = $1 AND lt.reason = 'payment_capture_ticket'
         GROUP BY lt.id, lt.created_at, ll.currency, lt.ticket_order_id
       ),
       payout_rows AS (
         SELECT COALESCE(op.updated_at, op.created_at) AS occurred_at,
                'payout'::text AS type,
                op.status::text AS status,
                (0 - op.amount_minor)::bigint AS amount_minor,
                op.currency,
                op.ticket_order_id,
                CASE
                  WHEN op.status::text = 'pending' THEN 'Organizer payout queued'
                  WHEN op.under_review THEN 'Payout under review'
                  ELSE NULL
                END AS event_reason
         FROM organizer_payouts op
         INNER JOIN event_orders eo ON eo.id = op.ticket_order_id
         WHERE op.tenant_id = $1
       ),
       refund_rows AS (
         SELECT trc.created_at AS occurred_at,
                'refund_request'::text AS type,
                trc.status::text AS status,
                (0 - trc.amount_minor)::bigint AS amount_minor,
                trc.currency,
                trc.ticket_order_id,
                trc.reason AS event_reason
         FROM ticket_refund_cases trc
         INNER JOIN event_orders eo ON eo.id = trc.ticket_order_id
         WHERE trc.tenant_id = $1
       )
       SELECT x.occurred_at, x.type, x.status, x.amount_minor::text, x.currency,
              x.ticket_order_id, tord.id::text AS order_ref, x.event_reason
       FROM (
         SELECT * FROM capture_rows
         UNION ALL SELECT * FROM fee_rows
         UNION ALL SELECT * FROM payout_rows
         UNION ALL SELECT * FROM refund_rows
       ) x
       LEFT JOIN ticket_orders tord ON tord.id = x.ticket_order_id
       ORDER BY x.occurred_at DESC
       LIMIT $3`,
      [actor.tenantId, scope.eventId, n],
    );

    return {
      items: rows.map((r) => ({
        occurredAt: r.occurred_at.toISOString(),
        type: r.type,
        status: r.status,
        amountMinor: r.amount_minor,
        currency: r.currency,
        ticketOrderId: r.ticket_order_id,
        orderReference: r.order_ref,
        reason: r.event_reason,
        timestampMs: r.occurred_at.getTime(),
      })),
    };
  }

  async getOrganizerBalance(tenantId: string, organizerId: string) {
    const ledgerBal = await this.pool.query<{ net: string }>(
      `SELECT COALESCE(SUM(
         CASE WHEN ll.direction = 'credit' THEN ll.amount_minor ELSE -ll.amount_minor END
       ), 0)::text AS net
       FROM ledger_accounts la
       INNER JOIN ledger_lines ll ON ll.account_id = la.id
       INNER JOIN ledger_transactions lt ON lt.id = ll.transaction_id
       WHERE la.tenant_id = $1 AND la.kind = 'organizer_payable' AND la.organizer_id = $2
         AND lt.reason IN ('payment_capture_ticket', 'payment_refund_ticket', 'payout_organizer_release')`,
      [tenantId, organizerId],
    );
    const netOrganizerPayable = BigInt(ledgerBal.rows[0]?.net ?? '0');

    const pendingPayout = await this.pool.query<{ pending_minor: string }>(
      `SELECT COALESCE(SUM(amount_minor), 0)::text AS pending_minor
       FROM organizer_payouts
       WHERE tenant_id = $1 AND organizer_id = $2 AND status::text IN ('pending', 'processing')`,
      [tenantId, organizerId],
    );
    const pendingPayoutMinor = BigInt(pendingPayout.rows[0]?.pending_minor ?? '0');

    const held = await this.pool.query<{ held_minor: string }>(
      `SELECT COALESCE(SUM(
         CASE
           WHEN tord.escrow_release_not_before IS NOT NULL AND tord.escrow_release_not_before > now()
             THEN tord.subtotal_minor
           WHEN tord.escrow_release_not_before IS NULL
             AND COALESCE(tord.completed_at, tord.updated_at) + (COALESCE(tfs.escrow_release_delay_hours, 48) || ' hours')::interval > now()
             THEN tord.subtotal_minor
           ELSE 0
         END
       ), 0)::text AS held_minor
       FROM ticket_orders tord
       LEFT JOIN tenant_finance_settings tfs ON tfs.tenant_id = tord.tenant_id
       WHERE tord.tenant_id = $1 AND tord.organizer_id = $2
         AND tord.status IN ('fulfilled', 'confirmed')`,
      [tenantId, organizerId],
    );
    const heldMinor = BigInt(held.rows[0]?.held_minor ?? '0');
    const available = netOrganizerPayable - pendingPayoutMinor - heldMinor;
    const availableClamped = available > 0n ? available : 0n;

    return {
      netOrganizerPayableMinor: netOrganizerPayable.toString(),
      pendingPayoutMinor: pendingPayoutMinor.toString(),
      heldInEscrowMinor: heldMinor.toString(),
      availableForPayoutMinor: availableClamped.toString(),
    };
  }

  async assertOrganizerAccess(actor: CommerceActor, organizerId: string): Promise<void> {
    const ids = await this.managedOrganizerIds(actor.tenantId, actor.userId);
    if (!ids.includes(organizerId)) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'Organizer access denied' });
    }
  }
}
