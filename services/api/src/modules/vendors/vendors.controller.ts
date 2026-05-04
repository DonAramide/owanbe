import { Body, Controller, Get, HttpCode, Post, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { hasAnyAdminRole } from '../../common/roles/role-helpers';
import { VENDOR_CREATE_ROLES } from '../../common/permission-matrix';
import { CreateVendorDto } from './dto/create-vendor.dto';
import { VendorsService } from './vendors.service';

@Controller('vendors')
export class VendorsController {
  constructor(private readonly vendors: VendorsService) {}

  /**
   * Public catalog: without JWT, only tenant-scoped active vendors (never trust query flags for elevation).
   * With valid JWT, RBAC + account checks run via global guards; `includeNonActive` only for admin tiers.
   */
  @Public()
  @Throttle({ public: { limit: 500, ttl: 60_000 } })
  @Get()
  async list(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser | undefined,
    @Query('q') q?: string,
    @Query('city') city?: string,
    @Query('includeNonActive') includeNonActive?: string,
  ) {
    const includeNonActiveCatalog =
      !!user && hasAnyAdminRole(user.roles) && includeNonActive === 'true';
    return this.vendors.listCatalog(tenantId, {
      includeNonActive: includeNonActiveCatalog,
      q,
      city,
    });
  }

  @Roles(...VENDOR_CREATE_ROLES)
  @Throttle({ onboarding: { limit: 25, ttl: 60_000 } })
  @HttpCode(201)
  @Post()
  async create(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Body() body: CreateVendorDto,
  ) {
    return this.vendors.createVendor(tenantId, user.userId, body);
  }
}
