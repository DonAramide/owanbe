import {
  Body,
  Controller,
  Headers,
  HttpCode,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { VENDOR_ONBOARDING_WRITE } from '../../common/permission-matrix';
import { VendorAccessService } from '../../ownership/vendor-access.service';
import { CreateApplicationDto } from './dto/create-application.dto';
import { UpsertBusinessDto } from './dto/upsert-business.dto';
import { OnboardingService } from './onboarding.service';

@Controller()
export class OnboardingController {
  constructor(
    private readonly onboarding: OnboardingService,
    private readonly vendorAccess: VendorAccessService,
  ) {}

  @Roles(...VENDOR_ONBOARDING_WRITE)
  @Throttle({ onboarding: { limit: 20, ttl: 60_000 } })
  @HttpCode(201)
  @Post('vendors/:vendorId/onboarding/applications')
  async createApplication(
    @TenantId() tenantId: string,
    @Param('vendorId') vendorId: string,
    @CurrentUser() user: JwtUser,
    @Headers('idempotency-key') idempotencyHeader: string | undefined,
    @Body() body: CreateApplicationDto,
  ) {
    await this.vendorAccess.assertVendorOwnerOrStaff(tenantId, vendorId, user.userId);
    return this.onboarding.createApplication(
      tenantId,
      vendorId,
      user.userId,
      idempotencyHeader?.trim() || undefined,
      body.idempotencyKey,
    );
  }

  @Roles(...VENDOR_ONBOARDING_WRITE)
  @Throttle({ onboarding: { limit: 40, ttl: 60_000 } })
  @Put('vendors/:vendorId/onboarding/applications/:applicationId/business')
  async upsertBusiness(
    @TenantId() tenantId: string,
    @Param('vendorId') vendorId: string,
    @Param('applicationId') applicationId: string,
    @CurrentUser() user: JwtUser,
    @Body() dto: UpsertBusinessDto,
  ) {
    await this.vendorAccess.assertVendorOwnerOrStaff(tenantId, vendorId, user.userId);
    return this.onboarding.upsertBusiness(tenantId, vendorId, applicationId, user.userId, dto);
  }

  @Roles(...VENDOR_ONBOARDING_WRITE)
  @Throttle({ onboarding: { limit: 15, ttl: 60_000 } })
  @Post('vendors/:vendorId/onboarding/applications/:applicationId/submit')
  async submit(
    @TenantId() tenantId: string,
    @Param('vendorId') vendorId: string,
    @Param('applicationId') applicationId: string,
    @CurrentUser() user: JwtUser,
  ) {
    await this.vendorAccess.assertVendorOwnerOrStaff(tenantId, vendorId, user.userId);
    return this.onboarding.submit(tenantId, vendorId, applicationId, user.userId);
  }
}
