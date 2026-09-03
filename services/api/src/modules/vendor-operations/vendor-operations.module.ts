import { Module, forwardRef } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { CommerceModule } from '../commerce/commerce.module';
import { EventsModule } from '../events/events.module';
import { VendorsModule } from '../vendors/vendors.module';
import { PaymentsModule } from '../payments/payments.module';
import { RentalsModule } from '../rentals/rentals.module';
import { VendorOperationsController } from './vendor-operations.controller';
import { VendorCrmService } from './vendor-crm.service';
import { VendorCalendarService } from './vendor-calendar.service';
import { VendorAvailabilityService } from './vendor-availability.service';
import { VendorChangeRequestService } from './vendor-change-request.service';
import { VendorOfferingsService } from './vendor-offerings.service';
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
    RentalsModule,
  ],
  controllers: [VendorOperationsController],
  providers: [
    VendorCrmService,
    VendorCalendarService,
    VendorPricingRulesService,
    EventVendorFundsService,
    VendorAvailabilityService,
    VendorChangeRequestService,
    VendorOfferingsService,
  ],
  exports: [
    VendorCrmService,
    VendorCalendarService,
    EventVendorFundsService,
    VendorPricingRulesService,
    VendorAvailabilityService,
    VendorChangeRequestService,
    VendorOfferingsService,
  ],
})
export class VendorOperationsModule {}
