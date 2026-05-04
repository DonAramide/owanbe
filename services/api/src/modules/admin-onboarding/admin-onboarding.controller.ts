import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { ADMIN_APPROVERS, ADMIN_TIERS } from '../../common/permission-matrix';
import { ApproveApplicationDto } from './dto/approve-application.dto';
import { RejectApplicationDto } from './dto/reject-application.dto';
import { AdminOnboardingService } from './admin-onboarding.service';

@Controller('admin/onboarding')
export class AdminOnboardingController {
  constructor(private readonly admin: AdminOnboardingService) {}

  @Roles(...ADMIN_TIERS)
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('queue')
  async queue(
    @TenantId() tenantId: string,
    @Query('status') status?: 'applied' | 'under_review',
  ) {
    return this.admin.queue(tenantId, status);
  }

  @Roles(...ADMIN_TIERS)
  @Throttle({ default: { limit: 90, ttl: 60_000 } })
  @Get('applications/:applicationId')
  async getApplication(
    @TenantId() tenantId: string,
    @Param('applicationId') applicationId: string,
    @CurrentUser() user: JwtUser,
  ) {
    return this.admin.getApplicationDetail(tenantId, applicationId, user.userId);
  }

  @Roles(...ADMIN_APPROVERS)
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  @Post('applications/:applicationId/approve')
  async approve(
    @TenantId() tenantId: string,
    @Param('applicationId') applicationId: string,
    @CurrentUser() user: JwtUser,
    @Body() body: ApproveApplicationDto,
  ) {
    return this.admin.approve(tenantId, applicationId, user.userId, body.reviewNotes);
  }

  @Roles(...ADMIN_APPROVERS)
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  @Post('applications/:applicationId/reject')
  async reject(
    @TenantId() tenantId: string,
    @Param('applicationId') applicationId: string,
    @CurrentUser() user: JwtUser,
    @Body() body: RejectApplicationDto,
  ) {
    return this.admin.reject(
      tenantId,
      applicationId,
      user.userId,
      body.rejectionReason,
      body.reviewNotes,
    );
  }
}
