import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

type SortDir = 'asc' | 'desc';
type PaginationMeta = { total: number; totalPages: number; page: number; limit: number };
const ALLOWED_SORT_FIELDS = ['created_at', 'amount', 'status', 'type'] as const;
type AllowedSortField = (typeof ALLOWED_SORT_FIELDS)[number];

@Injectable()
export class AdminFinanceDashboardService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async summary(tenantId: string): Promise<Record<string, unknown>> {
    const [{ rows: volume }, { rows: escrow }, { rows: pending }, { rows: underReview }, { rows: failed }] =
      await Promise.all([
        this.pool.query<{ total_volume_minor: string }>(
          `SELECT COALESCE(SUM(amount_captured_minor), 0)::text AS total_volume_minor
           FROM payments
           WHERE tenant_id = $1
             AND status::text IN ('captured','partially_refunded','refunded')
             AND created_at >= date_trunc('day', now())`,
          [tenantId],
        ),
        this.pool.query<{ escrow_balance_minor: string }>(
          `WITH esc AS (
             SELECT id FROM ledger_accounts
             WHERE tenant_id = $1 AND kind = 'escrow'
           )
           SELECT COALESCE(SUM(CASE WHEN ll.direction='credit' THEN ll.amount_minor ELSE -ll.amount_minor END), 0)::text AS escrow_balance_minor
           FROM ledger_lines ll
           INNER JOIN esc ON esc.id = ll.account_id`,
          [tenantId],
        ),
        this.pool.query<{ pending_payout_count: string; pending_payout_minor: string }>(
          `SELECT COUNT(*)::text AS pending_payout_count,
                  COALESCE(SUM(amount_minor),0)::text AS pending_payout_minor
           FROM payouts
           WHERE tenant_id = $1 AND status::text IN ('pending','processing')`,
          [tenantId],
        ),
        this.pool.query<{ under_review_count: string; under_review_minor: string }>(
          `SELECT
             (SELECT COUNT(*) FROM payments WHERE tenant_id = $1 AND under_review = TRUE)::text
             || '/' ||
             (SELECT COUNT(*) FROM payouts WHERE tenant_id = $1 AND under_review = TRUE)::text AS under_review_count,
             (
               COALESCE((SELECT SUM(amount_captured_minor) FROM payments WHERE tenant_id = $1 AND under_review = TRUE),0)
               + COALESCE((SELECT SUM(amount_minor) FROM payouts WHERE tenant_id = $1 AND under_review = TRUE),0)
             )::text AS under_review_minor`,
          [tenantId],
        ),
        this.pool.query<{ failed_count: string; failed_minor: string }>(
          `SELECT
             (SELECT COUNT(*) FROM payments WHERE tenant_id = $1 AND status::text = 'failed')
             + (SELECT COUNT(*) FROM payouts WHERE tenant_id = $1 AND status::text = 'failed') AS failed_count,
             (
               COALESCE((SELECT SUM(amount_captured_minor) FROM payments WHERE tenant_id = $1 AND status::text = 'failed'),0)
               + COALESCE((SELECT SUM(amount_minor) FROM payouts WHERE tenant_id = $1 AND status::text = 'failed'),0)
             )::text AS failed_minor`,
          [tenantId],
        ),
      ]);

