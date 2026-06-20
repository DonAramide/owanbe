import { Controller, Get, Param, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { ADMIN_FINANCE_ROLES } from '../../common/permission-matrix';
import {
  FinanceExportService,
  type FinanceExportFormat,
  type FinanceExportKind,
} from './finance-export.service';

const KINDS: FinanceExportKind[] = [
  'transactions',
  'payouts',
  'refunds',
  'settlements',
  'organizer-payouts',
];

@Controller('admin/finance/exports')
export class FinanceExportController {
  constructor(private readonly exports: FinanceExportService) {}

  @Roles(...ADMIN_FINANCE_ROLES)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Get(':kind')
  async download(
    @TenantId() tenantId: string,
    @Param('kind') kind: string,
    @Query('format') format?: string,
    @Query('limit') limit?: string,
    @Res() res?: Response,
  ) {
    const normalizedKind = kind as FinanceExportKind;
    if (!KINDS.includes(normalizedKind)) {
      return { ok: false, reason: 'invalid_kind' };
    }
    const fmt: FinanceExportFormat = format === 'xlsx' ? 'xlsx' : 'csv';
    const n = Math.min(2000, Math.max(1, parseInt(limit ?? '500', 10) || 500));
    const out = await this.exports.export(tenantId, normalizedKind, fmt, n);
    res!.setHeader('Content-Type', out.contentType);
    res!.setHeader('Content-Disposition', `attachment; filename="${out.filename}"`);
    return res!.send(out.body);
  }
}
