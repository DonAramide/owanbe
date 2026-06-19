import { Injectable } from '@nestjs/common';
import { LedgerService } from '../payments/ledger.service';
import type { PoolClient } from 'pg';
import type { DualWriteTreasuryContext, LedgerEntrySnapshot } from './qfe.types';

/**
 * Legacy treasury ledger path (ledger_transactions + ledger_lines).
 * ledger_lines are the persisted ledger_entries in QFE v1.0 terminology.
 */
@Injectable()
export class TreasuryLedgerWriterService {
  constructor(private readonly ledger: LedgerService) {}

  async writePayoutReleaseJournal(
    ctx: DualWriteTreasuryContext,
  ): Promise<{ ledgerTransactionId: string; ledgerEntries: LedgerEntrySnapshot[] }> {
    const { input } = ctx;
    const ledgerTransactionId = await this.ledger.applyPayoutReleaseLedger(input.client, {
      tenantId: input.tenantId,
      bookingId: input.bookingId,
      paymentId: input.paymentId,
      payoutId: input.payoutId,
      amountMinor: input.amountMinor,
      currency: input.currency,
      escrowAccountId: ctx.escrowAccountId,
      vendorPayableAccountId: ctx.vendorPayableAccountId,
    });

    const { rows } = await input.client.query<{
      account_id: string;
      direction: 'debit' | 'credit';
      amount_minor: string;
      currency: string;
      memo: string;
    }>(
      `SELECT account_id, direction, amount_minor::text, currency, memo
       FROM ledger_lines
       WHERE transaction_id = $1
       ORDER BY created_at ASC`,
      [ledgerTransactionId],
    );

    const ledgerEntries: LedgerEntrySnapshot[] = rows.map((r) => ({
      accountId: r.account_id,
      direction: r.direction,
      amountMinor: BigInt(r.amount_minor),
      currency: r.currency,
      memo: r.memo,
    }));

    return { ledgerTransactionId, ledgerEntries };
  }
}
