import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { CommerceModule } from '../commerce/commerce.module';
import { EventsModule } from '../events/events.module';
import { VendorOperationsController } from './vendor-operations.controller';
import { VendorCrmService } from './vendor-crm.service';
import { VendorCalendarService } from './vendor-calendar.service';

@Module({
  imports: [DatabaseModule, CommerceModule, EventsModule],
  controllers: [VendorOperationsController],
  providers: [VendorCrmService, VendorCalendarService],
  exports: [VendorCrmService, VendorCalendarService],
})
export class VendorOperationsModule {}
