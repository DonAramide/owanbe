import { Module, forwardRef } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { IdentityController } from './identity.controller';
import { IdentityService } from './identity.service';
import { AttendeeProfileService } from './attendee-profile.service';
import { OrganizerProfileService } from './organizer-profile.service';
import { VendorProfileService } from './vendor-profile.service';
import { VendorsModule } from '../vendors/vendors.module';

@Module({
  imports: [DatabaseModule, forwardRef(() => VendorsModule)],
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
