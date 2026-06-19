import { Injectable, Logger } from '@nestjs/common';
import { QfeFeatureFlagsService } from './qfe-feature-flags.service';
import { TreasuryLedgerWriterService } from './treasury-ledger-writer.service';
import { QfeFinancialWriterService } from './qfe-financial-writer.service';
import { TreasuryReconciliationService } from './treasury-reconciliation.service';
import type { DualWriteTreasuryContext, TreasurySettlementResult } from './qfe.types';

/**
 * QFE dual-write coordinator — treasury settlement path only (S5).
 * Legacy ledger always runs first; QFE financial layer is additive behind QFE_DUAL_WRITE_TREASURY.
 */
@Injectable()
export class FinancialDualWriteCoordinatorService {
  private readonly logger = new Logger(FinancialDualWriteCoordinatorService.name);

  constructor(
    private readonly flags: QfeFeatureFlagsService,
    private readonly ledgerWriter: TreasuryLedgerWriterService,
    private readonly financialWriter: QfeFinancialWriterService,
    private readonly treasuryReconcile: TreasuryReconciliationService,
  ) {}

  async coordinateTreasurySettlement(ctx: DualWriteTreasuryContext): Promise<TreasurySettlementResult> {
    const dualWriteEnabled = this.flags.isTreasuryDualWriteEnabled();
    const { settlementReference } = ctx.input;

    const { ledgerTransactionId, ledgerEntries } =
      await this.ledgerWriter.writePayoutReleaseJournal(ctx);

    if (!dualWriteEnabled) {
      return {
        skipped: false,
        reason: 'ledger_only',
        settlementReference,
        ledgerTransactionId,
        dualWriteEnabled: false,
        ledgerEntries,
      };
    }

    const { financialTransactionId } = await this.financialWriter.writeTreasurySettlementFinancial(
      ctx.input.client,
      { ctx, ledgerTransactionId, ledgerEntries },
    );

    const reconcile = await this.treasuryReconcile.assertPostingParity(ctx.input.client, {
      financialTransactionId,
      ledgerEntries,
    });

    if (!reconcile.ok) {
      await this.treasuryReconcile.recordTreasuryMismatch(ctx.input.client, {
        tenantId: ctx.input.tenantId,
        payoutId: ctx.input.payoutId,
        paymentId: ctx.input.paymentId,
        bookingId: ctx.input.bookingId,
        settlementReference,
        reconcile,
      });
      throw new Error('QFE_TREASURY_DUAL_WRITE_MISMATCH');
    }

    this.logger.log(
      {
        settlementReference,
        ledgerTransactionId,
        financialTransactionId,
      },
      'Treasury settlement dual-write posted',
    );

    return {
      skipped: false,
      reason: 'dual_write_posted',
      settlementReference,
      ledgerTransactionId,
      financialTransactionId,
      dualWriteEnabled: true,
      ledgerEntries,
    };
  }
}
