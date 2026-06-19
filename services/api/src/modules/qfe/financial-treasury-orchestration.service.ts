import { Injectable, Logger } from '@nestjs/common';
import { LedgerService } from '../payments/ledger.service';
import { FinancialDualWriteCoordinatorService } from './financial-dual-write-coordinator.service';
import type {
  DualWriteTreasuryContext,
  TreasurySettlementInput,
  TreasurySettlementResult,
} from './qfe.types';

export function treasurySettlementReference(payoutId: string): string {
  return `treasury_settlement:${payoutId}`;
}

/**
 * Treasury settlement orchestration — postSettlementJournal is the only S5 migration surface.
 */
@Injectable()
export class FinancialTreasuryOrchestrationService {
  private readonly logger = new Logger(FinancialTreasuryOrchestrationService.name);

  constructor(
    private readonly ledger: LedgerService,
    private readonly coordinator: FinancialDualWriteCoordinatorService,
  ) {}

  /**
   * Posts treasury settlement journal (escrow → vendor_payable) with optional QFE dual-write.
   * Preserves ledger_entries (ledger_lines), payout settlement status, and treasury reconciliation rows.
   */
  async postSettlementJournal(input: TreasurySettlementInput): Promise<TreasurySettlementResult> {
    const settlementReference =
      input.settlementReference || treasurySettlementReference(input.payoutId);

    const existing = await this.findExistingTreasurySettlement(input.client, input.tenantId, input.payoutId);
    if (existing?.status === 'journal_posted' || existing?.status === 'reconciled') {
      return {
        skipped: true,
        reason: 'already_posted',
        settlementReference: existing.settlement_reference,
        ledgerTransactionId: existing.ledger_transaction_id ?? undefined,
        financialTransactionId: existing.financial_transaction_id ?? undefined,
        treasurySettlementId: existing.id,
        dualWriteEnabled: false,
      };
    }

    const escrow = await this.ledger.ensurePoolLedgerAccounts(
      input.client,
      input.tenantId,
      input.currency,
    );
    const vendorPayable = await this.ledger.ensureVendorPayableAccount(
      input.client,
      input.tenantId,
      input.vendorId,
      input.currency,
    );

    const treasurySettlementId = await this.upsertTreasurySettlementPending(input.client, {
      ...input,
      settlementReference,
    });

    const ctx: DualWriteTreasuryContext = {
      input: { ...input, settlementReference },
      escrowAccountId: escrow.escrowPoolId,
      vendorPayableAccountId: vendorPayable,
    };

    let result: TreasurySettlementResult;
    try {
      result = await this.coordinator.coordinateTreasurySettlement(ctx);
    } catch (e) {
      await this.markTreasurySettlementStatus(input.client, treasurySettlementId, 'mismatch', {
        error: String((e as Error).message).slice(0, 500),
      });
      throw e;
    }

    await this.markTreasurySettlementPosted(input.client, {
      treasurySettlementId,
      ledgerTransactionId: result.ledgerTransactionId!,
      financialTransactionId: result.financialTransactionId,
      dualWrite: result.dualWriteEnabled,
    });

    return {
      ...result,
      treasurySettlementId,
      settlementReference,
    };
  }

  private async findExistingTreasurySettlement(
    client: TreasurySettlementInput['client'],
    tenantId: string,
    payoutId: string,
  ) {
    const { rows } = await client.query<{
      id: string;
      settlement_reference: string;
      status: string;
      ledger_transaction_id: string | null;
      financial_transaction_id: string | null;
    }>(
      `SELECT id, settlement_reference, status::text, ledger_transaction_id, financial_transaction_id
       FROM treasury_settlements
       WHERE tenant_id = $1 AND payout_id = $2`,
      [tenantId, payoutId],
    );
    return rows[0];
  }

  private async upsertTreasurySettlementPending(
    client: TreasurySettlementInput['client'],
    input: TreasurySettlementInput & { settlementReference: string },
  ): Promise<string> {
    const cur = input.currency.toUpperCase();
    const ins = await client.query<{ id: string }>(
      `INSERT INTO treasury_settlements (
         tenant_id, payout_id, settlement_reference, status,
         currency, amount_minor, metadata
       ) VALUES ($1, $2, $3, 'pending', $4, $5::bigint, $6::jsonb)
       ON CONFLICT (payout_id) DO UPDATE
         SET updated_at = now(),
             metadata = treasury_settlements.metadata || EXCLUDED.metadata
       RETURNING id`,
      [
        input.tenantId,
        input.payoutId,
        input.settlementReference,
        cur,
        input.amountMinor.toString(),
        JSON.stringify({ webhook_event_id: input.webhookEventId ?? null }),
      ],
    );
    const id = ins.rows[0]?.id;
    if (!id) throw new Error('treasury_settlements upsert failed');
    return id;
  }

  private async markTreasurySettlementPosted(
    client: TreasurySettlementInput['client'],
    params: {
      treasurySettlementId: string;
      ledgerTransactionId: string;
      financialTransactionId?: string;
      dualWrite: boolean;
    },
  ): Promise<void> {
    await client.query(
      `UPDATE treasury_settlements
       SET status = CASE WHEN $4 THEN 'reconciled'::treasury_settlement_status ELSE 'journal_posted'::treasury_settlement_status END,
           ledger_transaction_id = COALESCE(ledger_transaction_id, $2),
           financial_transaction_id = COALESCE(financial_transaction_id, $3),
           posted_at = COALESCE(posted_at, now()),
           reconciled_at = CASE WHEN $4 THEN COALESCE(reconciled_at, now()) ELSE reconciled_at END,
           updated_at = now()
       WHERE id = $1`,
      [
        params.treasurySettlementId,
        params.ledgerTransactionId,
        params.financialTransactionId ?? null,
        params.dualWrite,
      ],
    );
  }

  private async markTreasurySettlementStatus(
    client: TreasurySettlementInput['client'],
    treasurySettlementId: string,
    status: 'mismatch',
    metadata: Record<string, unknown>,
  ): Promise<void> {
    await client.query(
      `UPDATE treasury_settlements
       SET status = $2::treasury_settlement_status,
           metadata = metadata || $3::jsonb,
           updated_at = now()
       WHERE id = $1`,
      [treasurySettlementId, status, JSON.stringify(metadata)],
    );
  }
}
