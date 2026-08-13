import { Module, forwardRef } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { PaymentsModule } from '../payments/payments.module';
import { EventsModule } from '../events/events.module';
import { TenantFinancePolicyService } from './tenant-finance-policy.service';
import { TicketOrdersService } from './ticket-orders.service';
import { TicketPaymentsService } from './ticket-payments.service';
import { TicketEntitlementsService } from './ticket-entitlements.service';
import { TicketCommerceController } from './ticket-commerce.controller';
import { OrganizerFinanceController } from './organizer-finance.controller';
import { CommerceAuthService } from './commerce-auth.service';
import { CommerceAuthGuard } from './commerce-auth.guard';
import { OrganizerFinanceService } from './organizer-finance.service';
import { OrganizerPayoutService } from './organizer-payout.service';
import { OrganizerTicketSalesService } from './organizer-ticket-sales.service';
import { TicketRefundService } from './ticket-refund.service';
import { TicketRefundController } from './ticket-refund.controller';
import { FinanceExportService } from './finance-export.service';
import { FinanceExportController } from './finance-export.controller';

@Module({
  imports: [DatabaseModule, forwardRef(() => PaymentsModule), forwardRef(() => EventsModule)],
  controllers: [
    TicketCommerceController,
    OrganizerFinanceController,
    TicketRefundController,
    FinanceExportController,
  ],
  providers: [
    TenantFinancePolicyService,
    TicketOrdersService,
    TicketPaymentsService,
    TicketEntitlementsService,
    OrganizerTicketSalesService,
    OrganizerFinanceService,
    OrganizerPayoutService,
    TicketRefundService,
    FinanceExportService,
    CommerceAuthService,
    CommerceAuthGuard,
  ],
  exports: [
    TenantFinancePolicyService,
    TicketOrdersService,
    TicketPaymentsService,
    TicketEntitlementsService,
    OrganizerTicketSalesService,
    OrganizerFinanceService,
    OrganizerPayoutService,
    TicketRefundService,
    FinanceExportService,
    CommerceAuthService,
    CommerceAuthGuard,
  ],
})
export class CommerceModule {}
