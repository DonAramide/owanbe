import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { CommerceModule } from '../commerce/commerce.module';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';
import { EventsAccessService } from './events-access.service';
import { EventTiersService } from './event-tiers.service';
import { OrganizerPortalService } from './organizer-portal.service';
import { VendorParticipationService } from './vendor-participation.service';
import { EventOperationsService } from './event-operations.service';
import { EventWebsiteService } from './event-website.service';
import { CelebrationWallService } from './celebration-wall.service';
import { AsoEbiService } from './aso-ebi.service';
import { SeatingService } from './seating.service';
import { ProgramService } from './program.service';
import { EventGuestsService } from './event-guests.service';
import { EventInvitationsService } from './event-invitations.service';

@Module({
  imports: [DatabaseModule, CommerceModule],
  controllers: [EventsController],
  providers: [
    EventsService,
    EventsAccessService,
    EventTiersService,
    OrganizerPortalService,
    VendorParticipationService,
    EventOperationsService,
    EventWebsiteService,
    CelebrationWallService,
    AsoEbiService,
    SeatingService,
    ProgramService,
    EventGuestsService,
    EventInvitationsService,
  ],
  exports: [EventsService, EventsAccessService],
})
export class EventsModule {}
