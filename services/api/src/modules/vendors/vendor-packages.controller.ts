import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { VENDOR_ONBOARDING_WRITE } from '../../common/permission-matrix';
import { VendorPackagesService } from './vendor-packages.service';

@Controller('vendor/packages')
export class VendorPackagesController {
  constructor(private readonly packages: VendorPackagesService) {}

  @Roles(...VENDOR_ONBOARDING_WRITE)
  @Throttle({ default: { limit: 80, ttl: 60_000 } })
  @Get()
  async list(@TenantId() tenantId: string, @CurrentUser() user: JwtUser) {
    return this.packages.listForVendorUser(tenantId, user);
  }

  @Roles(...VENDOR_ONBOARDING_WRITE)
  @Throttle({ default: { limit: 40, ttl: 60_000 } })
  @Post()
  async create(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Body() body: Record<string, unknown>,
  ) {
    return this.packages.createForVendorUser(tenantId, user, {
      name: body.name as string | undefined,
      description: body.description as string | undefined,
      category: body.category as string | undefined,
      priceMinor: body.priceMinor != null ? Number(body.priceMinor) : undefined,
      currency: body.currency as string | undefined,
    });
  }

  @Roles(...VENDOR_ONBOARDING_WRITE)
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Patch(':packageId')
  async patch(
    @TenantId() tenantId: string,
    @Param('packageId') packageId: string,
    @CurrentUser() user: JwtUser,
    @Body() body: Record<string, unknown>,
  ) {
    return this.packages.patchForVendorUser(tenantId, user, packageId, {
      isActive: body.isActive as boolean | undefined,
      name: body.name as string | undefined,
      description: body.description as string | undefined,
    });
  }
}
