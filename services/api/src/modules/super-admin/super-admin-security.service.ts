import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

@Injectable()
export class SuperAdminSecurityService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getSecurityCenter() {
    // Phase 29 — richer ops center; keep endpoint stable for Flutter.
    const [events, auditSecurity, mfaEvents] = await Promise.all([
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
         LIMIT 150`,
      ),
      this.pool.query<{ action: string; count: string }>(
        `SELECT action, COUNT(*)::text AS count
         FROM audit_log
         WHERE action LIKE '%suspend%' OR action LIKE '%permission%' OR action LIKE '%finance%'
            OR action LIKE 'identity.%'
         GROUP BY action
         ORDER BY count DESC
         LIMIT 30`,
      ),
      this.pool.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM platform_security_events
         WHERE event_type IN ('mfa_enrolled', 'mfa_verified', 'mfa_disabled', 'mfa_recovery')
           AND created_at >= now() - interval '30 days'`,
      ),
    ]);
    const byType = {
      failedLogins: events.rows.filter((e) => e.event_type === 'failed_login').length,
      permissionEscalations: events.rows.filter((e) => e.event_type === 'permission_escalation').length,
      suspiciousActivity: events.rows.filter((e) => e.event_type === 'suspicious_activity').length,
      financeExceptions: events.rows.filter((e) => e.event_type === 'finance_exception').length,
      rateLimitViolations: events.rows.filter((e) => e.event_type === 'rate_limit_violation').length,
      sessionAbuse: events.rows.filter((e) => e.event_type === 'session_abuse').length,
      mfaActivity: parseInt(mfaEvents.rows[0]?.n ?? '0', 10),
      accountLifecycle: events.rows.filter((e) => e.event_type === 'account_lifecycle').length,
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
