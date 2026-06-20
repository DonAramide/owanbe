import { Injectable, Inject, Logger } from '@nestjs/common';
import type { Pool, PoolClient } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { LedgerService } from './ledger.service';
import { AuditLogService } from '../../audit/audit-log.service';
import { AlertsService } from './alerts.service';

@Injectable()
export class ReconciliationService {
  private readonly logger = new Logger(ReconciliationService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly ledger: LedgerService,
    private readonly audit: AuditLogService,
    private readonly alerts: AlertsService,
  ) {}

  /**
   * Inserts a minimal reconciliation job + report row (same DB txn as caller).
   */
  async recordInlineIssue(
    client: PoolClient,
    params: {
      tenantId: string;
      paymentId?: string;
      bookingId?: string;
      details: Record<string, unknown>;
      severity?: 'low' | 'medium' | 'high' | 'critical';
    },
  ): Promise<void> {
    const job = await client.query<{ id: string }>(
      `INSERT INTO reconciliation_jobs (
         tenant_id, provider, period_start, period_end, status, triggered_by, summary
       ) VALUES (
         $1, 'quaser', now(), now(), 'succeeded', 'system',
         $2::jsonb
       )
       RETURNING id`,
      [params.tenantId, JSON.stringify({ source: 'inline_webhook', ...params.details })],
    );
    const jobId = job.rows[0]?.id;
    if (!jobId) {
      this.logger.error('reconciliation_jobs insert failed');
      return;
    }

    await client.query(
      `INSERT INTO reconciliation_reports (
         job_id, tenant_id, issue_kind, severity, payment_id, booking_id, details, resolution_status
       ) VALUES ($1, $2, 'status_mismatch'::reconciliation_issue_kind, $3,
                 $4::uuid, $5::uuid, $6::jsonb, 'open')`,
      [
        jobId,
        params.tenantId,
        params.severity ?? 'critical',
        params.paymentId ?? null,
        params.bookingId ?? null,
        JSON.stringify({
          ...params.details,
          classification: 'booking_payment_state_mismatch',
        }),
      ],
    );
    if (params.paymentId) {
      await client.query(`UPDATE payments SET under_review = TRUE, updated_at = now() WHERE id = $1`, [
        params.paymentId,
      ]);
    }
    if (params.bookingId) {
      await client.query(
        `UPDATE payouts
         SET under_review = TRUE, updated_at = now()
         WHERE booking_id = $1 AND tenant_id = $2 AND status::text IN ('pending','processing')`,
        [params.bookingId, params.tenantId],
      );
    }
  }

