import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { Roles } from '../../common/decorators/roles.decorator';
import { SkipTenant } from '../../common/decorators/skip-tenant.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { SUPER_ADMIN_ROLES } from '../../common/permission-matrix';
import { SuperAdminOverviewService } from './super-admin-overview.service';
import { SuperAdminTenantsService } from './super-admin-tenants.service';
import { SuperAdminFinanceService } from './super-admin-finance.service';
import { SuperAdminSystemHealthService } from './super-admin-system-health.service';
import { SuperAdminFeatureFlagsService } from './super-admin-feature-flags.service';
import { SuperAdminAuditService } from './super-admin-audit.service';
import { SuperAdminAnalyticsService } from './super-admin-analytics.service';
import { SuperAdminSecurityService } from './super-admin-security.service';

@Controller('super-admin')
@SkipTenant()
export class SuperAdminController {
  constructor(
    private readonly overview: SuperAdminOverviewService,
    private readonly tenants: SuperAdminTenantsService,
    private readonly finance: SuperAdminFinanceService,
    private readonly systemHealthSvc: SuperAdminSystemHealthService,
    private readonly featureFlags: SuperAdminFeatureFlagsService,
    private readonly audit: SuperAdminAuditService,
    private readonly analytics: SuperAdminAnalyticsService,
    private readonly security: SuperAdminSecurityService,
  ) {}

  @Roles(...SUPER_ADMIN_ROLES)
  @Get('platform/overview')
  platformOverview() {
    return this.overview.getOverview();
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Get('tenants')
  listTenants(@Query('q') q?: string, @Query('status') status?: string) {
    return this.tenants.list(q, status);
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Post('tenants')
  createTenant(
    @CurrentUser() user: JwtUser,
    @Body() body: { slug: string; name: string },
  ) {
    return this.tenants.create(user.userId, body);
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Get('tenants/:tenantId')
  tenantDetail(@Param('tenantId') tenantId: string) {
    return this.tenants.getDetail(tenantId);
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Post('tenants/:tenantId/suspend')
  suspendTenant(@CurrentUser() user: JwtUser, @Param('tenantId') tenantId: string) {
    return this.tenants.setStatus(user.userId, tenantId, 'suspended');
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Post('tenants/:tenantId/reactivate')
  reactivateTenant(@CurrentUser() user: JwtUser, @Param('tenantId') tenantId: string) {
    return this.tenants.setStatus(user.userId, tenantId, 'active');
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Get('finance/platform')
  platformFinance(@Query('drill') drill?: string, @Query('drillId') drillId?: string) {
    return this.finance.getPlatformFinance(drill, drillId);
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Get('system/health')
  systemHealth() {
    return this.systemHealthSvc.getHealth();
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Get('feature-flags/:tenantId')
  listFeatureFlags(@Param('tenantId') tenantId: string) {
    return this.featureFlags.listForTenant(tenantId);
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Post('feature-flags/:tenantId')
  setFeatureFlag(
    @CurrentUser() user: JwtUser,
    @Param('tenantId') tenantId: string,
    @Body() body: { flagKey: string; enabled: boolean },
  ) {
    return this.featureFlags.setFlag(user.userId, tenantId, body.flagKey, body.enabled);
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Get('audit/timeline')
  auditTimeline(@Query('category') category?: string, @Query('limit') limit?: string) {
    return this.audit.timeline(category, parseInt(limit ?? '100', 10) || 100);
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Get('analytics/platform')
  platformAnalytics(@Query('range') range?: string) {
    return this.analytics.getAnalytics(range ?? '30d');
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Get('security/center')
  securityCenter() {
    return this.security.getSecurityCenter();
  }
}
