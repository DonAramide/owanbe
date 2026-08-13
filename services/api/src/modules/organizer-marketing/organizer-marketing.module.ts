import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { IntegrationsModule } from '../../integrations/integrations.module';
import { EventsModule } from '../events/events.module';
import { CommerceModule } from '../commerce/commerce.module';
import { OrganizerMarketingController } from './organizer-marketing.controller';
import { OrganizerMarketingService } from './organizer-marketing.service';

@Module({
  imports: [DatabaseModule, IntegrationsModule, EventsModule, CommerceModule],
  controllers: [OrganizerMarketingController],
  providers: [OrganizerMarketingService],
  exports: [OrganizerMarketingService],
})
export class OrganizerMarketingModule {}
