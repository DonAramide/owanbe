import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { ADMIN_TIERS } from '../../common/permission-matrix';
import type { JwtUser } from '../../common/types/jwt-user';
import { RequirePermissions } from '../../permissions/permissions.decorator';
import { ComplianceService, type DeletionAction, type ExportKind } from './compliance.service';

/**
 * Phase 27 — Enterprise Compliance & Data Governance (admin / tenant.manage).
 * Reuses Phase 8 tables + AuditLogService. Does not own business data.
 */
@Controller('compliance')
@Roles(...ADMIN_TIERS)
@RequirePermissions('tenant.manage')
export class ComplianceController {
  constructor(private readonly compliance: ComplianceService) {}

  @Get('dashboard')
  dashboard(@CurrentUser() user: JwtUser) {
    return this.compliance.dashboard(user.tenantId);
  }

  @Get('retention')
  retention(@CurrentUser() user: JwtUser) {
    return this.compliance.getRetentionPolicies(user.tenantId);
  }

  @Patch('retention')
  updateRetention(
    @CurrentUser() user: JwtUser,
    @Body()
    body: {
      auditRetentionDays?: number;
      financeRetentionDays?: number;
      marketingRetentionDays?: number;
      notificationRetentionDays?: number;
      guestRetentionDays?: number;
    },
  ) {
    return this.compliance.updateRetentionPolicies(user.tenantId, user.userId, body);
  }

  @Get('exports')
  listExports(@CurrentUser() user: JwtUser) {
    return this.compliance.listExports(user.tenantId);
  }

  @Get('exports/:id/download')
  downloadExport(@CurrentUser() user: JwtUser, @Param('id') id: string) {
    return this.compliance.downloadExport(user.tenantId, id, user.userId);
  }

  @Post('exports')
  createExport(
    @CurrentUser() user: JwtUser,
    @Body()
    body: {
      exportKind?: ExportKind;
      subjectUserId?: string;
    },
  ) {
    return this.compliance.createExportRequest({
      tenantId: user.tenantId,
      actorUserId: user.userId,
      exportKind: body.exportKind,
      subjectUserId: body.subjectUserId,
    });
  }

  /** Legacy Phase 8 path — synchronous audit bundle (kept for compatibility). */
  @Get('export')
  export(@CurrentUser() user: JwtUser) {
    return this.compliance.exportAuditBundle(user.tenantId, user.userId);
  }

  @Get('deletion-requests')
  listDeletions(@CurrentUser() user: JwtUser) {
    return this.compliance.listDeletionRequests(user.tenantId);
  }

  @Post('deletion-requests')
  createDeletion(
    @CurrentUser() user: JwtUser,
    @Body() body: { subjectUserId: string; reason?: string },
  ) {
    return this.compliance.requestDataDeletion({
      tenantId: user.tenantId,
      subjectUserId: body.subjectUserId,
      requestedBy: user.userId,
      reason: body.reason ?? '',
    });
  }

  @Post('deletion-requests/:id/transition')
  transitionDeletion(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Body() body: { action: DeletionAction; reason?: string },
  ) {
    return this.compliance.transitionDeletion({
      tenantId: user.tenantId,
      requestId: id,
      actorUserId: user.userId,
      action: body.action,
      rejectionReason: body.reason,
    });
  }

  @Get('activity')
  activity(@CurrentUser() user: JwtUser, @Query('limit') limit?: string) {
    const n = Math.min(Math.max(Number(limit ?? 40) || 40, 1), 100);
    return this.compliance.complianceActivity(user.tenantId, n);
  }

  @Get('reports/governance.csv')
  async governanceCsv(@CurrentUser() user: JwtUser, @Res() res: Response) {
    const report = await this.compliance.complianceReportCsv(user.tenantId);
    res.setHeader('Content-Type', report.contentType);
    res.setHeader('Content-Disposition', `attachment; filename="${report.filename}"`);
    res.send(report.body);
  }
}
