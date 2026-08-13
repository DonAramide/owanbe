import { Module, forwardRef } from '@nestjs/common';
import { CommerceModule } from '../commerce/commerce.module';
import { EventsModule } from '../events/events.module';
import { VendorOperationsModule } from '../vendor-operations/vendor-operations.module';
import { OrganizerMarketingModule } from '../organizer-marketing/organizer-marketing.module';
import { OrganizerReportsController } from './organizer-reports.controller';
import { OrganizerReportsService } from './organizer-reports.service';

@Module({
  imports: [
    CommerceModule,
    EventsModule,
    VendorOperationsModule,
    forwardRef(() => OrganizerMarketingModule),
  ],
  controllers: [OrganizerReportsController],
  providers: [OrganizerReportsService],
  exports: [OrganizerReportsService],
})
export class OrganizerReportsModule {}
