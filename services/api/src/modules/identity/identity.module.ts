import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { IdentityController } from './identity.controller';
import { IdentityService } from './identity.service';
import { AttendeeProfileService } from './attendee-profile.service';
import { OrganizerProfileService } from './organizer-profile.service';
import { VendorProfileService } from './vendor-profile.service';

@Module({
  imports: [DatabaseModule],
  controllers: [IdentityController],
  providers: [
    IdentityService,
    AttendeeProfileService,
    OrganizerProfileService,
    VendorProfileService,
  ],
  exports: [
    IdentityService,
    AttendeeProfileService,
    OrganizerProfileService,
    VendorProfileService,
  ],
})
export class IdentityModule {}
