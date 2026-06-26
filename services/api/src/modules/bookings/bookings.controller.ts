import { Body, Controller, Get, Param, Patch, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { BOOKING_READ_ROLES, VENDOR_ONBOARDING_WRITE } from '../../common/permission-matrix';
import { BookingsService } from './bookings.service';

@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookings: BookingsService) {}

  @Roles(...BOOKING_READ_ROLES)
  @Throttle({ default: { limit: 100, ttl: 60_000 } })
  @Get()
  async list(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('status') status?: string,
  ) {
    return this.bookings.listForUser(tenantId, user, status);
  }

  @Roles(...BOOKING_READ_ROLES)
  @Throttle({ default: { limit: 100, ttl: 60_000 } })
  @Get(':bookingId')
  async getOne(
    @TenantId() tenantId: string,
    @Param('bookingId') bookingId: string,
    @CurrentUser() user: JwtUser,
  ) {
    return this.bookings.getForUser(tenantId, bookingId, user);
  }

  @Roles(...VENDOR_ONBOARDING_WRITE)
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Patch(':bookingId/status')
  async updateStatus(
    @TenantId() tenantId: string,
    @Param('bookingId') bookingId: string,
    @CurrentUser() user: JwtUser,
    @Body() body: { action?: string },
  ) {
    const action = String(body.action ?? '').trim() as 'accept' | 'fulfill' | 'cancel';
    return this.bookings.updateVendorStatus(tenantId, user.userId, bookingId, action);
  }
}
