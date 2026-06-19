import { Injectable } from '@nestjs/common';
import type { PoolClient } from 'pg';
import type { DualWriteTreasuryContext, LedgerEntrySnapshot } from './qfe.types';

@Injectable()
export class QfeFinancialWriterService {
  /**
   * Idempotent QFE header + postings for treasury settlement (mirrors ledger_entries).
   */
  async writeTreasurySettlementFinancial(
    client: PoolClient,
    params: {
      ctx: DualWriteTreasuryContext;
      ledgerTransactionId: string;
      ledgerEntries: LedgerEntrySnapshot[];
    },
  ): Promise<{ financialTransactionId: string }> {
    const { input } = params.ctx;
    const idem = input.settlementReference;
    const cur = input.currency.toUpperCase();
    const amt = input.amountMinor.toString();

    const ins = await client.query<{ id: string }>(
      `INSERT INTO financial_transactions (
         tenant_id, kind, status, idempotency_key, settlement_reference,
         currency, amount_minor, booking_id, payment_id, payout_id,
         ledger_transaction_id, metadata
       ) VALUES (
         $1, 'treasury_settlement', 'posted', $2, $3,
         $4, $5::bigint, $6, $7, $8,
         $9, $10::jsonb
       )
       ON CONFLICT (tenant_id, idempotency_key) DO NOTHING
       RETURNING id`,
      [
        input.tenantId,
        idem,
        input.settlementReference,
        cur,
        amt,
        input.bookingId,
        input.paymentId,
        input.payoutId,
        params.ledgerTransactionId,
        JSON.stringify({
          source: 'treasury_settlement_dual_write',
          payout_id: input.payoutId,
          webhook_event_id: input.webhookEventId ?? null,
        }),
      ],
    );

    let financialTransactionId = ins.rows[0]?.id;
    if (!financialTransactionId) {
      const ex = await client.query<{ id: string }>(
        `SELECT id FROM financial_transactions
         WHERE tenant_id = $1 AND idempotency_key = $2`,
        [input.tenantId, idem],
      );
      financialTransactionId = ex.rows[0]?.id;
    }
    if (!financialTransactionId) {
      throw new Error('financial_transactions upsert failed');
    }

    const { rows: postingCount } = await client.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM financial_transaction_postings WHERE financial_transaction_id = $1`,
      [financialTransactionId],
    );
    if (postingCount[0]?.n === '0') {
      let seq = 0;
      for (const entry of params.ledgerEntries) {
        await client.query(
          `INSERT INTO financial_transaction_postings (
             financial_transaction_id, sequence_no, ledger_account_id,
             direction, amount_minor, currency, memo
           ) VALUES ($1, $2, $3, $4, $5::bigint, $6, $7)`,
          [
            financialTransactionId,
            seq,
            entry.accountId,
            entry.direction,
            entry.amountMinor.toString(),
            entry.currency.toUpperCase(),
            entry.memo,
          ],
        );
        seq += 1;
      }
    }

    await client.query(
      `UPDATE financial_transactions
       SET ledger_transaction_id = COALESCE(ledger_transaction_id, $2),
           status = 'posted',
           updated_at = now()
       WHERE id = $1`,
      [financialTransactionId, params.ledgerTransactionId],
    );

    return { financialTransactionId };
  }
}
