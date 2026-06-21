import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

@Injectable()
export class SuperAdminSecurityService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getSecurityCenter() {
    const [events, auditSecurity] = await Promise.all([
      this.pool.query<{
        id: string;
        tenant_id: string | null;
        event_type: string;
        severity: string;
        details: Record<string, unknown>;
        created_at: Date;
        tenant_name: string | null;
      }>(
        `SELECT se.id::text, se.tenant_id::text, se.event_type, se.severity, se.details, se.created_at,
                t.name AS tenant_name
         FROM platform_security_events se
         LEFT JOIN tenants t ON t.id = se.tenant_id
         ORDER BY se.created_at DESC
         LIMIT 100`,
      ),
      this.pool.query<{ action: string; count: string }>(
        `SELECT action, COUNT(*)::text AS count
         FROM audit_log
         WHERE action LIKE '%suspend%' OR action LIKE '%permission%' OR action LIKE '%finance%'
         GROUP BY action
         ORDER BY count DESC
         LIMIT 20`,
      ),
    ]);
    const byType = {
      failedLogins: events.rows.filter((e) => e.event_type === 'failed_login').length,
      permissionEscalations: events.rows.filter((e) => e.event_type === 'permission_escalation').length,
      suspiciousActivity: events.rows.filter((e) => e.event_type === 'suspicious_activity').length,
      financeExceptions: events.rows.filter((e) => e.event_type === 'finance_exception').length,
      rateLimitViolations: events.rows.filter((e) => e.event_type === 'rate_limit_violation').length,
      sessionAbuse: events.rows.filter((e) => e.event_type === 'session_abuse').length,
    };
    return {
      summary: byType,
      events: events.rows.map((e) => ({
        id: e.id,
        tenantId: e.tenant_id,
        tenantName: e.tenant_name,
        eventType: e.event_type,
        severity: e.severity,
        details: e.details,
        timestamp: e.created_at.toISOString(),
      })),
      auditHighlights: auditSecurity.rows.map((r) => ({
        action: r.action,
        count: Number(r.count),
      })),
    };
  }
}
