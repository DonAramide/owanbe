import { Controller, Get, Param, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { BOOKING_READ_ROLES } from '../../common/permission-matrix';
import { BookingAccessService } from '../../ownership/booking-access.service';
import { mapBookingToApi } from './booking.mapper';

@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookings: BookingAccessService) {}

  @Roles(...BOOKING_READ_ROLES)
  @Throttle({ default: { limit: 100, ttl: 60_000 } })
  @Get()
  async list(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('status') status?: string,
  ) {
    const rows = await this.bookings.listBookingsForPrincipal(tenantId, user, status);
    return {
      items: rows.map(mapBookingToApi),
      nextCursor: null as string | null,
    };
  }

  @Roles(...BOOKING_READ_ROLES)
  @Throttle({ default: { limit: 100, ttl: 60_000 } })
  @Get(':bookingId')
  async getOne(
    @TenantId() tenantId: string,
    @Param('bookingId') bookingId: string,
    @CurrentUser() user: JwtUser,
  ) {
    const row = await this.bookings.getBooking(tenantId, bookingId, user);
    return mapBookingToApi(row);
  }
}
