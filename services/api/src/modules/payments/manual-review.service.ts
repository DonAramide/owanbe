import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { FinancialAdjustmentsService } from './financial-adjustments.service';
import { AuditLogService } from '../../audit/audit-log.service';
import { FinanceStateService } from './finance-state.service';

@Injectable()
export class ManualReviewService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly adjustments: FinancialAdjustmentsService,
    private readonly audit: AuditLogService,
    private readonly financeState: FinanceStateService,
  ) {}

  async approvePayment(tenantId: string, paymentId: string, actorUserId: string, note?: string) {
    await this.pool.query(
      `UPDATE payments
       SET under_review = FALSE,
           metadata = metadata || $3::jsonb,
           updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [paymentId, tenantId, JSON.stringify({ manual_review: { action: 'approve', note: note ?? null } })],
    );
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: 'MANUAL_REVIEW_APPROVE',
      resourceType: 'payment',
      resourceId: paymentId,
      metadata: { note: note ?? null },
    });
    return { ok: true };
  }

  async rejectPayment(tenantId: string, paymentId: string, actorUserId: string, note?: string) {
    const out = await this.adjustments.refundPayment({
      tenantId,
      paymentId,
      actorUserId,
      reason: note ?? 'manual_review_reject',
      idempotencyKey: `manual-review-reject:${paymentId}`,
    });
    await this.pool.query(`UPDATE payments SET under_review = FALSE, updated_at = now() WHERE id = $1`, [paymentId]);
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: 'MANUAL_REVIEW_REJECT',
      resourceType: 'payment',
      resourceId: paymentId,
      metadata: { note: note ?? null },
    });
    return out;
  }

  async escalatePayment(tenantId: string, paymentId: string, actorUserId: string, note?: string) {
    await this.pool.query(`UPDATE payments SET under_review = TRUE, updated_at = now() WHERE id = $1`, [paymentId]);
    await this.financeState.setState({
      state: 'frozen',
      actorUserId,
      tenantIdForAudit: tenantId,
      reason: note ?? 'manual_review_escalation',
      metadata: { paymentId },
    });
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: 'MANUAL_REVIEW_ESCALATE',
      resourceType: 'payment',
      resourceId: paymentId,
      metadata: { note: note ?? null },
    });
    return { ok: true, state: 'frozen' as const };
  }
}
