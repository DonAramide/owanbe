import {
  BadRequestException,
  Injectable,
  Inject,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';
import { SecurityEventService } from '../../security/security-event.service';
import { RolesService } from '../../roles/roles.service';
import { SupabaseAdminService } from '../../integrations/supabase/supabase-admin.service';

/**
 * Phase 29 — Identity & Security productization.
 * Orchestrates Supabase Auth MFA + users.status lifecycle.
 * Does not replace JWT auth or RBAC.
 */
@Injectable()
export class IdentitySecurityService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
    private readonly securityEvents: SecurityEventService,
    private readonly roles: RolesService,
    private readonly supabaseAdmin: SupabaseAdminService,
  ) {}

  async securityOpsCenter() {
    const [events, mfaAudit, lifecycle, suspended] = await Promise.all([
      this.pool.query(
        `SELECT se.id::text, se.tenant_id::text, se.event_type, se.severity, se.details,
                se.actor_user_id::text, se.created_at, t.name AS tenant_name
         FROM platform_security_events se
         LEFT JOIN tenants t ON t.id = se.tenant_id
         ORDER BY se.created_at DESC
         LIMIT 150`,
      ),
      this.pool.query<{ action: string; n: string }>(
        `SELECT action, COUNT(*)::text AS n FROM audit_log
         WHERE action LIKE 'identity.mfa%' OR action LIKE 'identity.session%'
            OR action LIKE 'identity.user_%'
         GROUP BY action ORDER BY n DESC LIMIT 30`,
      ),
      this.pool.query<{ status: string; n: string }>(
        `SELECT status::text AS status, COUNT(*)::text AS n FROM users GROUP BY status`,
      ),
      this.pool.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM users WHERE status::text = 'suspended'`,
      ),
    ]);

    const rows = events.rows;
    const summary = {
      failedLogins: rows.filter((e) => e.event_type === 'failed_login').length,
      permissionEscalations: rows.filter((e) => e.event_type === 'permission_escalation').length,
      suspiciousActivity: rows.filter((e) => e.event_type === 'suspicious_activity').length,
      financeExceptions: rows.filter((e) => e.event_type === 'finance_exception').length,
      rateLimitViolations: rows.filter((e) => e.event_type === 'rate_limit_violation').length,
      sessionAbuse: rows.filter((e) => e.event_type === 'session_abuse').length,
      mfaEnrolled: rows.filter((e) => e.event_type === 'mfa_enrolled').length,
      mfaVerified: rows.filter((e) => e.event_type === 'mfa_verified').length,
      mfaDisabled: rows.filter((e) => e.event_type === 'mfa_disabled').length,
      mfaRecovery: rows.filter((e) => e.event_type === 'mfa_recovery').length,
      accountLifecycle: rows.filter((e) => e.event_type === 'account_lifecycle').length,
    };

    const loginActivity = rows.filter((e) =>
      ['failed_login', 'session_abuse', 'mfa_verified'].includes(e.event_type as string),
    );

    return {
      generatedAt: new Date().toISOString(),
      supabaseAdminConfigured: this.supabaseAdmin.isConfigured(),
      summary,
      usersByStatus: Object.fromEntries(
        lifecycle.rows.map((r) => [r.status, parseInt(r.n, 10)]),
      ),
      suspendedUsers: parseInt(suspended.rows[0]?.n ?? '0', 10),
      events: rows.map((e) => ({
        id: e.id,
        tenantId: e.tenant_id,
        tenantName: e.tenant_name,
        eventType: e.event_type,
        severity: e.severity,
        actorUserId: e.actor_user_id,
        details: e.details,
        timestamp: e.created_at,
      })),
      loginActivity: loginActivity.slice(0, 40).map((e) => ({
        id: e.id,
        eventType: e.event_type,
        severity: e.severity,
        actorUserId: e.actor_user_id,
        tenantId: e.tenant_id,
        timestamp: e.created_at,
        details: e.details,
      })),
      auditHighlights: mfaAudit.rows.map((r) => ({
        action: r.action,
        count: parseInt(r.n, 10),
      })),
    };
  }

  async securityReportCsv() {
    const center = await this.securityOpsCenter();
    const lines = [
      'section,id,detail,count_or_status,timestamp',
      ...Object.entries(center.summary).map(
        ([k, v]) => `summary,${k},${k},${v},${center.generatedAt}`,
      ),
      ...center.events.slice(0, 100).map(
        (e) =>
          `event,${e.id},${e.eventType},${e.severity},${e.timestamp ?? ''}`,
      ),
      ...center.auditHighlights.map(
        (a) => `audit,${a.action},${a.action},${a.count},${center.generatedAt}`,
      ),
    ];
    return {
      filename: `identity-security-${new Date().toISOString().slice(0, 10)}.csv`,
      contentType: 'text/csv; charset=utf-8',
      body: lines.join('\n'),
    };
  }

  // ── Users ───────────────────────────────────────────────────────────

  async listUsers(params: { tenantId?: string; status?: string; q?: string }) {
    const args: unknown[] = [];
    let where = 'WHERE 1=1';
    if (params.tenantId) {
      args.push(params.tenantId);
      where += ` AND u.tenant_id = $${args.length}::uuid`;
    }
    if (params.status && params.status !== 'all') {
      args.push(params.status);
      where += ` AND u.status::text = $${args.length}`;
    }
    if (params.q?.trim()) {
      args.push(`%${params.q.trim().toLowerCase()}%`);
      where += ` AND (lower(u.email) LIKE $${args.length} OR lower(COALESCE(u.display_name, '')) LIKE $${args.length})`;
    }
    const { rows } = await this.pool.query(
      `SELECT u.id, u.tenant_id, u.email, u.display_name, u.status::text, u.suspended_reason,
              u.suspended_at, u.created_at, u.updated_at, u.last_login_at,
              t.name AS tenant_name, t.slug AS tenant_slug
       FROM users u
       INNER JOIN tenants t ON t.id = u.tenant_id
       ${where}
       ORDER BY u.updated_at DESC NULLS LAST
       LIMIT 200`,
      args,
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        tenantId: r.tenant_id,
        tenantName: r.tenant_name,
        tenantSlug: r.tenant_slug,
        email: r.email,
        displayName: r.display_name,
        status: r.status,
        suspendedReason: r.suspended_reason,
        suspendedAt: r.suspended_at,
        lastLoginAt: r.last_login_at,
        createdAt: r.created_at,
        updatedAt: r.updated_at,
      })),
    };
  }

  async setUserStatus(params: {
    actorUserId: string;
    actorTenantId: string;
    targetUserId: string;
    status: 'active' | 'suspended';
    reason?: string;
  }) {
    if (params.targetUserId === params.actorUserId) {
      throw new BadRequestException('Cannot change your own account status via this endpoint');
    }
    const { rows } = await this.pool.query(
      `SELECT id, tenant_id, email, status::text FROM users WHERE id = $1::uuid`,
      [params.targetUserId],
    );
    if (!rows[0]) throw new NotFoundException('User not found');
    const target = rows[0];

    await this.pool.query(
      `UPDATE users SET
         status = $2::user_status,
         suspended_reason = CASE WHEN $2::text = 'suspended' THEN $3 ELSE NULL END,
         suspended_at = CASE WHEN $2::text = 'suspended' THEN now() ELSE NULL END,
         suspended_by = CASE WHEN $2::text = 'suspended' THEN $4::uuid ELSE NULL END,
         updated_at = now()
       WHERE id = $1::uuid`,
      [
        params.targetUserId,
        params.status,
        params.reason ?? 'Admin suspension',
        params.actorUserId,
      ],
    );

    this.roles.invalidate(target.tenant_id as string, params.targetUserId);

    const action =
      params.status === 'suspended' ? 'identity.user_suspended' : 'identity.user_reactivated';
    await this.audit.logAction({
      tenantId: target.tenant_id as string,
      actorUserId: params.actorUserId,
      action,
      resourceType: 'user',
      resourceId: params.targetUserId,
      metadata: {
        previousStatus: target.status,
        email: target.email,
        reason: params.reason ?? null,
      },
    });
    await this.securityEvents.record({
      eventType: 'account_lifecycle',
      severity: params.status === 'suspended' ? 'warning' : 'info',
      tenantId: target.tenant_id as string,
      actorUserId: params.actorUserId,
      details: { targetUserId: params.targetUserId, status: params.status, action },
    });

    if (params.status === 'suspended') {
      await this.supabaseAdmin.signOutUser(params.targetUserId).catch(() => undefined);
    }

    return { ok: true, status: params.status, userId: params.targetUserId };
  }

  // ── MFA ─────────────────────────────────────────────────────────────

  async getMfaStatus(userId: string) {
    const factors = await this.supabaseAdmin.listMfaFactors(userId);
    const verified = factors.factors.filter((f) => f.status === 'verified');
    return {
      available: factors.available,
      reason: factors.reason,
      enrolled: verified.length > 0,
      factorCount: factors.factors.length,
      verifiedFactorCount: verified.length,
      factors: factors.factors,
      enrollmentNote:
        'Enrollment and TOTP verification use Supabase Auth client MFA (same IdP as login). Nest orchestrates status, recovery, and audit only.',
    };
  }

  async recordMfaEvent(params: {
    actorUserId: string;
    tenantId: string;
    kind: 'enrolled' | 'verified' | 'disabled' | 'recovery';
    metadata?: Record<string, unknown>;
  }) {
    const map = {
      enrolled: { action: 'identity.mfa_enrolled', event: 'mfa_enrolled' as const },
      verified: { action: 'identity.mfa_verified', event: 'mfa_verified' as const },
      disabled: { action: 'identity.mfa_disabled', event: 'mfa_disabled' as const },
      recovery: { action: 'identity.mfa_recovery', event: 'mfa_recovery' as const },
    }[params.kind];

    await this.audit.logAction({
      tenantId: params.tenantId,
      actorUserId: params.actorUserId,
      action: map.action,
      resourceType: 'user',
      resourceId: params.actorUserId,
      metadata: params.metadata ?? {},
    });
    await this.securityEvents.record({
      eventType: map.event,
      severity: params.kind === 'recovery' || params.kind === 'disabled' ? 'warning' : 'info',
      tenantId: params.tenantId,
      actorUserId: params.actorUserId,
      details: params.metadata ?? {},
    });
    return { ok: true, kind: params.kind };
  }

  /** Admin MFA recovery — remove factors via Supabase Auth Admin. */
  async resetMfa(params: {
    actorUserId: string;
    actorTenantId: string;
    targetUserId: string;
    reason?: string;
  }) {
    const factors = await this.supabaseAdmin.listMfaFactors(params.targetUserId);
    if (!factors.available) {
      return {
        available: false,
        reason: factors.reason ?? 'MFA recovery Unavailable',
        removed: 0,
      };
    }
    let removed = 0;
    for (const f of factors.factors) {
      if (!f.id) continue;
      const del = await this.supabaseAdmin.deleteMfaFactor(params.targetUserId, f.id);
      if (del.available && del.ok) removed += 1;
    }

    const { rows } = await this.pool.query(
      `SELECT tenant_id FROM users WHERE id = $1::uuid`,
      [params.targetUserId],
    );
    const tenantId = (rows[0]?.tenant_id as string) ?? params.actorTenantId;

    await this.audit.logAction({
      tenantId,
      actorUserId: params.actorUserId,
      action: 'identity.mfa_recovery',
      resourceType: 'user',
      resourceId: params.targetUserId,
      metadata: { removed, reason: params.reason ?? null },
    });
    await this.securityEvents.record({
      eventType: 'mfa_recovery',
      severity: 'warning',
      tenantId,
      actorUserId: params.actorUserId,
      details: { targetUserId: params.targetUserId, removed },
    });

    return { available: true, removed, ok: true };
  }

  // ── Sessions ────────────────────────────────────────────────────────

  async getSessions(userId: string) {
    const auth = await this.supabaseAdmin.getAuthUser(userId);
    if (!auth.available || !auth.user) {
      return {
        available: false,
        reason: auth.reason ?? 'Session inventory Unavailable',
        items: [],
        note: 'Supabase Auth Admin required. No invented session rows.',
      };
    }
    // Auth user payload may include last_sign_in; full session list varies by project.
    const lastSignIn = auth.user.last_sign_in_at ?? auth.user.lastSignInAt ?? null;
    return {
      available: true,
      items: [
        {
          id: 'auth-primary',
          userId,
          lastSignInAt: lastSignIn,
          email: auth.user.email ?? null,
          source: 'supabase_auth_admin',
        },
      ],
      note: 'Detailed multi-device session inventory depends on Auth Admin capabilities; revoke uses global sign-out.',
    };
  }

  async revokeSessions(params: {
    actorUserId: string;
    actorTenantId: string;
    targetUserId: string;
  }) {
    const result = await this.supabaseAdmin.signOutUser(params.targetUserId);
    const { rows } = await this.pool.query(
      `SELECT tenant_id FROM users WHERE id = $1::uuid`,
      [params.targetUserId],
    );
    const tenantId = (rows[0]?.tenant_id as string) ?? params.actorTenantId;

    if (result.available) {
      await this.audit.logAction({
        tenantId,
        actorUserId: params.actorUserId,
        action: 'identity.session_revoked',
        resourceType: 'user',
        resourceId: params.targetUserId,
        metadata: {},
      });
      await this.securityEvents.record({
        eventType: 'session_abuse',
        severity: 'warning',
        tenantId,
        actorUserId: params.actorUserId,
        details: { targetUserId: params.targetUserId, action: 'admin_force_logout' },
      });
    }
    return result;
  }

  async assertSameTenantOrSuperAdmin(
    actorRoles: string[],
    actorTenantId: string,
    targetUserId: string,
  ) {
    if (actorRoles.includes('super_admin')) return;
    const { rows } = await this.pool.query(
      `SELECT tenant_id FROM users WHERE id = $1::uuid`,
      [targetUserId],
    );
    if (!rows[0]) throw new NotFoundException('User not found');
    if (rows[0].tenant_id !== actorTenantId) {
      throw new ForbiddenException('Cross-tenant user action requires super_admin');
    }
  }
}
