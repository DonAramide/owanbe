import { Module, forwardRef } from '@nestjs/common';
import { PaymentsModule } from '../payments/payments.module';
import { QfeFeatureFlagsService } from './qfe-feature-flags.service';
import { TreasuryLedgerWriterService } from './treasury-ledger-writer.service';
import { QfeFinancialWriterService } from './qfe-financial-writer.service';
import { TreasuryReconciliationService } from './treasury-reconciliation.service';
import { FinancialDualWriteCoordinatorService } from './financial-dual-write-coordinator.service';
import { FinancialTreasuryOrchestrationService } from './financial-treasury-orchestration.service';

@Module({
  imports: [forwardRef(() => PaymentsModule)],
  providers: [
    QfeFeatureFlagsService,
    TreasuryLedgerWriterService,
    QfeFinancialWriterService,
    TreasuryReconciliationService,
    FinancialDualWriteCoordinatorService,
    FinancialTreasuryOrchestrationService,
  ],
  exports: [FinancialTreasuryOrchestrationService, QfeFeatureFlagsService],
})
export class QfeModule {}
