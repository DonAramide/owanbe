import { Controller, Get, Param } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { UsersService } from './users.service';

@Controller()
export class PublicProfileController {
  constructor(private readonly users: UsersService) {}

  /** Self profile card (always visible to owner). */
  @Get('me/attendee-profile-card')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  async myAttendeeCard(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
  ) {
    return this.users.getPublicAttendeeProfile(tenantId, user.userId, user.userId);
  }

  /** Peer-visible attendee profile card (privacy-filtered). */
  @Get('users/:userId/attendee-profile-card')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  async attendeeCard(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('userId') userId: string,
  ) {
    return this.users.getPublicAttendeeProfile(tenantId, user.userId, userId);
  }
}
