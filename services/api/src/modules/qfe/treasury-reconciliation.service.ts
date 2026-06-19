import { Injectable, Logger } from '@nestjs/common';
import type { PoolClient } from 'pg';
import type { LedgerEntrySnapshot } from './qfe.types';

export interface TreasuryReconcileResult {
  ok: boolean;
  ledgerDebitTotal: bigint;
  ledgerCreditTotal: bigint;
  qfeDebitTotal: bigint;
  qfeCreditTotal: bigint;
}

/**
 * Inline treasury dual-write parity: ledger_entries (ledger_lines) vs financial_transaction_postings.
 */
@Injectable()
export class TreasuryReconciliationService {
  private readonly logger = new Logger(TreasuryReconciliationService.name);

  sumDirection(entries: LedgerEntrySnapshot[], direction: 'debit' | 'credit'): bigint {
    return entries
      .filter((e) => e.direction === direction)
      .reduce((acc, e) => acc + e.amountMinor, 0n);
  }

  async assertPostingParity(
    client: PoolClient,
    params: {
      financialTransactionId: string;
      ledgerEntries: LedgerEntrySnapshot[];
    },
  ): Promise<TreasuryReconcileResult> {
    const ledgerDebitTotal = this.sumDirection(params.ledgerEntries, 'debit');
    const ledgerCreditTotal = this.sumDirection(params.ledgerEntries, 'credit');

    const { rows } = await client.query<{
      direction: 'debit' | 'credit';
      total: string;
    }>(
      `SELECT direction, COALESCE(SUM(amount_minor), 0)::text AS total
       FROM financial_transaction_postings
       WHERE financial_transaction_id = $1
       GROUP BY direction`,
      [params.financialTransactionId],
    );

    const byDir = new Map(rows.map((r) => [r.direction, BigInt(r.total)]));
    const qfeDebitTotal = byDir.get('debit') ?? 0n;
    const qfeCreditTotal = byDir.get('credit') ?? 0n;

    const ok =
      ledgerDebitTotal === qfeDebitTotal &&
      ledgerCreditTotal === qfeCreditTotal &&
      ledgerDebitTotal === ledgerCreditTotal;

    if (!ok) {
      this.logger.error(
        {
          financialTransactionId: params.financialTransactionId,
          ledgerDebitTotal: ledgerDebitTotal.toString(),
          ledgerCreditTotal: ledgerCreditTotal.toString(),
          qfeDebitTotal: qfeDebitTotal.toString(),
          qfeCreditTotal: qfeCreditTotal.toString(),
        },
        'Treasury dual-write posting mismatch',
      );
    }

    return {
      ok,
      ledgerDebitTotal,
      ledgerCreditTotal,
      qfeDebitTotal,
      qfeCreditTotal,
    };
  }

  async recordTreasuryMismatch(
    client: PoolClient,
    params: {
      tenantId: string;
      payoutId: string;
      paymentId: string;
      bookingId: string;
      settlementReference: string;
      reconcile: TreasuryReconcileResult;
    },
  ): Promise<void> {
    const job = await client.query<{ id: string }>(
      `INSERT INTO reconciliation_jobs (
         tenant_id, provider, period_start, period_end, status, triggered_by, summary
       ) VALUES ($1, 'quaser', now(), now() + interval '1 millisecond', 'succeeded', 'system', $2::jsonb)
       RETURNING id`,
      [
        params.tenantId,
        JSON.stringify({
          source: 'treasury_dual_write',
          settlement_reference: params.settlementReference,
          reconcile: {
            ok: params.reconcile.ok,
            ledgerDebitTotal: params.reconcile.ledgerDebitTotal.toString(),
            ledgerCreditTotal: params.reconcile.ledgerCreditTotal.toString(),
            qfeDebitTotal: params.reconcile.qfeDebitTotal.toString(),
            qfeCreditTotal: params.reconcile.qfeCreditTotal.toString(),
          },
        }),
      ],
    );
    const jobId = job.rows[0]?.id;
    if (!jobId) return;

    await client.query(
      `INSERT INTO reconciliation_reports (
         job_id, tenant_id, issue_kind, severity, payment_id, booking_id,
         internal_reference, details, resolution_status
       ) VALUES ($1, $2, 'amount_mismatch', 'critical', $3, $4, $5, $6::jsonb, 'open')`,
      [
        jobId,
        params.tenantId,
        params.paymentId,
        params.bookingId,
        params.settlementReference,
        JSON.stringify({
          classification: 'qfe_treasury_dual_write_mismatch',
          payout_id: params.payoutId,
        }),
      ],
    );
  }
}
