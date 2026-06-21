import { Body, Controller, Get, Post } from '@nestjs/common';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../permissions/permissions.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { ADMIN_TIERS } from '../../common/permission-matrix';
import { ComplianceService } from './compliance.service';

@Controller('compliance')
export class ComplianceController {
  constructor(private readonly compliance: ComplianceService) {}

  @Roles(...ADMIN_TIERS)
  @RequirePermissions('tenant.manage')
  @Get('export')
  exportAudit(@TenantId() tenantId: string, @CurrentUser() user: JwtUser) {
    return this.compliance.exportAuditBundle(tenantId, user.userId);
  }

  @Roles(...ADMIN_TIERS)
  @RequirePermissions('tenant.manage')
  @Get('retention')
  retention(@TenantId() tenantId: string) {
    return this.compliance.getRetentionPolicies(tenantId);
  }

  @Roles(...ADMIN_TIERS)
  @RequirePermissions('tenant.manage')
  @Post('deletion-requests')
  requestDeletion(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Body() body: { subjectUserId: string; reason?: string },
  ) {
    return this.compliance.requestDataDeletion({
      tenantId,
      subjectUserId: body.subjectUserId,
      requestedBy: user.userId,
      reason: body.reason ?? '',
    });
  }
}
