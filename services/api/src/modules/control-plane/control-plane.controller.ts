import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { Roles } from '../../common/decorators/roles.decorator';
import { SkipTenant } from '../../common/decorators/skip-tenant.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { SUPER_ADMIN_ROLES, ADMIN_TIERS } from '../../common/permission-matrix';
import { RequirePermissions } from '../../permissions/permissions.decorator';
import { ControlPlaneService } from './control-plane.service';

/**
 * Phase 28 — Enterprise Administration & Control Plane.
 * Super-admin primary; admin tiers may read tenant-scoped vendor standing via existing admin routes.
 */
@Controller('control-plane')
@SkipTenant()
export class ControlPlaneController {
  constructor(private readonly control: ControlPlaneService) {}

  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('dashboard')
  dashboard() {
    return this.control.dashboard();
  }

  // ── Tenants ─────────────────────────────────────────────────────────

  @Roles(...SUPER_ADMIN_ROLES)
  @Get('tenants')
  listTenants(@Query('q') q?: string, @Query('status') status?: string) {
    return this.control.listTenants(q, status);
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Get('tenants/:tenantId')
  getTenant(@Param('tenantId') tenantId: string) {
    return this.control.getTenant(tenantId);
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Patch('tenants/:tenantId/configuration')
  updateTenantConfig(
    @CurrentUser() user: JwtUser,
    @Param('tenantId') tenantId: string,
    @Body() body: { metadata?: Record<string, unknown> },
  ) {
    return this.control.updateTenantMetadata(user.userId, tenantId, body.metadata ?? {});
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @RequirePermissions('tenant.suspend')
  @Post('tenants/:tenantId/suspend')
  suspendTenant(@CurrentUser() user: JwtUser, @Param('tenantId') tenantId: string) {
    return this.control.setTenantStatus(user.userId, tenantId, 'suspended');
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Post('tenants/:tenantId/reactivate')
  reactivateTenant(@CurrentUser() user: JwtUser, @Param('tenantId') tenantId: string) {
    return this.control.setTenantStatus(user.userId, tenantId, 'active');
  }

  // ── Vendor governance ───────────────────────────────────────────────

  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('vendors')
  listVendors(
    @Query('q') q?: string,
    @Query('status') status?: string,
    @Query('tenantId') tenantId?: string,
  ) {
    return this.control.listVendors(q, status, tenantId);
  }

  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('vendors/:tenantId/:vendorId')
  getVendor(@Param('tenantId') tenantId: string, @Param('vendorId') vendorId: string) {
    return this.control.getVendorGovernance(tenantId, vendorId);
  }

  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Post('vendors/:tenantId/:vendorId/transition')
  transitionVendor(
    @CurrentUser() user: JwtUser,
    @Param('tenantId') tenantId: string,
    @Param('vendorId') vendorId: string,
    @Body() body: { action: 'approve' | 'suspend' | 'reactivate' | 'reject'; reason?: string },
  ) {
    return this.control.transitionVendor(
      user.userId,
      tenantId,
      vendorId,
      body.action,
      body.reason,
    );
  }

  // ── MDM (dictionary master data) ────────────────────────────────────

  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('mdm/domains')
  mdmDomains() {
    return this.control.listMdmDomains();
  }

  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('mdm/domains/:domainKey/entities')
  mdmEntities(
    @Param('domainKey') domainKey: string,
    @Query('parentId') parentId?: string,
    @Query('q') q?: string,
  ) {
    return this.control.listMdmEntities(domainKey, parentId, q);
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Post('mdm/domains/:domainKey/entities')
  createMdmEntity(
    @CurrentUser() user: JwtUser,
    @Param('domainKey') domainKey: string,
    @Body()
    body: {
      slug: string;
      label: string;
      description?: string;
      parentId?: string | null;
      status?: string;
      sortOrder?: number;
      properties?: Record<string, unknown>;
    },
  ) {
    return this.control.createMdmEntity(user.userId, user.tenantId, domainKey, body);
  }

  @Roles(...SUPER_ADMIN_ROLES)
  @Patch('mdm/entities/:entityId')
  updateMdmEntity(
    @CurrentUser() user: JwtUser,
    @Param('entityId') entityId: string,
    @Body()
    body: {
      label?: string;
      description?: string;
      status?: string;
      sortOrder?: number;
      properties?: Record<string, unknown>;
    },
  ) {
    return this.control.updateMdmEntity(user.userId, user.tenantId, entityId, body);
  }

  // ── Devices (honest Unavailable) ────────────────────────────────────

  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('devices')
  devices() {
    return this.control.devicesUnavailable();
  }

  // ── Audit ───────────────────────────────────────────────────────────

  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('activity')
  activity(@Query('limit') limit?: string) {
    return this.control.listMdmActivity(parseInt(limit ?? '40', 10) || 40);
  }
}
