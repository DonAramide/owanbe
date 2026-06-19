import { Module } from '@nestjs/common';
import { AuthModule } from '../../auth/auth.module';
import { OwnershipModule } from '../../ownership/ownership.module';
import { PaymentsController } from './payments.controller';
import { AdminFinanceController } from './admin-finance.controller';
import { QuaserWebhookController } from './quaser-webhook.controller';
import { PaymentsService } from './payments.service';
import { QuaserRouterService } from './quaser-router.service';
import { QuaserWebhookService } from './quaser-webhook.service';
import { LedgerService } from './ledger.service';
import { PayoutService } from './payout.service';
import { ReconciliationService } from './reconciliation.service';
import { AlertsService } from './alerts.service';
import { FinancialAdjustmentsService } from './financial-adjustments.service';
import { FinanceStateService } from './finance-state.service';
import { VendorFinanceController } from './vendor-finance.controller';
import { VendorFinanceService } from './vendor-finance.service';
import { ManualReviewService } from './manual-review.service';
import { FinanceTimeoutService } from './finance-timeout.service';
import { AdminFinanceDashboardService } from './admin-finance-dashboard.service';
import { DisputesService } from './disputes.service';
import { DisputesController } from './disputes.controller';
import { QfeModule } from '../qfe/qfe.module';

@Module({
  imports: [AuthModule, OwnershipModule, QfeModule],
  controllers: [
    PaymentsController,
    AdminFinanceController,
    QuaserWebhookController,
    VendorFinanceController,
    DisputesController,
  ],
  providers: [
    PaymentsService,
    QuaserRouterService,
    QuaserWebhookService,
    LedgerService,
    PayoutService,
    ReconciliationService,
    AlertsService,
    FinancialAdjustmentsService,
    FinanceStateService,
    VendorFinanceService,
    ManualReviewService,
    FinanceTimeoutService,
    AdminFinanceDashboardService,
    DisputesService,
  ],
  exports: [
    PaymentsService,
    PayoutService,
    LedgerService,
    ReconciliationService,
    AlertsService,
    FinancialAdjustmentsService,
    FinanceStateService,
    VendorFinanceService,
    ManualReviewService,
    AdminFinanceDashboardService,
    DisputesService,
  ],
})
export class PaymentsModule {}
