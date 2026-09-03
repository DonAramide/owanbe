import { Body, Controller, Get, Param, Post, Put, Patch, Req } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { IdentityService } from './identity.service';
import { AttendeeProfileService } from './attendee-profile.service';
import { OrganizerProfileService } from './organizer-profile.service';
import { VendorProfileService } from './vendor-profile.service';
import { LookupTicketInvitationsDto } from './dto/lookup-ticket-invitations.dto';
import { UpsertOrganizerProfileDto } from './dto/upsert-organizer-profile.dto';
import { UpsertAttendeeProfileDto } from './dto/upsert-attendee-profile.dto';
import { UpsertVendorProfileDto } from './dto/upsert-vendor-profile.dto';

@Controller()
export class IdentityController {
  constructor(
    private readonly identity: IdentityService,
    private readonly attendeeProfile: AttendeeProfileService,
    private readonly organizerProfile: OrganizerProfileService,
    private readonly vendorProfile: VendorProfileService,
  ) {}

  @Public()
  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  @Post('public/ticket-invitations/lookup')
  async lookupInvitations(
    @Body() dto: LookupTicketInvitationsDto,
    @Req() req: Request & { catalogTenantId?: string; tenantId?: string },
  ) {
    const tenantId = req.tenantId ?? req.catalogTenantId!;
    const items = await this.identity.lookupTicketInvitations(
      tenantId,
      dto.email,
      dto.phone,
    );
    return { items };
  }

  @Post('me/ticket-entitlements/link')
  async linkEntitlements(
    @CurrentUser() user: JwtUser,
    @Body() dto: LookupTicketInvitationsDto,
  ) {
    const result = await this.identity.linkTicketEntitlements(
      user.tenantId,
      user.userId,
      dto.email,
      dto.phone,
    );
    return result;
  }

  /** Organizer workspace profile — dedicated `organizer_profiles` store. */
  @Get('me/organizer-profile')
  async getOrganizerProfile(@CurrentUser() user: JwtUser) {
    return this.organizerProfile.getProfile(user.tenantId, user.userId);
  }

  @Put('me/organizer-profile')
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  async upsertOrganizerProfile(
    @CurrentUser() user: JwtUser,
    @Body() dto: UpsertOrganizerProfileDto,
  ) {
    if (this.organizerProfile.hasOnboardingFields(dto)) {
      await this.identity.upsertOrganizerProfile(user.tenantId, user.userId, {
        displayName: dto.displayName,
        organizationName: dto.organizationName,
        phoneE164: dto.phoneE164,
        onboardingStep: dto.onboardingStep,
        markEmailVerified: dto.markEmailVerified,
        markPhoneVerified: dto.markPhoneVerified,
      });
    }
    if (this.organizerProfile.hasWorkspaceFields(dto)) {
      return this.organizerProfile.upsertProfile(user.tenantId, user.userId, dto);
    }
    return this.organizerProfile.getProfile(user.tenantId, user.userId);
  }

  @Patch('me/organizer-profile')
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  async patchOrganizerProfile(
    @CurrentUser() user: JwtUser,
    @Body() dto: UpsertOrganizerProfileDto,
  ) {
    if (this.organizerProfile.hasOnboardingFields(dto) && !this.organizerProfile.hasWorkspaceFields(dto)) {
      await this.identity.upsertOrganizerProfile(user.tenantId, user.userId, {
        displayName: dto.displayName,
        organizationName: dto.organizationName,
        phoneE164: dto.phoneE164,
        onboardingStep: dto.onboardingStep,
        markEmailVerified: dto.markEmailVerified,
        markPhoneVerified: dto.markPhoneVerified,
      });
      return this.organizerProfile.getProfile(user.tenantId, user.userId);
    }
    return this.organizerProfile.upsertProfile(user.tenantId, user.userId, dto);
  }

  /** Attendee workspace profile — dedicated `attendee_profiles` store only. */
  @Get('me/attendee-profile')
  async getAttendeeProfile(@CurrentUser() user: JwtUser) {
    return this.attendeeProfile.getProfile(user.tenantId, user.userId);
  }

  @Put('me/attendee-profile')
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  async upsertAttendeeProfile(
    @CurrentUser() user: JwtUser,
    @Body() dto: UpsertAttendeeProfileDto,
  ) {
    return this.attendeeProfile.upsertProfile(user.tenantId, user.userId, dto);
  }

  @Patch('me/attendee-profile')
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  async patchAttendeeProfile(
    @CurrentUser() user: JwtUser,
    @Body() dto: UpsertAttendeeProfileDto,
  ) {
    return this.attendeeProfile.upsertProfile(user.tenantId, user.userId, dto);
  }

  /** Vendor workspace profile — dedicated `vendor_profiles` store only. */
  @Get('me/vendor-profile')
  async getVendorProfile(@CurrentUser() user: JwtUser) {
    return this.vendorProfile.getProfile(user.tenantId, user.userId);
  }

  @Put('me/vendor-profile')
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  async upsertVendorProfile(
    @CurrentUser() user: JwtUser,
    @Body() dto: UpsertVendorProfileDto,
  ) {
    return this.vendorProfile.upsertProfile(user.tenantId, user.userId, dto);
  }

  @Patch('me/vendor-profile')
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  async patchVendorProfile(
    @CurrentUser() user: JwtUser,
    @Body() dto: UpsertVendorProfileDto,
  ) {
    return this.vendorProfile.upsertProfile(user.tenantId, user.userId, dto);
  }

  @Patch('me/vendor-services/:serviceId')
  @Throttle({ strict: { limit: 40, ttl: 60_000 } })
  async patchOwnVendorService(
    @CurrentUser() user: JwtUser,
    @Param('serviceId') serviceId: string,
    @Body()
    body: {
      status?: string;
      capabilities?: Array<{ key: string; label: string; provided?: boolean }>;
      customExtras?: Array<Record<string, unknown>>;
    },
  ) {
    return this.vendorProfile.patchOwnService(user.tenantId, user.userId, serviceId, body);
  }

  @Get('me/vendor-id')
  async resolveVendorId(@CurrentUser() user: JwtUser) {
    const vendorId = await this.identity.resolveVendorId(user.tenantId, user.userId);
    return { vendorId };
  }
}