    return {
      totalVolumeMinor: volume[0]?.total_volume_minor ?? '0',
      escrowBalanceMinor: escrow[0]?.escrow_balance_minor ?? '0',
      pendingPayoutCount: pending[0]?.pending_payout_count ?? '0',
      pendingPayoutMinor: pending[0]?.pending_payout_minor ?? '0',
      underReviewCount: underReview[0]?.under_review_count ?? '0/0',
      underReviewMinor: underReview[0]?.under_review_minor ?? '0',
      failedCount: String(failed[0]?.failed_count ?? 0),
      failedMinor: failed[0]?.failed_minor ?? '0',
    };
  }

  async alerts(
    tenantId: string,
    page = 1,
    limit = 50,
  ): Promise<PaginationMeta & { items: Array<Record<string, unknown>> }> {
    const offset = (page - 1) * limit;
    const { rows: countRows } = await this.pool.query<{ total: string }>(
      `WITH raw AS (
         SELECT 'reconciliation_issue'::text AS type
         FROM reconciliation_reports rr
         WHERE rr.tenant_id = $1 AND rr.resolution_status::text = 'open'
         UNION ALL
         SELECT 'payout_failure'::text AS type
         FROM payouts p
         WHERE p.tenant_id = $1 AND p.status::text = 'failed'
         UNION ALL
         SELECT 'payment_under_review'::text AS type
         FROM payments p
         WHERE p.tenant_id = $1 AND p.under_review = TRUE
       )
       SELECT COUNT(*)::text AS total
       FROM (SELECT type FROM raw GROUP BY type) x`,
      [tenantId],
    );
    const total = Number(countRows[0]?.total ?? 0);
    const totalPages = Math.max(1, Math.ceil(total / limit));

    const { rows } = await this.pool.query<{
      type: string;
      count: string;
      latest_occurrence: Date;
      severity: string;
    }>(
      `WITH raw AS (
         SELECT 'reconciliation_issue'::text AS type,
                CASE WHEN rr.severity IN ('high','critical') THEN 'CRITICAL' ELSE 'WARNING' END AS severity,
                rr.created_at
         FROM reconciliation_reports rr
         WHERE rr.tenant_id = $1 AND rr.resolution_status::text = 'open'
         UNION ALL
         SELECT 'payout_failure'::text, 'WARNING'::text, p.created_at
         FROM payouts p
         WHERE p.tenant_id = $1 AND p.status::text = 'failed'
         UNION ALL
         SELECT 'payment_under_review'::text, 'CRITICAL'::text, p.created_at
         FROM payments p
         WHERE p.tenant_id = $1 AND p.under_review = TRUE
       )
       SELECT
         r.type,
         COUNT(*)::text AS count,
         MAX(r.created_at) AS latest_occurrence,
         CASE
           WHEN BOOL_OR(r.severity = 'CRITICAL') THEN 'CRITICAL'
           WHEN BOOL_OR(r.severity = 'WARNING') THEN 'WARNING'
           ELSE 'INFO'
         END AS severity
       FROM raw r
       GROUP BY r.type
       ORDER BY latest_occurrence DESC
       OFFSET $2
       LIMIT $3`,
      [tenantId, offset, limit],
    );
    return { total, totalPages, page, limit, items: rows };
  }

  async transactions(params: {
    tenantId: string;
    page: number;
    limit: number;
    type?: string;
    status?: string;
    sortBy?: string;
    sortDir?: SortDir;
    fromDate?: Date;
    toDate?: Date;
  }): Promise<PaginationMeta & { items: Array<Record<string, unknown>> }> {
    const offset = (params.page - 1) * params.limit;
    const requestedSort = (params.sortBy ?? 'created_at').toLowerCase();
    const sortBy: AllowedSortField = (ALLOWED_SORT_FIELDS as readonly string[]).includes(requestedSort)
      ? (requestedSort as AllowedSortField)
      : 'created_at';
    const sortDir = (params.sortDir ?? 'desc').toLowerCase() === 'asc' ? 'ASC' : 'DESC';
    const sortColumn =
      sortBy === 'amount'
        ? 'amount_minor'
        : sortBy === 'status'
          ? 'status'
          : sortBy === 'type'
            ? 'type'
            : 'created_at';

    const { rows: countRows } = await this.pool.query<{ total: string }>(
      `WITH timeline AS (
         SELECT 'payment'::text AS type, p.status::text AS status
         FROM payments p
         WHERE p.tenant_id = $1
           AND ($4::timestamptz IS NULL OR p.created_at >= $4)
           AND ($5::timestamptz IS NULL OR p.created_at < $5)
         UNION ALL
         SELECT 'payout'::text AS type, po.status::text AS status
         FROM payouts po
         WHERE po.tenant_id = $1
           AND ($4::timestamptz IS NULL OR po.created_at >= $4)
           AND ($5::timestamptz IS NULL OR po.created_at < $5)
         UNION ALL
         SELECT CASE WHEN lt.reason = 'payment_refund' THEN 'refund' ELSE 'chargeback' END AS type,
                'posted'::text AS status
         FROM ledger_transactions lt
         WHERE lt.tenant_id = $1
           AND lt.reason IN ('payment_refund','payment_chargeback')
           AND ($4::timestamptz IS NULL OR lt.created_at >= $4)
           AND ($5::timestamptz IS NULL OR lt.created_at < $5)
       )
       SELECT COUNT(*)::text AS total
       FROM timeline t
       WHERE ($2::text IS NULL OR t.type = $2)
         AND ($3::text IS NULL OR t.status = $3)`,
      [params.tenantId, params.type ?? null, params.status ?? null, params.fromDate ?? null, params.toDate ?? null],
    );
    const total = Number(countRows[0]?.total ?? 0);
    const totalPages = Math.max(1, Math.ceil(total / params.limit));

    const { rows } = await this.pool.query<{
      transaction_id: string;
      user_label: string;
      amount_minor: string;
      type: string;
      status: string;
      created_at: Date;
      booking_id: string | null;
      under_review: boolean;
    }>(
      `SELECT * FROM (
         SELECT ('payment_' || p.id::text) AS transaction_id,
                'payment'::text AS source_type,
                COALESCE(u.display_name, u.email, p.booking_id::text) AS user_label,
                p.amount_captured_minor::text AS amount_minor,
                'payment'::text AS type,
                p.status::text AS status,
                p.created_at,
                p.booking_id::text AS booking_id,
                p.booking_id::text AS booking_reference,
                p.under_review
         FROM payments p
         LEFT JOIN bookings b ON b.id = p.booking_id
         LEFT JOIN users u ON u.id = b.client_user_id
         WHERE p.tenant_id = $1
           AND ($4::timestamptz IS NULL OR p.created_at >= $4)
           AND ($5::timestamptz IS NULL OR p.created_at < $5)
         UNION ALL
         SELECT ('payout_' || po.id::text) AS transaction_id,
                'payout'::text AS source_type,
                COALESCE(v.business_name, po.vendor_id::text) AS user_label,
                po.amount_minor::text AS amount_minor,
                'payout'::text AS type,
                po.status::text AS status,
                po.created_at,
                po.booking_id::text AS booking_id,
                po.booking_id::text AS booking_reference,
                po.under_review
         FROM payouts po
         LEFT JOIN vendors v ON v.id = po.vendor_id
         WHERE po.tenant_id = $1
           AND ($4::timestamptz IS NULL OR po.created_at >= $4)
           AND ($5::timestamptz IS NULL OR po.created_at < $5)
         UNION ALL
         SELECT (CASE WHEN lt.reason = 'payment_refund' THEN 'refund_' ELSE 'chargeback_' END || lt.id::text) AS transaction_id,
                CASE WHEN lt.reason = 'payment_refund' THEN 'refund' ELSE 'chargeback' END AS source_type,
                COALESCE(v.business_name, 'Vendor') AS user_label,
                ABS(SUM(CASE WHEN ll.direction = 'credit' THEN ll.amount_minor ELSE -ll.amount_minor END))::text AS amount_minor,
                CASE WHEN lt.reason = 'payment_refund' THEN 'refund' ELSE 'chargeback' END AS type,
                'posted'::text AS status,
                lt.created_at,
                lt.booking_id::text AS booking_id,
                lt.booking_id::text AS booking_reference,
                FALSE AS under_review
         FROM ledger_transactions lt
         INNER JOIN ledger_lines ll ON ll.transaction_id = lt.id
         LEFT JOIN bookings b ON b.id = lt.booking_id
         LEFT JOIN vendors v ON v.id = b.vendor_id
         WHERE lt.tenant_id = $1
           AND lt.reason IN ('payment_refund','payment_chargeback')
           AND ($4::timestamptz IS NULL OR lt.created_at >= $4)
           AND ($5::timestamptz IS NULL OR lt.created_at < $5)
         GROUP BY lt.id, lt.reason, lt.created_at, lt.booking_id, v.business_name
       ) t
       WHERE ($2::text IS NULL OR t.type = $2)
         AND ($3::text IS NULL OR t.status = $3)
       ORDER BY ${sortColumn} ${sortDir}
       OFFSET $6
       LIMIT $7`,
      [
        params.tenantId,
        params.type ?? null,
        params.status ?? null,
        params.fromDate ?? null,
        params.toDate ?? null,
        offset,
        params.limit,
      ],
    );

    return { total, totalPages, page: params.page, limit: params.limit, items: rows };
  }

  async reviews(
    tenantId: string,
    page = 1,
    limit = 100,
    fromDate?: Date,
    toDate?: Date,
  ): Promise<PaginationMeta & { items: Array<Record<string, unknown>> }> {
    const offset = (page - 1) * limit;
    const { rows: countRows } = await this.pool.query<{ total: string }>(
      `SELECT COUNT(*)::text AS total
       FROM payments p
       WHERE p.tenant_id = $1
         AND p.under_review = TRUE
         AND ($2::timestamptz IS NULL OR p.created_at >= $2)
         AND ($3::timestamptz IS NULL OR p.created_at < $3)`,
      [tenantId, fromDate ?? null, toDate ?? null],
    );
    const total = Number(countRows[0]?.total ?? 0);
    const totalPages = Math.max(1, Math.ceil(total / limit));

    const { rows } = await this.pool.query(
      `SELECT p.id::text AS payment_id,
              p.amount_captured_minor::text AS amount_minor,
              p.currency,
              p.updated_at,
              b.id::text AS booking_id,
              b.vendor_id::text AS vendor_id,
              COALESCE(p.metadata->'reconciliation'->>'reason', p.metadata->'booking_confirm_inconsistency'->>'observed_booking_status', 'manual_review') AS reason
       FROM payments p
       LEFT JOIN bookings b ON b.id = p.booking_id
       WHERE p.tenant_id = $1
         AND p.under_review = TRUE
         AND ($4::timestamptz IS NULL OR p.created_at >= $4)
         AND ($5::timestamptz IS NULL OR p.created_at < $5)
       ORDER BY p.updated_at DESC
       OFFSET $2
       LIMIT $3`,
      [tenantId, offset, limit, fromDate ?? null, toDate ?? null],
    );
    return { total, totalPages, page, limit, items: rows };
  }

  async reconciliation(
    tenantId: string,
    page = 1,
    limit = 100,
    fromDate?: Date,
    toDate?: Date,
  ): Promise<PaginationMeta & { items: unknown[] }> {
    const offset = (page - 1) * limit;
    const { rows: countRows } = await this.pool.query<{ total: string }>(
      `SELECT COUNT(*)::text AS total
       FROM reconciliation_reports rr
       WHERE rr.tenant_id = $1
         AND ($2::timestamptz IS NULL OR rr.created_at >= $2)
         AND ($3::timestamptz IS NULL OR rr.created_at < $3)`,
      [tenantId, fromDate ?? null, toDate ?? null],
    );
    const total = Number(countRows[0]?.total ?? 0);
    const totalPages = Math.max(1, Math.ceil(total / limit));

    const { rows } = await this.pool.query(
      `SELECT rr.id::text AS report_id,
              rr.issue_kind::text AS issue_kind,
              rr.severity,
              rr.expected_minor::text AS expected_amount,
              rr.actual_minor::text AS actual_amount,
              rr.delta_minor::text AS difference,
              rr.payment_id::text,
              rr.booking_id::text,
              rr.resolution_status::text AS status,
              rr.created_at
       FROM reconciliation_reports rr
       WHERE rr.tenant_id = $1
         AND ($4::timestamptz IS NULL OR rr.created_at >= $4)
         AND ($5::timestamptz IS NULL OR rr.created_at < $5)
       ORDER BY rr.created_at DESC
       OFFSET $2
       LIMIT $3`,
      [tenantId, offset, limit, fromDate ?? null, toDate ?? null],
    );
    return { total, totalPages, page, limit, items: rows };
  }

  async payments(
    tenantId: string,
    page = 1,
    limit = 100,
  ): Promise<PaginationMeta & { items: Array<Record<string, unknown>> }> {
    const offset = (page - 1) * limit;
    const { rows: countRows } = await this.pool.query<{ total: string }>(
      `SELECT COUNT(*)::text AS total FROM payments WHERE tenant_id = $1`,
      [tenantId],
    );
    const total = Number(countRows[0]?.total ?? 0);
    const totalPages = Math.max(1, Math.ceil(total / limit));
    const { rows } = await this.pool.query(
      `SELECT id, booking_id, status::text, currency, amount_captured_minor::text, amount_refunded_minor::text,
              idempotency_key, quaser_reference, under_review, created_at, updated_at
       FROM payments
       WHERE tenant_id = $1
       ORDER BY created_at DESC
       OFFSET $2
       LIMIT $3`,
      [tenantId, offset, limit],
    );
    return { total, totalPages, page, limit, items: rows };
  }

  async payouts(
    tenantId: string,
    page = 1,
    limit = 100,
    fromDate?: Date,
    toDate?: Date,
  ): Promise<PaginationMeta & { items: Array<Record<string, unknown>> }> {
    const offset = (page - 1) * limit;
    const { rows: countRows } = await this.pool.query<{ total: string }>(
      `SELECT COUNT(*)::text AS total
       FROM payouts
       WHERE tenant_id = $1
         AND ($2::timestamptz IS NULL OR created_at >= $2)
         AND ($3::timestamptz IS NULL OR created_at < $3)`,
      [tenantId, fromDate ?? null, toDate ?? null],
    );
    const total = Number(countRows[0]?.total ?? 0);
    const totalPages = Math.max(1, Math.ceil(total / limit));
    const { rows } = await this.pool.query(
      `SELECT id, booking_id, vendor_id, payment_id, status::text, currency, amount_minor::text,
              quaser_reference, failure_code, failure_message, under_review, created_at, updated_at
       FROM payouts
       WHERE tenant_id = $1
         AND ($4::timestamptz IS NULL OR created_at >= $4)
         AND ($5::timestamptz IS NULL OR created_at < $5)
       ORDER BY created_at DESC
       OFFSET $2
       LIMIT $3`,
      [tenantId, offset, limit, fromDate ?? null, toDate ?? null],
    );
    return { total, totalPages, page, limit, items: rows };
  }

  async paymentById(tenantId: string, paymentId: string): Promise<Record<string, unknown> | null> {
    const { rows } = await this.pool.query(
      `SELECT id, booking_id, status::text, currency, amount_captured_minor::text, amount_refunded_minor::text,
              under_review, metadata, updated_at
       FROM payments
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, paymentId],
    );
    return rows[0] ?? null;
  }

  async payoutById(tenantId: string, payoutId: string): Promise<Record<string, unknown> | null> {
    const { rows } = await this.pool.query(
      `SELECT id, booking_id, vendor_id, payment_id, status::text, amount_minor::text, currency,
              under_review, failure_code, failure_message, updated_at
       FROM payouts
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, payoutId],
    );
    return rows[0] ?? null;
  }
}
