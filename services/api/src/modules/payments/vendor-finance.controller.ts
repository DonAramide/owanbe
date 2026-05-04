import { Controller, Get, Post, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { VENDOR_FINANCE_VIEW_ROLES } from '../../common/permission-matrix';
import { VendorFinanceService } from './vendor-finance.service';

@Controller('vendor/finance')
export class VendorFinanceController {
  constructor(private readonly vendorFinance: VendorFinanceService) {}

  @Roles(...VENDOR_FINANCE_VIEW_ROLES)
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('balance')
  async balance(@TenantId() tenantId: string, @CurrentUser() user: JwtUser) {
    return this.vendorFinance.getBalanceForPrincipal(tenantId, user.userId);
  }

  @Roles(...VENDOR_FINANCE_VIEW_ROLES)
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('summary')
  async summary(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('vendorId') vendorId?: string,
  ) {
    return this.vendorFinance.getDashboardSummary(tenantId, user.userId, vendorId);
  }

  @Roles(...VENDOR_FINANCE_VIEW_ROLES)
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('transactions')
  async transactions(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('limit') limit?: string,
    @Query('vendorId') vendorId?: string,
  ) {
    const n = Math.min(200, Math.max(1, parseInt(limit ?? '100', 10) || 100));
    return this.vendorFinance.getTransactions(tenantId, user.userId, n, vendorId);
  }

  @Roles(...VENDOR_FINANCE_VIEW_ROLES)
  @Throttle({ strict: { limit: 40, ttl: 60_000 } })
  @Post('payout')
  async requestPayout(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('vendorId') vendorId: string | undefined,
    @Query('amountMinor') amountMinor: string,
  ) {
    return this.vendorFinance.requestPayout({
      tenantId,
      userId: user.userId,
      vendorId,
      amountMinor,
    });
  }
}
