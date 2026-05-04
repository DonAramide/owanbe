import {
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
  ForbiddenException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { VendorAccessService } from '../../ownership/vendor-access.service';
import { PayoutService } from './payout.service';
import { FinanceStateService } from './finance-state.service';

interface VendorBalanceRow {
  vendor_id: string;
  currency: string;
  earnings_minor: string;
  refunds_minor: string;
  chargebacks_minor: string;
  pending_payout_minor: string;
  under_review_minor: string;
  liability_minor: string;
  net_earnings_minor: string;
  available_minor: string;
}

@Injectable()
export class VendorFinanceService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly vendorAccess: VendorAccessService,
    private readonly payouts: PayoutService,
    private readonly financeState: FinanceStateService,
  ) {}

  private async managedVendorIds(tenantId: string, userId: string): Promise<string[]> {
    const vendorScope = await this.pool.query<{ vendor_id: string }>(
      `SELECT v.id AS vendor_id
       FROM vendors v
       WHERE v.tenant_id = $1
         AND (v.owner_user_id = $2 OR EXISTS (
           SELECT 1 FROM vendor_users vu WHERE vu.vendor_id = v.id AND vu.user_id = $2
         ))`,
      [tenantId, userId],
    );
    return vendorScope.rows.map((r) => r.vendor_id);
  }

  /**
   * Single source of truth for vendor financial aggregates.
   * Net earnings = earnings - refunds - chargebacks.
   * Available = net earnings - pending payouts - open liabilities.
   */
  async calculateAvailableBalance(tenantId: string, vendorIds: string[]): Promise<VendorBalanceRow[]> {
    if (!vendorIds.length) return [];
    const { rows } = await this.pool.query<VendorBalanceRow>(
      `WITH scope AS (
         SELECT unnest($2::uuid[]) AS vendor_id
       ),
       ledger_base AS (
         SELECT la.vendor_id, ll.currency, lt.reason,
                SUM(CASE WHEN ll.direction='credit' THEN ll.amount_minor ELSE -ll.amount_minor END)::bigint AS amount_minor
         FROM ledger_accounts la
         INNER JOIN ledger_lines ll ON ll.account_id = la.id
         INNER JOIN ledger_transactions lt ON lt.id = ll.transaction_id
         INNER JOIN scope s ON s.vendor_id = la.vendor_id
         WHERE la.tenant_id = $1 AND la.kind = 'vendor_payable'
           AND lt.reason IN ('payment_capture_quaser','payment_refund','payment_chargeback','payout_escrow_release')
         GROUP BY la.vendor_id, ll.currency, lt.reason
       ),
       ledger_pivot AS (
         SELECT vendor_id, currency,
                COALESCE(SUM(CASE WHEN reason = 'payment_capture_quaser' THEN amount_minor ELSE 0 END),0)::bigint AS earnings_minor,
                COALESCE(SUM(CASE WHEN reason = 'payment_refund' THEN 0 - amount_minor ELSE 0 END),0)::bigint AS refunds_minor,
                COALESCE(SUM(CASE WHEN reason = 'payment_chargeback' THEN 0 - amount_minor ELSE 0 END),0)::bigint AS chargebacks_minor
         FROM ledger_base
         GROUP BY vendor_id, currency
       ),
       pending AS (
         SELECT p.vendor_id, p.currency,
                COALESCE(SUM(p.amount_minor), 0)::bigint AS pending_payout_minor
         FROM payouts p
         INNER JOIN scope s ON s.vendor_id = p.vendor_id
         WHERE p.tenant_id = $1
           AND p.status::text IN ('pending','processing')
         GROUP BY p.vendor_id, p.currency
       ),
       under_review AS (
         SELECT p.vendor_id, p.currency,
                COALESCE(SUM(p.amount_minor), 0)::bigint AS under_review_minor
         FROM payouts p
         INNER JOIN scope s ON s.vendor_id = p.vendor_id
         WHERE p.tenant_id = $1 AND p.under_review = TRUE
         GROUP BY p.vendor_id, p.currency
       ),
       liabilities AS (
         SELECT b.vendor_id, p.currency,
                COALESCE(SUM(d.amount_claimed_minor), 0)::bigint AS liability_minor
         FROM disputes d
         INNER JOIN bookings b ON b.id = d.booking_id
         INNER JOIN payments p ON p.booking_id = b.id
         INNER JOIN scope s ON s.vendor_id = b.vendor_id
         WHERE d.tenant_id = $1
           AND d.status::text IN ('open','under_review','awaiting_evidence')
           AND d.amount_claimed_minor IS NOT NULL
         GROUP BY b.vendor_id, p.currency
       )
       SELECT lp.vendor_id,
              lp.currency,
              lp.earnings_minor::text,
              lp.refunds_minor::text,
              lp.chargebacks_minor::text,
              COALESCE(pn.pending_payout_minor, 0)::text AS pending_payout_minor,
              COALESCE(ur.under_review_minor, 0)::text AS under_review_minor,
              COALESCE(lb.liability_minor, 0)::text AS liability_minor,
              (lp.earnings_minor - lp.refunds_minor - lp.chargebacks_minor)::text AS net_earnings_minor,
              GREATEST(
                (lp.earnings_minor - lp.refunds_minor - lp.chargebacks_minor)
                - COALESCE(pn.pending_payout_minor, 0)
                - COALESCE(lb.liability_minor, 0),
                0
              )::text AS available_minor
       FROM ledger_pivot lp
       LEFT JOIN pending pn ON pn.vendor_id = lp.vendor_id AND pn.currency = lp.currency
       LEFT JOIN under_review ur ON ur.vendor_id = lp.vendor_id AND ur.currency = lp.currency
       LEFT JOIN liabilities lb ON lb.vendor_id = lp.vendor_id AND lb.currency = lp.currency
       ORDER BY lp.vendor_id, lp.currency`,
      [tenantId, vendorIds],
    );
    return rows;
  }

  async getBalanceForPrincipal(tenantId: string, userId: string) {
    const vendorIds = await this.managedVendorIds(tenantId, userId);
    if (!vendorIds.length) {
      return { items: [], totalBalanceMinor: '0' };
    }
    const rows = await this.calculateAvailableBalance(tenantId, vendorIds);

    const total = rows.reduce((acc, r) => acc + BigInt(r.available_minor), 0n);
    return {
      items: rows.map((r) => ({
        vendorId: r.vendor_id,
        currency: r.currency,
        vendorPayableMinor: r.net_earnings_minor,
        pendingPayoutMinor: r.pending_payout_minor,
        liabilityMinor: r.liability_minor,
        availableMinor: r.available_minor,
      })),
      totalBalanceMinor: total.toString(),
    };
  }

  async getDashboardSummary(tenantId: string, userId: string, vendorId?: string) {
    const vendorIds = await this.managedVendorIds(tenantId, userId);
    if (!vendorIds.length) {
      return {
        items: [],
        totals: {
          availableBalanceMinor: '0',
          pendingEarningsMinor: '0',
          underReviewAmountMinor: '0',
          totalEarningsMinor: '0',
        },
      };
    }
    const scoped = vendorId ? vendorIds.filter((v) => v === vendorId) : vendorIds;
    if (!scoped.length) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'Vendor access denied' });
    }

    const rows = await this.calculateAvailableBalance(tenantId, scoped);

    const totals = rows.reduce(
      (acc, r) => {
        acc.availableBalanceMinor += BigInt(r.available_minor);
        acc.pendingEarningsMinor += BigInt(r.pending_payout_minor);
        acc.underReviewAmountMinor += BigInt(r.under_review_minor);
        acc.totalEarningsMinor += BigInt(r.net_earnings_minor);
        return acc;
      },
      {
        availableBalanceMinor: 0n,
        pendingEarningsMinor: 0n,
        underReviewAmountMinor: 0n,
        totalEarningsMinor: 0n,
      },
    );
    return {
      items: rows.map((r) => ({
        vendorId: r.vendor_id,
        currency: r.currency,
        availableBalanceMinor: r.available_minor,
        available_balance: r.available_minor,
        pendingEarningsMinor: r.pending_payout_minor,
        pending_earnings: r.pending_payout_minor,
        underReviewAmountMinor: r.under_review_minor,
        under_review_amount: r.under_review_minor,
        totalEarningsMinor: r.net_earnings_minor,
        total_earnings: r.net_earnings_minor,
      })),
      totals: {
        availableBalanceMinor: totals.availableBalanceMinor.toString(),
        available_balance: totals.availableBalanceMinor.toString(),
        pendingEarningsMinor: totals.pendingEarningsMinor.toString(),
        pending_earnings: totals.pendingEarningsMinor.toString(),
        underReviewAmountMinor: totals.underReviewAmountMinor.toString(),
        under_review_amount: totals.underReviewAmountMinor.toString(),
        totalEarningsMinor: totals.totalEarningsMinor.toString(),
        total_earnings: totals.totalEarningsMinor.toString(),
      },
    };
  }

  async getTransactions(tenantId: string, userId: string, limit = 100, vendorId?: string) {
    const vendorIds = await this.managedVendorIds(tenantId, userId);
    const scoped = vendorId ? vendorIds.filter((v) => v === vendorId) : vendorIds;
    if (!scoped.length) return { items: [] };

    const { rows } = await this.pool.query<{
      occurred_at: Date;
      type: string;
      status: string;
      amount_minor: string;
      currency: string;
      booking_id: string | null;
      booking_ref: string | null;
      payment_id: string | null;
      payout_id: string | null;
      vendor_id: string;
      event_reason: string | null;
    }>(
      `WITH vendor_scope AS (
         SELECT unnest($2::uuid[]) AS vendor_id
       ),
       earning_rows AS (
         SELECT lt.created_at AS occurred_at,
                CASE WHEN lt.reason = 'payment_chargeback' THEN 'chargeback'
                     WHEN lt.reason = 'payment_refund' THEN 'refund'
                     ELSE 'earning' END AS type,
                'posted'::text AS status,
                SUM(CASE WHEN ll.direction='credit' THEN ll.amount_minor ELSE -ll.amount_minor END)::bigint AS amount_minor,
                ll.currency,
                lt.booking_id,
                lt.payment_id,
                NULL::uuid AS payout_id,
                la.vendor_id,
                NULL::text AS event_reason
         FROM ledger_transactions lt
         INNER JOIN ledger_lines ll ON ll.transaction_id = lt.id
         INNER JOIN ledger_accounts la ON la.id = ll.account_id AND la.kind='vendor_payable'
         INNER JOIN vendor_scope vs ON vs.vendor_id = la.vendor_id
         WHERE lt.tenant_id = $1
           AND lt.reason IN ('payment_capture_quaser','payout_escrow_release','payment_refund','payment_chargeback')
         GROUP BY lt.id, lt.created_at, lt.reason, ll.currency, lt.booking_id, lt.payment_id, la.vendor_id
       ),
       payout_rows AS (
         SELECT COALESCE(p.updated_at, p.created_at) AS occurred_at,
                'payout'::text AS type,
                p.status::text AS status,
                (0 - p.amount_minor)::bigint AS amount_minor,
                p.currency,
                p.booking_id,
                p.payment_id,
                p.id AS payout_id,
                p.vendor_id,
                CASE
                  WHEN p.status::text = 'pending' THEN 'Queued for payout processing'
                  WHEN p.under_review = TRUE THEN 'Payout is under manual review'
                  WHEN p.status::text = 'failed' THEN COALESCE(p.failure_message, 'Payout failed')
                  ELSE NULL
                END AS event_reason
         FROM payouts p
         INNER JOIN vendor_scope vs ON vs.vendor_id = p.vendor_id
         WHERE p.tenant_id = $1
       )
       SELECT x.occurred_at, x.type, x.status, x.amount_minor::text, x.currency,
              x.booking_id, b.id::text AS booking_ref, x.payment_id, x.payout_id, x.vendor_id, x.event_reason
       FROM (
         SELECT * FROM earning_rows
         UNION ALL
         SELECT * FROM payout_rows
       ) x
       LEFT JOIN bookings b ON b.id = x.booking_id
       ORDER BY x.occurred_at DESC
       LIMIT $3`,
      [tenantId, scoped, limit],
    );
    return {
      items: rows.map((r) => ({
        occurredAt: r.occurred_at,
        vendorId: r.vendor_id,
        type: r.type,
        status: r.status,
        reason:
          r.event_reason ??
          (r.status === 'pending'
            ? 'Awaiting processing'
            : r.status === 'failed'
              ? 'Action failed'
              : r.status === 'under_review'
                ? 'Under manual review'
                : null),
        amountMinor: r.amount_minor,
        amount: r.amount_minor,
        currency: r.currency,
        bookingReference: r.booking_ref ?? r.booking_id,
        booking_reference: r.booking_ref ?? r.booking_id,
        bookingId: r.booking_id,
        paymentId: r.payment_id,
        payoutId: r.payout_id,
        timestampMs: r.occurred_at.getTime(),
      })),
    };
  }

  async requestPayout(params: {
    tenantId: string;
    userId: string;
    vendorId?: string;
    amountMinor: string;
  }) {
    const managed = await this.managedVendorIds(params.tenantId, params.userId);
    const vendorId = params.vendorId ?? managed[0];
    if (!vendorId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'No managed vendor found' });
    }
    await this.financeState.ensurePayoutsAllowed();
    await this.vendorAccess.assertVendorOwnerOrStaff(params.tenantId, vendorId, params.userId);

    const summary = await this.calculateAvailableBalance(params.tenantId, [vendorId]);
    const available = summary.reduce((acc, i) => acc + BigInt(i.available_minor), 0n);
    const requested = BigInt(params.amountMinor);
    if (requested <= 0n) {
      throw new UnprocessableEntityException({
        code: 'INVALID_AMOUNT',
        message: 'Payout amount must be greater than zero',
      });
    }
    if (available < requested) {
      throw new UnprocessableEntityException({
        code: 'INSUFFICIENT_AVAILABLE_BALANCE',
        message: 'Requested amount exceeds available balance',
      });
    }

    const { rows } = await this.pool.query<{
      booking_id: string;
      tenant_id: string;
      vendor_id: string;
      payment_id: string;
      currency: string;
      subtotal_minor: string;
    }>(
      `SELECT b.id AS booking_id, b.tenant_id, b.vendor_id, p.id AS payment_id, b.currency, b.subtotal_minor::text
       FROM bookings b
       INNER JOIN payments p ON p.booking_id = b.id AND p.tenant_id = b.tenant_id AND p.status::text = 'captured'
       WHERE b.tenant_id = $1 AND b.vendor_id = $2
         AND b.status::text = 'completed'
         AND NOT EXISTS (
           SELECT 1 FROM payouts po
           WHERE po.booking_id = b.id AND po.status::text IN ('pending','processing','completed')
         )
         AND NOT EXISTS (
           SELECT 1 FROM disputes d
           WHERE d.booking_id = b.id AND d.status::text IN ('open','under_review','awaiting_evidence')
         )
       ORDER BY b.completed_at NULLS FIRST, b.updated_at ASC`,
      [params.tenantId, vendorId],
    );

    if (!rows.length) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'No eligible funds available for payout' });
    }

    let remaining = requested;
    const created: Array<{ payoutId: string; bookingId: string; amountMinor: string }> = [];
    for (const row of rows) {
      const rowAmount = BigInt(row.subtotal_minor);
      if (rowAmount > remaining) {
        continue;
      }
      const out = await this.payouts.enqueuePayoutForBooking(row, { adminOverride: false });
      if ('payoutId' in out) {
        created.push({ payoutId: out.payoutId, bookingId: row.booking_id, amountMinor: row.subtotal_minor });
        remaining -= rowAmount;
      }
      if (remaining === 0n) break;
    }

    if (remaining !== 0n) {
      throw new UnprocessableEntityException({
        code: 'AMOUNT_NOT_ALLOCATABLE',
        message: 'Requested amount cannot be composed from eligible payout units',
      });
    }

    return { ok: true, requestedMinor: requested.toString(), payouts: created };
  }
}