  /**
   * Compare captured payments vs ledger capture txns for a window (PSP/internal truth).
   */
  async runLedgerPaymentConsistencyCheck(
    tenantId: string,
    actorUserId: string,
    periodStart: Date,
    periodEnd: Date,
  ): Promise<{ jobId: string; reportsInserted: number }> {
    const client = await this.pool.connect();
    let reportsInserted = 0;
    try {
      await client.query('BEGIN');
      const job = await client.query<{ id: string }>(
        `INSERT INTO reconciliation_jobs (
           tenant_id, provider, period_start, period_end, status, triggered_by, actor_user_id, summary
         ) VALUES ($1, 'quaser', $2, $3, 'running', 'manual', $4::uuid, '{}'::jsonb)
         RETURNING id`,
        [tenantId, periodStart, periodEnd, actorUserId],
      );
      const jobId = job.rows[0]?.id;
      if (!jobId) {
        throw new Error('job insert failed');
      }

      const missingLedger = await client.query<{ payment_id: string; booking_id: string }>(
        `SELECT p.id AS payment_id, p.booking_id
         FROM payments p
         WHERE p.tenant_id = $1
           AND p.status::text = 'captured'
           AND p.updated_at >= $2 AND p.updated_at < $3
           AND NOT EXISTS (
             SELECT 1 FROM ledger_transactions lt
             WHERE lt.payment_id = p.id AND lt.reason = 'payment_capture_quaser'
           )`,
        [tenantId, periodStart, periodEnd],
      );
      for (const row of missingLedger.rows) {
        await client.query(
          `INSERT INTO reconciliation_reports (
             job_id, tenant_id, issue_kind, severity, payment_id, booking_id, details, resolution_status
           ) VALUES ($1, $2, 'ledger_only_transaction'::reconciliation_issue_kind, 'high',
                     $3::uuid, $4::uuid, $5::jsonb, 'open')`,
          [
            jobId,
            tenantId,
            row.payment_id,
            row.booking_id,
            JSON.stringify({ check: 'captured_payment_missing_ledger_capture' }),
          ],
        );
        await client.query(
          `UPDATE payments
           SET under_review = TRUE,
               metadata = metadata || '{"reconciliation":"missing_capture_ledger"}'::jsonb,
               updated_at = now()
           WHERE id = $1`,
          [row.payment_id],
        );
        reportsInserted++;
      }

      const orphanLedger = await client.query<{ ledger_txn_id: string; payment_id: string | null }>(
        `SELECT lt.id AS ledger_txn_id, lt.payment_id
         FROM ledger_transactions lt
         LEFT JOIN payments p ON p.id = lt.payment_id
         WHERE lt.tenant_id = $1
           AND lt.reason = 'payment_capture_quaser'
           AND lt.created_at >= $2 AND lt.created_at < $3
           AND (p.id IS NULL OR p.status::text <> 'captured')`,
        [tenantId, periodStart, periodEnd],
      );
      for (const row of orphanLedger.rows) {
        await client.query(
          `INSERT INTO reconciliation_reports (
             job_id, tenant_id, issue_kind, severity, payment_id, ledger_txn_id, details, resolution_status
           ) VALUES ($1, $2, 'psp_only_transaction'::reconciliation_issue_kind, 'critical',
                     $3::uuid, $4::uuid, $5::jsonb, 'open')`,
          [
            jobId,
            tenantId,
            row.payment_id,
            row.ledger_txn_id,
            JSON.stringify({ check: 'ledger_capture_without_captured_payment' }),
          ],
        );
        if (row.payment_id) {
          await client.query(
            `UPDATE payments
             SET under_review = TRUE,
                 metadata = metadata || '{"reconciliation":"orphan_capture_ledger"}'::jsonb,
                 updated_at = now()
             WHERE id = $1`,
            [row.payment_id],
          );
        }
        reportsInserted++;
      }

      const missingTicketLedger = await client.query<{ ticket_payment_id: string; ticket_order_id: string }>(
        `SELECT tp.id AS ticket_payment_id, tp.ticket_order_id
         FROM ticket_payments tp
         WHERE tp.tenant_id = $1
           AND tp.status::text = 'captured'
           AND tp.updated_at >= $2 AND tp.updated_at < $3
           AND NOT EXISTS (
             SELECT 1 FROM ledger_transactions lt
             WHERE lt.ticket_order_id = tp.ticket_order_id
               AND lt.tenant_id = tp.tenant_id
               AND lt.reason = 'payment_capture_ticket'
           )`,
        [tenantId, periodStart, periodEnd],
      );
      for (const row of missingTicketLedger.rows) {
        await client.query(
          `INSERT INTO reconciliation_reports (
             job_id, tenant_id, issue_kind, severity, payment_id, details, resolution_status
           ) VALUES ($1, $2, 'ledger_only_transaction'::reconciliation_issue_kind, 'high',
                     NULL, $3::jsonb, 'open')`,
          [
            jobId,
            tenantId,
            JSON.stringify({
              check: 'captured_ticket_payment_missing_ledger_capture',
              ticket_payment_id: row.ticket_payment_id,
              ticket_order_id: row.ticket_order_id,
            }),
          ],
        );
        await client.query(
          `UPDATE ticket_payments
           SET under_review = TRUE,
               metadata = metadata || $2::jsonb,
               updated_at = now()
           WHERE id = $1`,
          [row.ticket_payment_id, JSON.stringify({ reconciliation: 'missing_capture_ledger' })],
        );
        reportsInserted++;
      }

      const orphanTicketLedger = await client.query<{
        ledger_txn_id: string;
        ticket_order_id: string | null;
        ticket_payment_id: string | null;
      }>(
        `SELECT lt.id AS ledger_txn_id, lt.ticket_order_id,
                (SELECT tp.id FROM ticket_payments tp
                 WHERE tp.ticket_order_id = lt.ticket_order_id AND tp.tenant_id = lt.tenant_id
                 ORDER BY tp.updated_at DESC LIMIT 1) AS ticket_payment_id
         FROM ledger_transactions lt
         WHERE lt.tenant_id = $1
           AND lt.reason = 'payment_capture_ticket'
           AND lt.created_at >= $2 AND lt.created_at < $3
           AND NOT EXISTS (
             SELECT 1 FROM ticket_payments tp
             WHERE tp.ticket_order_id = lt.ticket_order_id
               AND tp.tenant_id = lt.tenant_id
               AND tp.status::text = 'captured'
           )`,
        [tenantId, periodStart, periodEnd],
      );
      for (const row of orphanTicketLedger.rows) {
        await client.query(
          `INSERT INTO reconciliation_reports (
             job_id, tenant_id, issue_kind, severity, ledger_txn_id, details, resolution_status
           ) VALUES ($1, $2, 'psp_only_transaction'::reconciliation_issue_kind, 'critical',
                     $3::uuid, $4::jsonb, 'open')`,
          [
            jobId,
            tenantId,
            row.ledger_txn_id,
            JSON.stringify({
              check: 'ledger_ticket_capture_without_captured_payment',
              ticket_payment_id: row.ticket_payment_id,
            }),
          ],
        );
        if (row.ticket_payment_id) {
          await client.query(
            `UPDATE ticket_payments
             SET under_review = TRUE,
                 metadata = metadata || $2::jsonb,
                 updated_at = now()
             WHERE id = $1`,
            [row.ticket_payment_id, JSON.stringify({ reconciliation: 'orphan_capture_ledger' })],
          );
        }
        reportsInserted++;
      }

      const settlementMismatches = await client.query<{
        settlement_id: string;
        payout_id: string;
        ledger_transaction_id: string | null;
        financial_transaction_id: string | null;
      }>(
        `SELECT ts.id AS settlement_id, ts.payout_id, ts.ledger_transaction_id, ts.financial_transaction_id
         FROM treasury_settlements ts
         WHERE ts.tenant_id = $1
           AND ts.created_at >= $2 AND ts.created_at < $3
           AND ts.status::text IN ('journal_posted', 'reconciled')
           AND (
             ts.ledger_transaction_id IS NULL
             OR (ts.financial_transaction_id IS NULL AND ts.metadata->>'dual_write' = 'true')
           )`,
        [tenantId, periodStart, periodEnd],
      );
      for (const row of settlementMismatches.rows) {
        await client.query(
          `INSERT INTO reconciliation_reports (
             job_id, tenant_id, issue_kind, severity, details, resolution_status
           ) VALUES ($1, $2, 'status_mismatch'::reconciliation_issue_kind, 'high', $3::jsonb, 'open')`,
          [
            jobId,
            tenantId,
            JSON.stringify({
              check: 'treasury_settlement_dual_write_mismatch',
              settlement_id: row.settlement_id,
              payout_id: row.payout_id,
              ledger_transaction_id: row.ledger_transaction_id,
              financial_transaction_id: row.financial_transaction_id,
            }),
          ],
        );
        reportsInserted++;
      }

      await client.query(
        `UPDATE reconciliation_jobs
         SET status = 'succeeded',
             finished_at = now(),
             summary = summary || $2::jsonb
         WHERE id = $1`,
        [jobId, JSON.stringify({ reportsInserted })],
      );
      if (reportsInserted > 0) {
        await this.alerts.trigger(
          'reconciliation_mismatch',
          { tenantId, jobId, reportsInserted },
          'CRITICAL',
        );
      }
      await client.query('COMMIT');
      return { jobId, reportsInserted };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  async recoverMissingCaptureLedger(params: {
    tenantId: string;
    paymentId: string;
    actorUserId: string;
    escalateIfFailed?: boolean;
  }): Promise<{ ok: boolean; recovered?: boolean; reason?: string }> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query<{
        id: string;
        booking_id: string;
        currency: string;
        amount_captured_minor: string;
        status: string;
      }>(
        `SELECT id, booking_id, currency, amount_captured_minor::text, status::text
         FROM payments
         WHERE id = $1 AND tenant_id = $2
         FOR UPDATE`,
        [params.paymentId, params.tenantId],
      );
      const p = rows[0];
      if (!p || p.status !== 'captured') {
        await client.query('ROLLBACK');
        return { ok: false, reason: 'payment_not_captured' };
      }
      const exists = await client.query(
        `SELECT 1 FROM ledger_transactions
         WHERE payment_id = $1 AND tenant_id = $2 AND reason = 'payment_capture_quaser'
         LIMIT 1`,
        [p.id, params.tenantId],
      );
      if (exists.rowCount) {
        await client.query('COMMIT');
        return { ok: true, recovered: false, reason: 'already_present' };
      }

      const bk = await client.query<{ platform_fee_minor: string }>(
        `SELECT platform_fee_minor::text FROM bookings WHERE id = $1 AND tenant_id = $2`,
        [p.booking_id, params.tenantId],
      );
      const fee = BigInt(bk.rows[0]?.platform_fee_minor ?? '0');
      const gross = BigInt(p.amount_captured_minor);
      const accounts = await this.ledger.ensurePoolLedgerAccounts(client, params.tenantId, p.currency);
      await client.query(
        `SELECT owanbe_apply_quaser_payment_capture(
           $1::uuid, $2::uuid, 'quaser'::payment_provider,
           $3, 'reconcile.recover.capture', $4::jsonb,
           $5::uuid, $6::uuid, $7::uuid,
           $8::bigint, $9::bigint
         )`,
        [
          p.id,
          params.tenantId,
          `reconcile-recover-${p.id}`,
          JSON.stringify({ recoveredBy: params.actorUserId }),
          accounts.pspClearingId,
          accounts.escrowPoolId,
          accounts.platformFeesId,
          gross.toString(),
          fee.toString(),
        ],
      );
      await client.query(`UPDATE payments SET under_review = FALSE, updated_at = now() WHERE id = $1`, [p.id]);
      await this.audit.logAction({
        tenantId: params.tenantId,
        actorUserId: params.actorUserId,
        action: 'RECONCILIATION_RECOVERY_CAPTURE',
        resourceType: 'payment',
        resourceId: p.id,
      });
      await client.query('COMMIT');
      return { ok: true, recovered: true };
    } catch (e) {
      await client.query('ROLLBACK');
      if (params.escalateIfFailed) {
        await this.pool.query(
          `UPDATE payments
           SET under_review = TRUE,
               metadata = metadata || '{"reconciliation":"manual_review_required"}'::jsonb,
               updated_at = now()
           WHERE id = $1 AND tenant_id = $2`,
          [params.paymentId, params.tenantId],
        );
      }
      await this.alerts.trigger(
        'reconciliation_mismatch',
        { tenantId: params.tenantId, paymentId: params.paymentId, error: (e as Error).message },
        'CRITICAL',
      );
      return { ok: false, reason: 'recovery_failed' };
    } finally {
      client.release();
    }
  }
}
