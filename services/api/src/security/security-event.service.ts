import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../database/database.tokens';

export type SecurityEventType =
  | 'failed_login'
  | 'permission_escalation'
  | 'suspicious_activity'
  | 'finance_exception'
  | 'rate_limit_violation'
  | 'session_abuse'
  | 'mfa_enrolled'
  | 'mfa_verified'
  | 'mfa_disabled'
  | 'mfa_recovery'
  | 'account_lifecycle';

export type SecuritySeverity = 'info' | 'warning' | 'critical';

@Injectable()
export class SecurityEventService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async record(params: {
    eventType: SecurityEventType;
    severity?: SecuritySeverity;
    tenantId?: string;
    actorUserId?: string;
    details?: Record<string, unknown>;
  }): Promise<void> {
    const values = [
      params.tenantId ?? null,
      params.eventType,
      params.severity ?? 'warning',
      params.actorUserId ?? null,
      JSON.stringify(params.details ?? {}),
    ];
    try {
      await this.pool.query(
        `INSERT INTO platform_security_events (tenant_id, event_type, severity, actor_user_id, details)
         VALUES ($1::uuid, $2, $3, $4::uuid, $5::jsonb)`,
        values,
      );
    } catch (err: unknown) {
      const code = (err as { code?: string })?.code;
      if (code !== '23503' || !params.actorUserId) throw err;
      // User not provisioned in Postgres yet — log without actor FK.
      await this.pool.query(
        `INSERT INTO platform_security_events (tenant_id, event_type, severity, actor_user_id, details)
         VALUES ($1::uuid, $2, $3, NULL, $4::jsonb)`,
        [
          params.tenantId ?? null,
          params.eventType,
          params.severity ?? 'warning',
          JSON.stringify({ ...params.details, actorUserId: params.actorUserId }),
        ],
      );
    }
  }
}
