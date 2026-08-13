import {
  BadRequestException,
  Injectable,
  Inject,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';

export type DeletionAction = 'review' | 'approve' | 'reject' | 'process';
export type ExportKind = 'audit_bundle' | 'subject_package';

/**
 * Phase 27 — Compliance consumer layer.
 * Composes audit_log, security events, users, deletion/export tables.
 * Does not own Finance/Tickets/Marketing data — anonymizes identity only.
 */
@Injectable()
export class ComplianceService {
  private readonly logger = new Logger(ComplianceService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
  ) {}

  async dashboard(tenantId: string) {
    const [retention, deletions, exports, recentAudit] = await Promise.all([
      this.getRetentionPolicies(tenantId),
      this.pool.query<{ status: string; n: string }>(
        `SELECT status, COUNT(*)::text AS n FROM data_deletion_requests
         WHERE tenant_id = $1 GROUP BY status`,
        [tenantId],
      ),
      this.pool.query<{ status: string; n: string }>(
        `SELECT status, COUNT(*)::text AS n FROM compliance_export_requests
         WHERE tenant_id = $1 GROUP BY status`,
        [tenantId],
      ),
      this.pool.query(
        `SELECT id, actor_user_id, action, resource_type, resource_id, created_at
         FROM audit_log
         WHERE tenant_id = $1
           AND (action LIKE 'compliance.%' OR resource_type LIKE 'compliance%'
                OR resource_type IN ('data_deletion_request', 'compliance_export'))
         ORDER BY created_at DESC
         LIMIT 25`,
        [tenantId],
      ),
    ]);

    const delByStatus = Object.fromEntries(
      deletions.rows.map((r) => [r.status, parseInt(r.n, 10)]),
    );
    const expByStatus = Object.fromEntries(exports.rows.map((r) => [r.status, parseInt(r.n, 10)]));

    return {
      generatedAt: new Date().toISOString(),
      tenantId,
      retention,
      pendingDeletions:
        (delByStatus.pending ?? 0) +
        (delByStatus.reviewing ?? 0) +
        (delByStatus.approved ?? 0) +
        (delByStatus.processing ?? 0),
      deletionByStatus: delByStatus,
      exportByStatus: expByStatus,
      recentActivity: recentAudit.rows.map((r) => ({
        id: r.id,
        actorUserId: r.actor_user_id,
        action: r.action,
        resourceType: r.resource_type,
        resourceId: r.resource_id,
        createdAt: r.created_at,
      })),
      governanceStatus: {
        retentionConfigured: !!retention,
        openDeletionQueue:
          (delByStatus.pending ?? 0) +
          (delByStatus.reviewing ?? 0) +
          (delByStatus.approved ?? 0),
      },
    };
  }

  async getRetentionPolicies(tenantId: string) {
    await this.ensureRetentionRow(tenantId);
    const { rows } = await this.pool.query(
      `SELECT tenant_id, audit_retention_days, finance_retention_days,
              marketing_retention_days, notification_retention_days, guest_retention_days,
              updated_at
       FROM compliance_retention_policies WHERE tenant_id = $1`,
      [tenantId],
    );
    const r = rows[0];
    if (!r) return null;
    return {
      tenantId: r.tenant_id,
      categories: [
        { id: 'audit', label: 'Audit logs', retentionDays: r.audit_retention_days },
        { id: 'finance', label: 'Finance records', retentionDays: r.finance_retention_days },
        { id: 'marketing', label: 'Marketing deliveries', retentionDays: r.marketing_retention_days },
        {
          id: 'notifications',
          label: 'Notification deliveries',
          retentionDays: r.notification_retention_days,
        },
        { id: 'guests', label: 'Guest records', retentionDays: r.guest_retention_days },
      ],
      auditRetentionDays: r.audit_retention_days,
      financeRetentionDays: r.finance_retention_days,
      marketingRetentionDays: r.marketing_retention_days,
      notificationRetentionDays: r.notification_retention_days,
      guestRetentionDays: r.guest_retention_days,
      updatedAt: r.updated_at,
    };
  }

  async updateRetentionPolicies(
    tenantId: string,
    actorUserId: string,
    patch: {
      auditRetentionDays?: number;
      financeRetentionDays?: number;
      marketingRetentionDays?: number;
      notificationRetentionDays?: number;
      guestRetentionDays?: number;
    },
  ) {
    await this.ensureRetentionRow(tenantId);
    await this.pool.query(
      `UPDATE compliance_retention_policies SET
         audit_retention_days = COALESCE($2, audit_retention_days),
         finance_retention_days = COALESCE($3, finance_retention_days),
         marketing_retention_days = COALESCE($4, marketing_retention_days),
         notification_retention_days = COALESCE($5, notification_retention_days),
         guest_retention_days = COALESCE($6, guest_retention_days),
         updated_at = now()
       WHERE tenant_id = $1`,
      [
        tenantId,
        patch.auditRetentionDays ?? null,
        patch.financeRetentionDays ?? null,
        patch.marketingRetentionDays ?? null,
        patch.notificationRetentionDays ?? null,
        patch.guestRetentionDays ?? null,
      ],
    );
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: 'compliance.retention_updated',
      resourceType: 'compliance_retention_policy',
      resourceId: tenantId,
      metadata: patch,
    });
    return this.getRetentionPolicies(tenantId);
  }

  /** Synchronous export job recorded as request — reuses composition, not a second engine. */
  async createExportRequest(params: {
    tenantId: string;
    actorUserId: string;
    exportKind?: ExportKind;
    subjectUserId?: string;
  }) {
    const kind = params.exportKind ?? 'audit_bundle';
    if (kind === 'subject_package' && !params.subjectUserId) {
      throw new BadRequestException('subjectUserId required for subject_package');
    }

    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO compliance_export_requests
         (tenant_id, requested_by, export_kind, subject_user_id, status)
       VALUES ($1::uuid, $2::uuid, $3, $4::uuid, 'processing')
       RETURNING id::text`,
      [params.tenantId, params.actorUserId, kind, params.subjectUserId ?? null],
    );
    const exportId = rows[0].id;

    try {
      const bundle =
        kind === 'subject_package'
          ? await this.exportSubjectPackage(params.tenantId, params.subjectUserId!, params.actorUserId)
          : await this.exportAuditBundle(params.tenantId, params.actorUserId);

      const summary = {
        generatedAt: bundle.generatedAt,
        kind,
        auditLogCount: Array.isArray((bundle as { auditLog?: unknown[] }).auditLog)
          ? (bundle as { auditLog: unknown[] }).auditLog.length
          : 0,
        securityEventCount: Array.isArray((bundle as { securityEvents?: unknown[] }).securityEvents)
          ? (bundle as { securityEvents: unknown[] }).securityEvents.length
          : 0,
        subjectUserId: params.subjectUserId ?? null,
      };

      await this.pool.query(
        `UPDATE compliance_export_requests
         SET status = 'completed', result_summary = $2::jsonb, completed_at = now()
         WHERE id = $1::uuid`,
        [exportId, JSON.stringify(summary)],
      );

      await this.audit.logAction({
        tenantId: params.tenantId,
        actorUserId: params.actorUserId,
        action: 'compliance.export_completed',
        resourceType: 'compliance_export',
        resourceId: exportId,
        metadata: summary,
      });

      // Persist summary only — re-compose via downloadExport for full package (no second engine).
      return { id: exportId, status: 'completed' as const, summary };
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'export_failed';
      await this.pool.query(
        `UPDATE compliance_export_requests
         SET status = 'failed', error_message = $2, completed_at = now()
         WHERE id = $1::uuid`,
        [exportId, msg],
      );
      await this.audit.logAction({
        tenantId: params.tenantId,
        actorUserId: params.actorUserId,
        action: 'compliance.export_failed',
        resourceType: 'compliance_export',
        resourceId: exportId,
        metadata: { error: msg },
      });
      throw err;
    }
  }

  async downloadExport(tenantId: string, exportId: string, actorUserId: string) {
    const { rows } = await this.pool.query(
      `SELECT id, export_kind, subject_user_id, status
       FROM compliance_export_requests
       WHERE tenant_id = $1 AND id = $2::uuid`,
      [tenantId, exportId],
    );
    const row = rows[0];
    if (!row) throw new NotFoundException('Export request not found');
    if (row.status !== 'completed') {
      throw new BadRequestException(`Export not ready (status=${row.status})`);
    }
    if (row.export_kind === 'subject_package') {
      if (!row.subject_user_id) throw new BadRequestException('Export missing subject');
      return this.exportSubjectPackage(tenantId, row.subject_user_id as string, actorUserId);
    }
    return this.exportAuditBundle(tenantId, actorUserId);
  }

  async listExports(tenantId: string, limit = 50) {
    const n = Math.min(100, Math.max(1, limit));
    const { rows } = await this.pool.query(
      `SELECT id, export_kind, subject_user_id, status, result_summary, error_message,
              requested_by, created_at, completed_at
       FROM compliance_export_requests
       WHERE tenant_id = $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [tenantId, n],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        exportKind: r.export_kind,
        subjectUserId: r.subject_user_id,
        status: r.status,
        resultSummary: r.result_summary,
        errorMessage: r.error_message,
        requestedBy: r.requested_by,
        createdAt: r.created_at,
        completedAt: r.completed_at,
      })),
    };
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

    await this.audit.logRead({
      tenantId,
      actorUserId,
      action: 'compliance.export_audit_bundle',
      resourceType: 'compliance_export',
      resourceId: tenantId,
      metadata: { auditRows: audit.rows.length },
    });

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

  async exportSubjectPackage(tenantId: string, subjectUserId: string, actorUserId: string) {
    const user = await this.pool.query(
      `SELECT id, email, status, pii_classification, created_at
       FROM users WHERE tenant_id = $1 AND id = $2::uuid`,
      [tenantId, subjectUserId],
    );
    if (!user.rows[0]) throw new NotFoundException('Subject user not found in tenant');

    const [orders, entitlements, guests, notifications, deletions] = await Promise.all([
      this.pool.query(
        `SELECT id, event_id, status, currency, total_minor, created_at
         FROM ticket_orders WHERE tenant_id = $1 AND buyer_user_id = $2::uuid
         ORDER BY created_at DESC LIMIT 500`,
        [tenantId, subjectUserId],
      ),
      this.pool.query(
        `SELECT id, event_id, status, ticket_code, issued_at
         FROM ticket_entitlements WHERE tenant_id = $1 AND holder_user_id = $2::uuid
         ORDER BY issued_at DESC LIMIT 500`,
        [tenantId, subjectUserId],
      ),
      this.pool.query(
        `SELECT id, event_id, name, email, rsvp_status, created_at
         FROM event_guests WHERE tenant_id = $1
           AND (email = (SELECT email FROM users WHERE id = $2::uuid)
                OR metadata->>'userId' = $2)
         LIMIT 500`,
        [tenantId, subjectUserId],
      ).catch(() => ({ rows: [] })),
      this.pool.query(
        `SELECT id, channel, template, status, created_at, sent_at
         FROM notification_deliveries WHERE tenant_id = $1 AND recipient = (
           SELECT email FROM users WHERE id = $2::uuid
         )
         ORDER BY created_at DESC LIMIT 500`,
        [tenantId, subjectUserId],
      ),
      this.pool.query(
        `SELECT id, status, reason, created_at, completed_at
         FROM data_deletion_requests
         WHERE tenant_id = $1 AND subject_user_id = $2::uuid`,
        [tenantId, subjectUserId],
      ),
    ]);

    return {
      generatedAt: new Date().toISOString(),
      tenantId,
      exportedBy: actorUserId,
      subject: user.rows[0],
      ticketOrders: orders.rows,
      entitlements: entitlements.rows,
      guests: guests.rows,
      notifications: notifications.rows,
      deletionRequests: deletions.rows,
      note: 'Read-only composition of canonical tables — Finance/Tickets remain owners',
    };
  }

  async listDeletionRequests(tenantId: string, limit = 50) {
    const n = Math.min(100, Math.max(1, limit));
    const { rows } = await this.pool.query(
      `SELECT d.id, d.subject_user_id, d.status, d.reason, d.requested_by,
              d.reviewed_by, d.approved_by, d.rejection_reason,
              d.created_at, d.reviewed_at, d.approved_at, d.completed_at,
              u.email AS subject_email
       FROM data_deletion_requests d
       LEFT JOIN users u ON u.id = d.subject_user_id
       WHERE d.tenant_id = $1
       ORDER BY d.created_at DESC
       LIMIT $2`,
      [tenantId, n],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        subjectUserId: r.subject_user_id,
        subjectEmail: r.subject_email,
        status: r.status,
        reason: r.reason,
        requestedBy: r.requested_by,
        reviewedBy: r.reviewed_by,
        approvedBy: r.approved_by,
        rejectionReason: r.rejection_reason,
        createdAt: r.created_at,
        reviewedAt: r.reviewed_at,
        approvedAt: r.approved_at,
        completedAt: r.completed_at,
      })),
    };
  }

  async requestDataDeletion(params: {
    tenantId: string;
    subjectUserId: string;
    requestedBy: string;
    reason: string;
  }) {
    const subject = await this.pool.query(
      `SELECT id FROM users WHERE tenant_id = $1 AND id = $2::uuid`,
      [params.tenantId, params.subjectUserId],
    );
    if (!subject.rows[0]) throw new NotFoundException('Subject user not found in tenant');

    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO data_deletion_requests (tenant_id, subject_user_id, requested_by, reason, status)
       VALUES ($1, $2, $3, $4, 'pending')
       RETURNING id::text`,
      [params.tenantId, params.subjectUserId, params.requestedBy, params.reason],
    );

    await this.audit.logAction({
      tenantId: params.tenantId,
      actorUserId: params.requestedBy,
      action: 'compliance.deletion_requested',
      resourceType: 'data_deletion_request',
      resourceId: rows[0].id,
      metadata: { subjectUserId: params.subjectUserId },
    });

    return { id: rows[0].id, status: 'pending' };
  }

  async transitionDeletion(params: {
    tenantId: string;
    requestId: string;
    actorUserId: string;
    action: DeletionAction;
    rejectionReason?: string;
  }) {
    const { rows } = await this.pool.query(
      `SELECT * FROM data_deletion_requests WHERE id = $1::uuid AND tenant_id = $2`,
      [params.requestId, params.tenantId],
    );
    const req = rows[0];
    if (!req) throw new NotFoundException('Deletion request not found');

    const status = req.status as string;

    if (params.action === 'review') {
      if (status !== 'pending') throw new BadRequestException('Only pending requests can enter review');
      await this.pool.query(
        `UPDATE data_deletion_requests
         SET status = 'reviewing', reviewed_by = $2::uuid, reviewed_at = now()
         WHERE id = $1::uuid`,
        [params.requestId, params.actorUserId],
      );
    } else if (params.action === 'approve') {
      if (!['pending', 'reviewing'].includes(status)) {
        throw new BadRequestException('Request not approvable in current status');
      }
      await this.pool.query(
        `UPDATE data_deletion_requests
         SET status = 'approved', approved_by = $2::uuid, approved_at = now(),
             reviewed_by = COALESCE(reviewed_by, $2::uuid),
             reviewed_at = COALESCE(reviewed_at, now())
         WHERE id = $1::uuid`,
        [params.requestId, params.actorUserId],
      );
    } else if (params.action === 'reject') {
      if (['completed', 'processing', 'rejected'].includes(status)) {
        throw new BadRequestException('Request cannot be rejected in current status');
      }
      await this.pool.query(
        `UPDATE data_deletion_requests
         SET status = 'rejected', rejection_reason = $2, completed_at = now(),
             reviewed_by = COALESCE(reviewed_by, $3::uuid),
             reviewed_at = COALESCE(reviewed_at, now())
         WHERE id = $1::uuid`,
        [params.requestId, params.rejectionReason ?? 'Rejected by operator', params.actorUserId],
      );
    } else if (params.action === 'process') {
      if (!['approved', 'pending', 'reviewing'].includes(status)) {
        throw new BadRequestException('Request must be approved (or legacy pending) before process');
      }
      // Retention check — finance ownership preserved; only identity anonymization
      const retention = await this.getRetentionPolicies(params.tenantId);
      await this.pool.query(
        `UPDATE data_deletion_requests SET status = 'processing' WHERE id = $1::uuid`,
        [params.requestId],
      );
      try {
        await this.anonymizeSubject(params.tenantId, req.subject_user_id as string, params.requestId);
        await this.pool.query(
          `UPDATE data_deletion_requests
           SET status = 'completed', completed_at = now(),
               metadata = metadata || $2::jsonb
           WHERE id = $1::uuid`,
          [
            params.requestId,
            JSON.stringify({
              anonymizedAt: new Date().toISOString(),
              retentionSnapshot: retention,
              mode: 'anonymize_identity',
            }),
          ],
        );
      } catch (err) {
        const msg = err instanceof Error ? err.message : 'process_failed';
        await this.pool.query(
          `UPDATE data_deletion_requests
           SET status = 'approved', metadata = metadata || $2::jsonb
           WHERE id = $1::uuid`,
          [params.requestId, JSON.stringify({ lastProcessError: msg })],
        );
        throw err;
      }
    } else {
      throw new BadRequestException('Unknown action');
    }

    await this.audit.logAction({
      tenantId: params.tenantId,
      actorUserId: params.actorUserId,
      action: `compliance.deletion_${params.action}`,
      resourceType: 'data_deletion_request',
      resourceId: params.requestId,
      metadata: { previousStatus: status, rejectionReason: params.rejectionReason },
    });

    const listed = await this.listDeletionRequests(params.tenantId, 100);
    return listed.items.find((i) => i.id === params.requestId);
  }

  async complianceActivity(tenantId: string, limit = 50) {
    const n = Math.min(100, Math.max(1, limit));
    const { rows } = await this.pool.query(
      `SELECT id, actor_user_id, action, resource_type, resource_id, metadata, created_at
       FROM audit_log
       WHERE tenant_id = $1 AND action LIKE 'compliance.%'
       ORDER BY created_at DESC
       LIMIT $2`,
      [tenantId, n],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        actorUserId: r.actor_user_id,
        action: r.action,
        resourceType: r.resource_type,
        resourceId: r.resource_id,
        metadata: r.metadata,
        createdAt: r.created_at,
      })),
    };
  }

  async complianceReportCsv(tenantId: string) {
    const [exports, deletions, activity] = await Promise.all([
      this.listExports(tenantId, 100),
      this.listDeletionRequests(tenantId, 100),
      this.complianceActivity(tenantId, 100),
    ]);
    const lines = [
      'section,id,status,detail,created_at',
      ...exports.items.map(
        (e) =>
          `export,${e.id},${e.status},${e.exportKind},${e.createdAt ?? ''}`,
      ),
      ...deletions.items.map(
        (d) =>
          `deletion,${d.id},${d.status},${d.subjectUserId},${d.createdAt ?? ''}`,
      ),
      ...activity.items.map(
        (a) =>
          `audit,${a.id},${a.action},${a.resourceType},${a.createdAt ?? ''}`,
      ),
    ];
    const stamp = new Date().toISOString().slice(0, 10);
    return {
      filename: `compliance-governance-${stamp}.csv`,
      contentType: 'text/csv; charset=utf-8',
      body: lines.join('\n'),
    };
  }

  /**
   * Anonymize identity fields only. Ticket/finance rows remain for ledger integrity.
   */
  private async anonymizeSubject(tenantId: string, subjectUserId: string, requestId: string) {
    const token = subjectUserId.replace(/-/g, '').slice(0, 12);
    const anonEmail = `deleted-${token}@anonymized.local`;
    const { rowCount } = await this.pool.query(
      `UPDATE users
       SET email = $3,
           display_name = 'Deleted User',
           status = CASE WHEN status::text = 'active' THEN 'suspended' ELSE status END,
           pii_classification = 'restricted',
           updated_at = now()
       WHERE tenant_id = $1 AND id = $2::uuid`,
      [tenantId, subjectUserId, anonEmail],
    );
    if (!rowCount) throw new NotFoundException('Subject user missing during anonymization');

    // Clear guest PII that matches prior email patterns is best-effort via metadata
    await this.pool
      .query(
        `UPDATE event_guests
         SET email = NULL, phone_e164 = NULL, name = 'Redacted Guest',
             metadata = metadata || jsonb_build_object('complianceRedacted', true, 'deletionRequestId', $3::text),
             updated_at = now()
         WHERE tenant_id = $1
           AND metadata->>'userId' = $2`,
        [tenantId, subjectUserId, requestId],
      )
      .catch(() => undefined);

    this.logger.log(`Anonymized subject ${subjectUserId} for deletion request ${requestId}`);
  }

  private async ensureRetentionRow(tenantId: string) {
    await this.pool.query(
      `INSERT INTO compliance_retention_policies (tenant_id)
       VALUES ($1::uuid)
       ON CONFLICT (tenant_id) DO NOTHING`,
      [tenantId],
    );
  }
}
