import { Controller, Headers, HttpCode, Param, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { CLIENT_PAYMENT_CREATE_ROLES } from '../../common/permission-matrix';
import { PaymentsService } from './payments.service';

@Controller('bookings/:bookingId')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  /**
   * Client-only (RBAC): initiate Quaser payment for own booking; amount from booking snapshot.
   */
  @Roles(...CLIENT_PAYMENT_CREATE_ROLES)
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  @HttpCode(201)
  @Post('payments')
  async createPayment(
    @TenantId() tenantId: string,
    @Param('bookingId') bookingId: string,
    @CurrentUser() user: JwtUser,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ) {
    return this.payments.createPaymentForBooking(tenantId, bookingId, user.userId, idempotencyKey);
  }
}
