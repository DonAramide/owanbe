import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

@Injectable()
export class ComplianceService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getRetentionPolicies(tenantId: string) {
    const { rows } = await this.pool.query<{
      audit_retention_days: number;
      finance_retention_days: number;
      updated_at: Date;
    }>(
      `SELECT audit_retention_days, finance_retention_days, updated_at
       FROM compliance_retention_policies WHERE tenant_id = $1`,
      [tenantId],
    );
    return rows[0] ?? null;
  }

  async exportAuditBundle(tenantId: string, actorUserId: string) {
    const [audit, security, deletions, retention, piiUsers] = await Promise.all([
      this.pool.query(
        `SELECT id, tenant_id, actor_user_id, action, resource_type, resource_id, metadata, created_at
         FROM audit_log WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT 5000`,
        [tenantId],
      ),
      this.pool.query(
        `SELECT id, tenant_id, event_type, severity, actor_user_id, details, created_at
         FROM platform_security_events WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT 1000`,
        [tenantId],
      ),
      this.pool.query(
        `SELECT id, subject_user_id, status, reason, created_at, completed_at
         FROM data_deletion_requests WHERE tenant_id = $1 ORDER BY created_at DESC`,
        [tenantId],
      ),
      this.getRetentionPolicies(tenantId),
      this.pool.query(
        `SELECT id, email, pii_classification, status FROM users WHERE tenant_id = $1`,
        [tenantId],
      ),
    ]);

    return {
      generatedAt: new Date().toISOString(),
      tenantId,
      exportedBy: actorUserId,
      retentionPolicy: retention,
      piiClassification: {
        standard: piiUsers.rows.filter((u) => u.pii_classification === 'standard').length,
        sensitive: piiUsers.rows.filter((u) => u.pii_classification === 'sensitive').length,
        restricted: piiUsers.rows.filter((u) => u.pii_classification === 'restricted').length,
        users: piiUsers.rows.map((u) => ({
          id: u.id,
          email: u.email,
          classification: u.pii_classification,
          status: u.status,
        })),
      },
      auditLog: audit.rows,
      securityEvents: security.rows,
      dataDeletionRequests: deletions.rows,
    };
  }

  async requestDataDeletion(params: {
    tenantId: string;
    subjectUserId: string;
    requestedBy: string;
    reason: string;
  }) {
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO data_deletion_requests (tenant_id, subject_user_id, requested_by, reason)
       VALUES ($1, $2, $3, $4)
       RETURNING id::text`,
      [params.tenantId, params.subjectUserId, params.requestedBy, params.reason],
    );
    return { id: rows[0].id, status: 'pending' };
  }
}
