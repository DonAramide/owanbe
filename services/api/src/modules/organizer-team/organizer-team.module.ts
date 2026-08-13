import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { AuditModule } from '../../audit/audit.module';
import { CommerceModule } from '../commerce/commerce.module';
import { EventsModule } from '../events/events.module';
import { OrganizerTeamController } from './organizer-team.controller';
import { OrganizerTeamService } from './organizer-team.service';

@Module({
  imports: [DatabaseModule, AuditModule, CommerceModule, EventsModule],
  controllers: [OrganizerTeamController],
  providers: [OrganizerTeamService],
  exports: [OrganizerTeamService],
})
export class OrganizerTeamModule {}
