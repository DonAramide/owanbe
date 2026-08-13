import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { Roles } from '../../common/decorators/roles.decorator';
import { SkipTenant } from '../../common/decorators/skip-tenant.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { SUPER_ADMIN_ROLES, ADMIN_TIERS } from '../../common/permission-matrix';
import { RequirePermissions } from '../../permissions/permissions.decorator';
import { IdentitySecurityService } from './identity-security.service';

/**
 * Phase 29 — Identity & Security productization APIs.
 */
@Controller()
export class IdentitySecurityController {
  constructor(private readonly identity: IdentitySecurityService) {}

  // ── Self MFA (any authenticated user) ───────────────────────────────

  @Get('me/security/mfa')
  myMfa(@CurrentUser() user: JwtUser) {
    return this.identity.getMfaStatus(user.userId);
  }

  @Post('me/security/mfa/events')
  myMfaEvent(
    @CurrentUser() user: JwtUser,
    @Body() body: { kind: 'enrolled' | 'verified' | 'disabled' | 'recovery'; metadata?: Record<string, unknown> },
  ) {
    return this.identity.recordMfaEvent({
      actorUserId: user.userId,
      tenantId: user.tenantId,
      kind: body.kind,
      metadata: body.metadata,
    });
  }

  @Get('me/security/sessions')
  mySessions(@CurrentUser() user: JwtUser) {
    return this.identity.getSessions(user.userId);
  }

  // ── Admin / Super-admin ops ─────────────────────────────────────────

  @SkipTenant()
  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('identity-security/center')
  securityCenter() {
    return this.identity.securityOpsCenter();
  }

  @SkipTenant()
  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('identity-security/report.csv')
  async reportCsv(@Res() res: Response) {
    const report = await this.identity.securityReportCsv();
    res.setHeader('Content-Type', report.contentType);
    res.setHeader('Content-Disposition', `attachment; filename="${report.filename}"`);
    res.send(report.body);
  }

  @SkipTenant()
  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('identity-security/users')
  listUsers(
    @Query('tenantId') tenantId?: string,
    @Query('status') status?: string,
    @Query('q') q?: string,
  ) {
    return this.identity.listUsers({ tenantId, status, q });
  }

  @SkipTenant()
  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @RequirePermissions('tenant.manage')
  @Post('identity-security/users/:userId/suspend')
  async suspend(
    @CurrentUser() user: JwtUser,
    @Param('userId') userId: string,
    @Body() body: { reason?: string },
  ) {
    await this.identity.assertSameTenantOrSuperAdmin(user.roles, user.tenantId, userId);
    return this.identity.setUserStatus({
      actorUserId: user.userId,
      actorTenantId: user.tenantId,
      targetUserId: userId,
      status: 'suspended',
      reason: body.reason,
    });
  }

  @SkipTenant()
  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @RequirePermissions('tenant.manage')
  @Post('identity-security/users/:userId/reactivate')
  async reactivate(@CurrentUser() user: JwtUser, @Param('userId') userId: string) {
    await this.identity.assertSameTenantOrSuperAdmin(user.roles, user.tenantId, userId);
    return this.identity.setUserStatus({
      actorUserId: user.userId,
      actorTenantId: user.tenantId,
      targetUserId: userId,
      status: 'active',
    });
  }

  @SkipTenant()
  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('identity-security/users/:userId/mfa')
  userMfa(@Param('userId') userId: string) {
    return this.identity.getMfaStatus(userId);
  }

  @SkipTenant()
  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @RequirePermissions('tenant.manage')
  @Post('identity-security/users/:userId/mfa/reset')
  async resetMfa(
    @CurrentUser() user: JwtUser,
    @Param('userId') userId: string,
    @Body() body: { reason?: string },
  ) {
    await this.identity.assertSameTenantOrSuperAdmin(user.roles, user.tenantId, userId);
    return this.identity.resetMfa({
      actorUserId: user.userId,
      actorTenantId: user.tenantId,
      targetUserId: userId,
      reason: body.reason,
    });
  }

  @SkipTenant()
  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @Get('identity-security/users/:userId/sessions')
  userSessions(@Param('userId') userId: string) {
    return this.identity.getSessions(userId);
  }

  @SkipTenant()
  @Roles(...SUPER_ADMIN_ROLES, ...ADMIN_TIERS)
  @RequirePermissions('tenant.manage')
  @Post('identity-security/users/:userId/sessions/revoke')
  async revokeSessions(@CurrentUser() user: JwtUser, @Param('userId') userId: string) {
    await this.identity.assertSameTenantOrSuperAdmin(user.roles, user.tenantId, userId);
    return this.identity.revokeSessions({
      actorUserId: user.userId,
      actorTenantId: user.tenantId,
      targetUserId: userId,
    });
  }
}
