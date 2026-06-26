import {
  Controller,
  Get,
  Param,
  Post,
  Query,
  Body,
} from '@nestjs/common';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import {
  ADMIN_TIERS,
  ADMIN_FINANCE_CONTROL_ROLES,
  ADMIN_APPROVERS,
} from '../../common/permission-matrix';
import { RequirePermissions } from '../../permissions/permissions.decorator';
import { PlatformDashboardService } from './platform-dashboard.service';
import { AdminOrganizersService } from './admin-organizers.service';
import { AdminEventsService } from './admin-events.service';
import { AdminVendorsService } from './admin-vendors.service';
import { AdminOperationsCenterService } from './admin-operations-center.service';
import { AdminFinanceSupervisionService } from './admin-finance-supervision.service';
import { AdminAuditService } from './admin-audit.service';
import { LaunchOpsDashboardService } from './launch-ops-dashboard.service';

@Controller('admin')
export class PlatformAdminController {
  constructor(
    private readonly dashboard: PlatformDashboardService,
    private readonly organizers: AdminOrganizersService,
    private readonly events: AdminEventsService,
    private readonly vendors: AdminVendorsService,
    private readonly operations: AdminOperationsCenterService,
    private readonly finance: AdminFinanceSupervisionService,
    private readonly audit: AdminAuditService,
    private readonly launchOps: LaunchOpsDashboardService,
  ) {}

  @Roles(...ADMIN_TIERS)
  @Get('ops/launch-dashboard')
  async launchOpsDashboard(@TenantId() tenantId: string) {
    return this.launchOps.getDashboard(tenantId);
  }

  @Roles(...ADMIN_TIERS)
  @Get('platform/dashboard')
  async platformDashboard(@TenantId() tenantId: string) {
    return this.dashboard.getDashboard(tenantId);
  }

  @Roles(...ADMIN_TIERS)
  @Get('organizers')
  async listOrganizers(
    @TenantId() tenantId: string,
    @Query('q') q?: string,
    @Query('status') status?: string,
  ) {
    return this.organizers.list(tenantId, q, status);
  }

  @Roles(...ADMIN_TIERS)
  @Get('organizers/:organizerId')
  async organizerDetail(@TenantId() tenantId: string, @Param('organizerId') organizerId: string) {
    return this.organizers.getDetail(tenantId, organizerId);
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Post('organizers/:organizerId/suspend')
  async suspendOrganizer(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('organizerId') organizerId: string,
  ) {
    return this.organizers.setStatus(tenantId, user.userId, organizerId, 'suspended');
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Post('organizers/:organizerId/reactivate')
  async reactivateOrganizer(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('organizerId') organizerId: string,
  ) {
    return this.organizers.setStatus(tenantId, user.userId, organizerId, 'active');
  }

  @Roles(...ADMIN_TIERS)
  @Get('events')
  async listEvents(
    @TenantId() tenantId: string,
    @Query('q') q?: string,
    @Query('status') status?: string,
  ) {
    return this.events.list(tenantId, q, status);
  }

  @Roles(...ADMIN_TIERS)
  @Get('events/:eventId')
  async eventDetail(@TenantId() tenantId: string, @Param('eventId') eventId: string) {
    return this.events.getDetail(tenantId, eventId);
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Post('events/:eventId/force-close')
  async forceCloseEvent(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('eventId') eventId: string,
  ) {
    return this.events.forceClose(tenantId, user.userId, eventId);
  }

  @Roles(...ADMIN_TIERS)
  @Get('vendors')
  async listVendors(
    @TenantId() tenantId: string,
    @Query('q') q?: string,
    @Query('status') status?: string,
  ) {
    return this.vendors.list(tenantId, q, status);
  }

  @Roles(...ADMIN_TIERS)
  @Get('vendors/:vendorId')
  async vendorDetail(@TenantId() tenantId: string, @Param('vendorId') vendorId: string) {
    return this.vendors.getDetail(tenantId, vendorId);
  }

  @Roles(...ADMIN_APPROVERS)
  @RequirePermissions('vendor.approve')
  @Post('vendors/:vendorId/approve')
  async approveVendor(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('vendorId') vendorId: string,
  ) {
    return this.vendors.setStatus(tenantId, user.userId, vendorId, 'active');
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Post('vendors/:vendorId/suspend')
  async suspendVendor(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('vendorId') vendorId: string,
    @Body() body: { reason?: string },
  ) {
    return this.vendors.setStatus(tenantId, user.userId, vendorId, 'suspended', body?.reason);
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Post('vendors/:vendorId/reactivate')
  async reactivateVendor(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('vendorId') vendorId: string,
  ) {
    return this.vendors.setStatus(tenantId, user.userId, vendorId, 'active');
  }

  @Roles(...ADMIN_TIERS)
  @Get('operations/overview')
  async operationsOverview(@TenantId() tenantId: string) {
    return this.operations.getOverview(tenantId);
  }

  @Roles(...ADMIN_TIERS)
  @Get('operations/check-ins')
  async operationsCheckIns(@TenantId() tenantId: string, @Query('limit') limit?: string) {
    return {
      items: await this.operations.recentCheckIns(tenantId, Math.min(200, parseInt(limit ?? '50', 10) || 50)),
    };
  }

  @Roles(...ADMIN_TIERS)
  @Get('operations/incidents')
  async operationsIncidents(@TenantId() tenantId: string) {
    return { items: await this.operations.openIncidents(tenantId) };
  }

  @Roles(...ADMIN_TIERS)
  @Get('operations/live-events')
  async operationsLiveEvents(@TenantId() tenantId: string) {
    return { items: await this.operations.liveEvents(tenantId) };
  }

  @Roles(...ADMIN_TIERS)
  @Get('operations/feed')
  async operationsFeed(@TenantId() tenantId: string, @Query('limit') limit?: string) {
    return {
      items: await this.operations.recentFeed(tenantId, Math.min(200, parseInt(limit ?? '80', 10) || 80)),
    };
  }

  @Roles(...ADMIN_TIERS)
  @Get('finance/supervision')
  async financeSupervision(@TenantId() tenantId: string) {
    return this.finance.getSupervision(tenantId);
  }

  @Roles(...ADMIN_TIERS)
  @Get('audit/timeline')
  async auditTimeline(
    @TenantId() tenantId: string,
    @Query('category') category?: string,
    @Query('limit') limit?: string,
  ) {
    return this.audit.timeline(tenantId, category, parseInt(limit ?? '100', 10) || 100);
  }
}
