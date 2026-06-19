import { BadRequestException, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { ADMIN_FINANCE_CONTROL_ROLES } from '../../common/permission-matrix';
import { PayoutService } from './payout.service';
import { ReconciliationService } from './reconciliation.service';
import { FinancialAdjustmentsService } from './financial-adjustments.service';
import { FinanceStateService, type FinanceSystemState } from './finance-state.service';
import { ManualReviewService } from './manual-review.service';
import { FinanceTimeoutService } from './finance-timeout.service';
import { AdminFinanceDashboardService } from './admin-finance-dashboard.service';
import { AuditLogService } from '../../audit/audit-log.service';

@Controller('admin/finance')
export class AdminFinanceController {
  constructor(
    private readonly payout: PayoutService,
    private readonly reconciliation: ReconciliationService,
    private readonly adjustments: FinancialAdjustmentsService,
    private readonly financeState: FinanceStateService,
    private readonly reviews: ManualReviewService,
    private readonly timeoutSweep: FinanceTimeoutService,
    private readonly dashboard: AdminFinanceDashboardService,
    private readonly audit: AuditLogService,
  ) {}

  private parseUtcDate(raw?: string): Date | undefined {
    if (!raw?.trim()) return undefined;
    const input = raw.trim();
    const hasTz = /(?:Z|[+\-]\d{2}:\d{2})$/i.test(input);
    const normalized = hasTz ? input : `${input}Z`;
    const parsed = new Date(normalized);
    if (Number.isNaN(parsed.getTime())) {
      throw new BadRequestException({ code: 'INVALID_DATE', message: `Invalid date: ${raw}` });
    }
    return parsed;
  }

  private parseDateRange(fromDate?: string, toDate?: string): { from?: Date; to?: Date } {
    const from = this.parseUtcDate(fromDate);
    const to = this.parseUtcDate(toDate);
    if (from && to && from >= to) {
      throw new BadRequestException({
        code: 'INVALID_DATE_RANGE',
        message: 'fromDate must be earlier than toDate',
      });
    }
    return { from, to };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Get('summary')
  async summary(@TenantId() tenantId: string) {
    return this.dashboard.summary(tenantId);
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Get('alerts')
  async alerts(@TenantId() tenantId: string, @Query('page') page?: string, @Query('limit') limit?: string) {
    const p = Math.max(1, parseInt(page ?? '1', 10) || 1);
    const n = Math.min(100, Math.max(1, parseInt(limit ?? '50', 10) || 50));
    return this.dashboard.alerts(tenantId, p, n);
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Get('transactions')
  async transactions(
    @TenantId() tenantId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('type') type?: string,
    @Query('status') status?: string,
    @Query('sortBy') sortBy?: string,
    @Query('sortDir') sortDir?: 'asc' | 'desc',
    @Query('fromDate') fromDate?: string,
    @Query('toDate') toDate?: string,
  ) {
    const range = this.parseDateRange(fromDate, toDate);
    return this.dashboard.transactions({
      tenantId,
      page: Math.max(1, parseInt(page ?? '1', 10) || 1),
      limit: Math.min(100, Math.max(1, parseInt(limit ?? '50', 10) || 50)),
      type,
      status,
      sortBy,
      sortDir,
      fromDate: range.from,
      toDate: range.to,
    });
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('payments')
  async listPayments(
    @TenantId() tenantId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const p = Math.max(1, parseInt(page ?? '1', 10) || 1);
    const n = Math.min(100, Math.max(1, parseInt(limit ?? '100', 10) || 100));
    return this.dashboard.payments(tenantId, p, n);
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('payouts')
  async listPayouts(
    @TenantId() tenantId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('fromDate') fromDate?: string,
    @Query('toDate') toDate?: string,
    @Query('status') status?: string,
  ) {
    const range = this.parseDateRange(fromDate, toDate);
    const p = Math.max(1, parseInt(page ?? '1', 10) || 1);
    const n = Math.min(100, Math.max(1, parseInt(limit ?? '100', 10) || 100));
    return this.dashboard.payouts(tenantId, p, n, range.from, range.to, status);
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  @Post('payouts/process-batch')
  async processPayoutBatch(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('limit') limit?: string,
    @Query('adminOverride') adminOverride?: string,
  ) {
    const n = Math.min(50, Math.max(1, parseInt(limit ?? '20', 10) || 20));
    const out = await this.payout.processPayoutBatch(tenantId, n, { adminOverride: adminOverride === 'true' });
    await this.audit.logAction({
      tenantId,
      actorUserId: user.userId,
      action: 'ADMIN_PAYOUT_PROCESS_BATCH',
      resourceType: 'payout_batch',
      resourceId: 'batch',
      metadata: { limit: n, processed: out.processed },
    });
    return { status: 'ok', updatedEntity: out };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  @Post('payouts/:payoutId/retry')
  async retryPayout(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('payoutId') payoutId: string,
    @Query('adminOverride') adminOverride?: string,
  ) {
    const out = await this.payout.retryFailedPayout(tenantId, payoutId, { adminOverride: adminOverride === 'true' });
    await this.audit.logAction({
      tenantId,
      actorUserId: user.userId,
      action: 'ADMIN_PAYOUT_RETRY',
      resourceType: 'payout',
      resourceId: payoutId,
      metadata: out,
    });
    return {
      status: out.ok ? 'ok' : 'noop',
      updatedEntity: await this.dashboard.payoutById(tenantId, payoutId),
    };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Throttle({ strict: { limit: 10, ttl: 60_000 } })
  @Post('reconciliation/run')
  async runReconciliation(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('periodStart') periodStart?: string,
    @Query('periodEnd') periodEnd?: string,
  ) {
    const end = periodEnd ? new Date(periodEnd) : new Date();
    const start = periodStart
      ? new Date(periodStart)
      : new Date(end.getTime() - 24 * 60 * 60 * 1000);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start >= end) {
      return { ok: false, reason: 'invalid_period' };
    }
    const out = await this.reconciliation.runLedgerPaymentConsistencyCheck(tenantId, user.userId, start, end);
    await this.audit.logAction({
      tenantId,
      actorUserId: user.userId,
      action: 'ADMIN_RECONCILIATION_RUN',
      resourceType: 'reconciliation_job',
      resourceId: out.jobId,
      metadata: { periodStart: start.toISOString(), periodEnd: end.toISOString(), reports: out.reportsInserted },
    });
    return { status: 'ok', updatedEntity: out };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  @Post('payments/:paymentId/refund')
  async refundPayment(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('paymentId') paymentId: string,
    @Query('amountMinor') amountMinor?: string,
    @Query('reason') reason?: string,
    @Query('idempotencyKey') idempotencyKey?: string,
  ) {
    const out = await this.adjustments.refundPayment({
      tenantId,
      paymentId,
      actorUserId: user.userId,
      amountMinor,
      reason,
      idempotencyKey,
    });
    await this.audit.logAction({
      tenantId,
      actorUserId: user.userId,
      action: 'ADMIN_REFUND',
      resourceType: 'payment',
      resourceId: paymentId,
      metadata: out,
    });
    return {
      status: out.ok ? 'ok' : 'noop',
      updatedEntity: await this.dashboard.paymentById(tenantId, paymentId),
    };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  @Post('payments/:paymentId/chargeback')
  async applyChargeback(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('paymentId') paymentId: string,
    @Query('amountMinor') amountMinor: string,
    @Query('eventId') eventId: string,
    @Query('suspendVendorPayouts') suspendVendorPayouts?: string,
  ) {
    const out = await this.adjustments.applyChargeback({
      tenantId,
      paymentId,
      actorUserId: user.userId,
      amountMinor,
      eventId,
      suspendVendorPayouts: suspendVendorPayouts === 'true',
    });
    await this.audit.logAction({
      tenantId,
      actorUserId: user.userId,
      action: 'ADMIN_CHARGEBACK',
      resourceType: 'payment',
      resourceId: paymentId,
      metadata: out,
    });
    return {
      status: out.ok ? 'ok' : 'noop',
      updatedEntity: await this.dashboard.paymentById(tenantId, paymentId),
    };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  @Post('reconciliation/recover-capture')
  async recoverCaptureLedger(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('paymentId') paymentId: string,
    @Query('escalateIfFailed') escalateIfFailed?: string,
  ) {
    const out = await this.reconciliation.recoverMissingCaptureLedger({
      tenantId,
      paymentId,
      actorUserId: user.userId,
      escalateIfFailed: escalateIfFailed === 'true',
    });
    await this.audit.logAction({
      tenantId,
      actorUserId: user.userId,
      action: 'ADMIN_RECONCILIATION_RECOVER',
      resourceType: 'payment',
      resourceId: paymentId,
      metadata: out,
    });
    return {
      status: out.ok ? 'ok' : 'noop',
      updatedEntity: await this.dashboard.paymentById(tenantId, paymentId),
    };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Get('reconciliation')
  async listReconciliation(
    @TenantId() tenantId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('fromDate') fromDate?: string,
    @Query('toDate') toDate?: string,
    @Query('status') status?: string,
  ) {
    const range = this.parseDateRange(fromDate, toDate);
    return this.dashboard.reconciliation(
      tenantId,
      Math.max(1, parseInt(page ?? '1', 10) || 1),
      Math.min(100, Math.max(1, parseInt(limit ?? '50', 10) || 50)),
      range.from,
      range.to,
      status,
    );
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Get('reviews')
  async listReviews(
    @TenantId() tenantId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('fromDate') fromDate?: string,
    @Query('toDate') toDate?: string,
  ) {
    const range = this.parseDateRange(fromDate, toDate);
    const p = Math.max(1, parseInt(page ?? '1', 10) || 1);
    const n = Math.min(100, Math.max(1, parseInt(limit ?? '100', 10) || 100));
    return this.dashboard.reviews(tenantId, p, n, range.from, range.to);
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Post('reconciliation/recover')
  async recover(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('paymentId') paymentId: string,
    @Query('escalateIfFailed') escalateIfFailed?: string,
  ) {
    const out = await this.reconciliation.recoverMissingCaptureLedger({
      tenantId,
      paymentId,
      actorUserId: user.userId,
      escalateIfFailed: escalateIfFailed === 'true',
    });
    await this.audit.logAction({
      tenantId,
      actorUserId: user.userId,
      action: 'ADMIN_RECONCILIATION_RECOVER',
      resourceType: 'payment',
      resourceId: paymentId,
      metadata: out,
    });
    return {
      status: out.ok ? 'ok' : 'noop',
      updatedEntity: await this.dashboard.paymentById(tenantId, paymentId),
    };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Get('state')
  async getFinanceState() {
    return { state: await this.financeState.getState() };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Post('state')
  async setFinanceState(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('state') state: FinanceSystemState,
    @Query('reason') reason?: string,
  ) {
    const out = await this.financeState.setState({
      state,
      actorUserId: user.userId,
      tenantIdForAudit: tenantId,
      reason,
    });
    return { status: 'ok', updatedEntity: out };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Post('reviews/:paymentId/approve')
  async approveReview(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('paymentId') paymentId: string,
    @Query('note') note?: string,
  ) {
    const out = await this.reviews.approvePayment(tenantId, paymentId, user.userId, note);
    return {
      status: out.ok ? 'ok' : 'noop',
      updatedEntity: await this.dashboard.paymentById(tenantId, paymentId),
    };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Post('reviews/:paymentId/reject')
  async rejectReview(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('paymentId') paymentId: string,
    @Query('note') note?: string,
  ) {
    const out = await this.reviews.rejectPayment(tenantId, paymentId, user.userId, note);
    return {
      status: out.ok ? 'ok' : 'noop',
      updatedEntity: await this.dashboard.paymentById(tenantId, paymentId),
    };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Post('reviews/:paymentId/escalate')
  async escalateReview(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('paymentId') paymentId: string,
    @Query('note') note?: string,
  ) {
    const out = await this.reviews.escalatePayment(tenantId, paymentId, user.userId, note);
    return {
      status: out.ok ? 'ok' : 'noop',
      updatedEntity: await this.dashboard.paymentById(tenantId, paymentId),
    };
  }

  @Roles(...ADMIN_FINANCE_CONTROL_ROLES)
  @Post('timeouts/run')
  async runTimeoutSweep() {
    const out = await this.timeoutSweep.runSweep();
    return { status: 'ok', updatedEntity: out };
  }
}
