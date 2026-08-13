import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { AuditModule } from '../../audit/audit.module';
import { IntegrationsModule } from '../../integrations/integrations.module';
import { CommerceModule } from '../commerce/commerce.module';
import { EventsModule } from '../events/events.module';
import { OrganizerReportsModule } from '../organizer-reports/organizer-reports.module';
import { DomainEventsModule } from '../domain-events/domain-events.module';
import { AutomationEngineService } from './automation-engine.service';
import { AutomationSchedulerService } from './automation-scheduler.service';
import { AutomationController } from './automation-controller';

@Module({
  imports: [
    DatabaseModule,
    AuditModule,
    IntegrationsModule,
    CommerceModule,
    EventsModule,
    OrganizerReportsModule,
    DomainEventsModule,
  ],
  controllers: [AutomationController],
  providers: [AutomationEngineService, AutomationSchedulerService],
  exports: [AutomationEngineService],
})
export class AutomationModule {}
