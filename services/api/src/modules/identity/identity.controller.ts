import { Body, Controller, Get, Post, Put, Req, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { IdentityService } from './identity.service';
import { LookupTicketInvitationsDto } from './dto/lookup-ticket-invitations.dto';
import { UpsertOrganizerProfileDto } from './dto/upsert-organizer-profile.dto';

@Controller()
export class IdentityController {
  constructor(private readonly identity: IdentityService) {}

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

  @Get('me/organizer-profile')
  async getOrganizerProfile(@CurrentUser() user: JwtUser) {
    return this.identity.getOrganizerProfile(user.tenantId, user.userId);
  }

  @Put('me/organizer-profile')
  async upsertOrganizerProfile(
    @CurrentUser() user: JwtUser,
    @Body() dto: UpsertOrganizerProfileDto,
  ) {
    return this.identity.upsertOrganizerProfile(user.tenantId, user.userId, dto);
  }

  @Get('me/vendor-id')
  async resolveVendorId(@CurrentUser() user: JwtUser) {
    const vendorId = await this.identity.resolveVendorId(user.tenantId, user.userId);
    return { vendorId };
  }
}
