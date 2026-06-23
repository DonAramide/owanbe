import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { CommerceModule } from '../commerce/commerce.module';
import { EventsModule } from '../events/events.module';
import { EventConfigController, AdminEventConfigController } from './event-config.controller';
import { EventConfigService } from './event-config.service';
import { VendorNegotiationsService } from './vendor-negotiations.service';

@Module({
  imports: [DatabaseModule, CommerceModule, EventsModule],
  controllers: [EventConfigController, AdminEventConfigController],
  providers: [EventConfigService, VendorNegotiationsService],
  exports: [EventConfigService],
})
export class EventConfigModule {}
