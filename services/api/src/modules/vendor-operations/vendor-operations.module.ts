import { Module, forwardRef } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { CommerceModule } from '../commerce/commerce.module';
import { EventsModule } from '../events/events.module';
import { VendorsModule } from '../vendors/vendors.module';
import { PaymentsModule } from '../payments/payments.module';
import { VendorOperationsController } from './vendor-operations.controller';
import { VendorCrmService } from './vendor-crm.service';
import { VendorCalendarService } from './vendor-calendar.service';
import {
  EventVendorFundsService,
  VendorPricingRulesService,
} from './vendor-pricing-funds.service';

@Module({
  imports: [
    DatabaseModule,
    CommerceModule,
    EventsModule,
    forwardRef(() => VendorsModule),
    forwardRef(() => PaymentsModule),
  ],
  controllers: [VendorOperationsController],
  providers: [
    VendorCrmService,
    VendorCalendarService,
    VendorPricingRulesService,
    EventVendorFundsService,
  ],
  exports: [
    VendorCrmService,
    VendorCalendarService,
    EventVendorFundsService,
    VendorPricingRulesService,
  ],
})
export class VendorOperationsModule {}
