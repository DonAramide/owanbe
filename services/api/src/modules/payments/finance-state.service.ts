import { Injectable, Inject, ForbiddenException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';

export type FinanceSystemState = 'normal' | 'restricted' | 'frozen';

@Injectable()
export class FinanceStateService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
  ) {}

  async getState(): Promise<FinanceSystemState> {
    const { rows } = await this.pool.query<{ state: FinanceSystemState }>(
      `SELECT state::text AS state FROM finance_system_state_control WHERE id = TRUE`,
    );
    return rows[0]?.state ?? 'normal';
  }

  async ensurePaymentsAllowed(opts?: { adminOverride?: boolean }): Promise<void> {
    const state = await this.getState();
    if (state === 'frozen' && !opts?.adminOverride) {
      throw new ForbiddenException({
        code: 'FINANCE_FROZEN',
        message: 'Financial system is frozen; new payments are blocked',
      });
    }
  }

  async ensurePayoutsAllowed(opts?: { adminOverride?: boolean }): Promise<void> {
    const state = await this.getState();
    if (state === 'frozen' && !opts?.adminOverride) {
      throw new ForbiddenException({
        code: 'FINANCE_FROZEN',
        message: 'Financial system is frozen; payouts are blocked',
      });
    }
  }

  async setState(params: {
    state: FinanceSystemState;
    actorUserId: string;
    tenantIdForAudit: string;
    reason?: string;
    metadata?: Record<string, unknown>;
  }): Promise<{ state: FinanceSystemState }> {
    await this.pool.query(
      `UPDATE finance_system_state_control
       SET state = $1::finance_system_state,
           changed_by_user_id = $2::uuid,
           reason = $3,
           metadata = COALESCE(metadata, '{}'::jsonb) || $4::jsonb,
           updated_at = now()
       WHERE id = TRUE`,
      [
        params.state,
        params.actorUserId,
        params.reason ?? null,
        JSON.stringify(params.metadata ?? {}),
      ],
    );
    await this.audit.logAction({
      tenantId: params.tenantIdForAudit,
      actorUserId: params.actorUserId,
      action: 'FINANCE_SYSTEM_STATE_CHANGE',
      resourceType: 'finance_system_state_control',
      resourceId: 'global',
      metadata: { state: params.state, reason: params.reason ?? null, ...params.metadata },
    });
    return { state: params.state };
  }
}
