import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../database/database.tokens';

export type SecurityEventType =
  | 'failed_login'
  | 'permission_escalation'
  | 'suspicious_activity'
  | 'finance_exception'
  | 'rate_limit_violation'
  | 'session_abuse';

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
    await this.pool.query(
      `INSERT INTO platform_security_events (tenant_id, event_type, severity, actor_user_id, details)
       VALUES ($1::uuid, $2, $3, $4::uuid, $5::jsonb)`,
      [
        params.tenantId ?? null,
        params.eventType,
        params.severity ?? 'warning',
        params.actorUserId ?? null,
        JSON.stringify(params.details ?? {}),
      ],
    );
  }
}
