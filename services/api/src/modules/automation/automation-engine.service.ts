import { Injectable, Inject, Logger } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';
import { NotificationService } from '../../integrations/notifications/notification.service';
import { DomainEventsService } from '../domain-events/domain-events.service';
import { DOMAIN_EVENTS } from '../domain-events/domain-event.types';
import type { DomainEvent } from '../domain-events/domain-event.types';
import { OrganizerReportsService } from '../organizer-reports/organizer-reports.service';

type WorkflowAction = {
  type: string;
  channel?: string;
  template?: string;
  subject?: string;
  body?: string;
  pack?: string;
  format?: string;
};

type WorkflowDef = {
  id: string;
  workflow_key: string;
  label: string;
  trigger_kind: string;
  trigger_key: string | null;
  schedule_expr: string | null;
  conditions: unknown;
  actions: unknown;
  scope: string;
  enabled: boolean;
  status: string;
};

/**
 * Phase 23 — read-only orchestration engine.
 * Evaluates definitions, dispatches existing services, records runs.
 */
@Injectable()
export class AutomationEngineService {
  private readonly logger = new Logger(AutomationEngineService.name);
  private listening = false;

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly events: DomainEventsService,
    private readonly notifications: NotificationService,
    private readonly audit: AuditLogService,
    private readonly reports: OrganizerReportsService,
  ) {}

  startListening() {
    if (this.listening) return;
    this.listening = true;
    this.events.on('*', (event) => this.onDomainEvent(event));
  }

  private async onDomainEvent(event: DomainEvent) {
    if (event.name === DOMAIN_EVENTS.SCHEDULE_TICK) {
      await this.processDueJobs();
      return;
    }
    await this.runMatchingEventRules(event);
  }

  async runMatchingEventRules(event: DomainEvent) {
    const defs = await this.loadEventDefs(event.name);
    for (const def of defs) {
      const organizerId = event.payload.organizerId ?? null;
      if (def.scope === 'organizer' && !organizerId) {
        await this.recordSkip(def, event, 'missing_organizer_id');
        continue;
      }
      if (organizerId && !(await this.isEnabledForOrganizer(event.payload.tenantId, organizerId, def.workflow_key))) {
        await this.recordSkip(def, event, 'disabled_by_organizer');
        continue;
      }
      if (!this.evaluateConditions(def.conditions, event.payload.data ?? {})) {
        await this.recordSkip(def, event, 'conditions_not_met');
        continue;
      }
      await this.executeDefinition(def, {
        triggerKind: 'event',
        triggerKey: event.name,
        tenantId: event.payload.tenantId,
        organizerId,
        entityId: event.payload.entityId ?? event.payload.eventId ?? null,
        context: {
          ...event.payload.data,
          eventId: event.payload.eventId,
          actorUserId: event.payload.actorUserId,
        },
      });
    }
  }

  private async loadEventDefs(triggerKey: string): Promise<WorkflowDef[]> {
    const { rows } = await this.pool.query<WorkflowDef>(
      `SELECT id, workflow_key, label, trigger_kind, trigger_key, schedule_expr,
              conditions, actions, scope, enabled, status
       FROM workflow_definitions
       WHERE status = 'published' AND enabled = true
         AND trigger_kind = 'event' AND trigger_key = $1`,
      [triggerKey],
    );
    return rows;
  }

  async listDefinitions(organizerId?: string, tenantId?: string) {
    const { rows } = await this.pool.query<WorkflowDef & { description: string; override_enabled: boolean | null }>(
      `SELECT d.id, d.workflow_key, d.label, d.trigger_kind, d.trigger_key,
              d.schedule_expr, d.conditions, d.actions, d.scope, d.enabled, d.status,
              o.enabled AS override_enabled
       FROM workflow_definitions d
       LEFT JOIN automation_rule_overrides o
         ON o.workflow_key = d.workflow_key
        AND o.organizer_id = $1
        AND o.tenant_id = $2
       WHERE d.status = 'published'
         AND (d.scope = 'platform' OR d.scope = 'organizer')
       ORDER BY d.trigger_kind, d.label`,
      [organizerId ?? null, tenantId ?? null],
    );
    return rows.map((r) => ({
      id: r.id,
      workflowKey: r.workflow_key,
      label: r.label,
      triggerKind: r.trigger_kind,
      triggerKey: r.trigger_key,
      scheduleExpr: r.schedule_expr,
      scope: r.scope,
      enabled: r.override_enabled == null ? r.enabled : r.override_enabled,
      defaultEnabled: r.enabled,
      actions: r.actions,
      conditions: r.conditions,
    }));
  }

  async setOverride(
    tenantId: string,
    organizerId: string,
    workflowKey: string,
    enabled: boolean,
  ) {
    await this.pool.query(
      `INSERT INTO automation_rule_overrides (tenant_id, organizer_id, workflow_key, enabled, updated_at)
       VALUES ($1, $2, $3, $4, now())
       ON CONFLICT (organizer_id, workflow_key) DO UPDATE
         SET enabled = EXCLUDED.enabled, updated_at = now()`,
      [tenantId, organizerId, workflowKey, enabled],
    );
    return { ok: true, workflowKey, enabled };
  }

  async listRuns(tenantId: string, organizerId: string | null, limit = 50) {
    const n = Math.min(100, Math.max(1, limit));
    const { rows } = await this.pool.query(
      `SELECT r.id, r.workflow_key, r.trigger_kind, r.trigger_key, r.status, r.entity_id,
              r.error_message, r.started_at, r.finished_at, r.context,
              COALESCE(
                json_agg(
                  json_build_object(
                    'id', a.id,
                    'actionType', a.action_type,
                    'status', a.status,
                    'attempts', a.attempts,
                    'errorMessage', a.error_message,
                    'finishedAt', a.finished_at
                  ) ORDER BY a.created_at
                ) FILTER (WHERE a.id IS NOT NULL),
                '[]'
              ) AS actions
       FROM automation_runs r
       LEFT JOIN automation_run_actions a ON a.run_id = r.id
       WHERE r.tenant_id = $1
         AND ($2::uuid IS NULL OR r.organizer_id = $2)
       GROUP BY r.id
       ORDER BY r.started_at DESC
       LIMIT $3`,
      [tenantId, organizerId, n],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        workflowKey: r.workflow_key,
        triggerKind: r.trigger_kind,
        triggerKey: r.trigger_key,
        status: r.status,
        entityId: r.entity_id,
        errorMessage: r.error_message,
        startedAt: r.started_at,
        finishedAt: r.finished_at,
        context: r.context,
        actions: r.actions,
      })),
    };
  }

  /** Phase 25 — automation observability (reuses run/job tables). */
  async observabilitySnapshot(tenantId: string, organizerId: string) {
    const { rows: runStats } = await this.pool.query<{ status: string; n: string }>(
      `SELECT status, COUNT(*)::text AS n
       FROM automation_runs
       WHERE tenant_id = $1 AND (organizer_id = $2 OR organizer_id IS NULL)
       GROUP BY status`,
      [tenantId, organizerId],
    );
    let jobStats: { status: string; n: string }[] = [];
    try {
      const jobQ = await this.pool.query<{ status: string; n: string }>(
        `SELECT status, COUNT(*)::text AS n
         FROM automation_jobs
         WHERE tenant_id = $1 AND (organizer_id = $2 OR organizer_id IS NULL)
         GROUP BY status`,
        [tenantId, organizerId],
      );
      jobStats = jobQ.rows;
    } catch {
      jobStats = [];
    }

    const byStatus = (rows: { status: string; n: string }[]) =>
      Object.fromEntries(rows.map((r) => [r.status, parseInt(r.n, 10)]));

    const runs = byStatus(runStats);
    const jobs = byStatus(jobStats);

    return {
      organizerId,
      generatedAt: new Date().toISOString(),
      executions: {
        success: (runs.succeeded ?? 0) + (runs.success ?? 0) + (runs.completed ?? 0),
        failed: runs.failed ?? 0,
        skipped: runs.skipped ?? 0,
        running: runs.running ?? 0,
        byStatus: runs,
      },
      jobs: {
        due: (jobs.pending ?? 0) + (jobs.queued ?? 0),
        failed: jobs.failed ?? 0,
        dead: (jobs.dead_letter ?? 0) + (jobs.dead ?? 0),
        byStatus: jobs,
      },
    };
  }

  async enqueueJob(params: {
    tenantId: string;
    organizerId?: string | null;
    workflowKey: string;
    runAt: Date;
    payload?: Record<string, unknown>;
    dedupeKey?: string;
  }) {
    await this.pool.query(
      `INSERT INTO automation_jobs (
         tenant_id, organizer_id, workflow_key, run_at, payload, dedupe_key
       )
       SELECT $1, $2, $3, $4, $5::jsonb, $6
       WHERE $6::text IS NULL OR NOT EXISTS (
         SELECT 1 FROM automation_jobs
         WHERE dedupe_key = $6 AND status IN ('pending', 'running')
       )`,
      [
        params.tenantId,
        params.organizerId ?? null,
        params.workflowKey,
        params.runAt.toISOString(),
        JSON.stringify(params.payload ?? {}),
        params.dedupeKey ?? null,
      ],
    );
  }

  async processDueJobs() {
    const { rows } = await this.pool.query<{
      id: string;
      tenant_id: string;
      organizer_id: string | null;
      workflow_key: string;
      payload: Record<string, unknown>;
      attempts: number;
      max_attempts: number;
    }>(
      `UPDATE automation_jobs
       SET status = 'running', attempts = attempts + 1, updated_at = now()
       WHERE id IN (
         SELECT id FROM automation_jobs
         WHERE status = 'pending' AND run_at <= now()
         ORDER BY run_at ASC
         LIMIT 25
         FOR UPDATE SKIP LOCKED
       )
       RETURNING id, tenant_id, organizer_id, workflow_key, payload, attempts, max_attempts`,
    );

    for (const job of rows) {
      try {
        const { rows: defs } = await this.pool.query<WorkflowDef>(
          `SELECT id, workflow_key, label, trigger_kind, trigger_key, schedule_expr,
                  conditions, actions, scope, enabled, status
           FROM workflow_definitions WHERE workflow_key = $1 LIMIT 1`,
          [job.workflow_key],
        );
        const def = defs[0];
        if (!def || !def.enabled) {
          await this.pool.query(
            `UPDATE automation_jobs SET status = 'cancelled', updated_at = now() WHERE id = $1`,
            [job.id],
          );
          continue;
        }
        await this.executeDefinition(def, {
          triggerKind: 'schedule',
          triggerKey: def.trigger_key ?? 'schedule.tick',
          tenantId: job.tenant_id,
          organizerId: job.organizer_id,
          entityId: job.id,
          context: job.payload ?? {},
        });
        await this.pool.query(
          `UPDATE automation_jobs SET status = 'done', updated_at = now() WHERE id = $1`,
          [job.id],
        );
      } catch (err) {
        const msg = (err as Error).message;
        const fail =
          job.attempts >= job.max_attempts
            ? 'failed'
            : 'pending';
        await this.pool.query(
          `UPDATE automation_jobs
           SET status = $2, last_error = $3, run_at = CASE WHEN $2 = 'pending' THEN now() + interval '5 minutes' ELSE run_at END,
               updated_at = now()
           WHERE id = $1`,
          [job.id, fail, msg],
        );
      }
    }
  }

  private async isEnabledForOrganizer(tenantId: string, organizerId: string, workflowKey: string) {
    const { rows } = await this.pool.query<{ enabled: boolean }>(
      `SELECT enabled FROM automation_rule_overrides
       WHERE tenant_id = $1 AND organizer_id = $2 AND workflow_key = $3`,
      [tenantId, organizerId, workflowKey],
    );
    if (rows[0]) return rows[0].enabled;
    const { rows: defs } = await this.pool.query<{ enabled: boolean }>(
      `SELECT enabled FROM workflow_definitions WHERE workflow_key = $1`,
      [workflowKey],
    );
    return defs[0]?.enabled ?? false;
  }

  private evaluateConditions(raw: unknown, data: Record<string, unknown>): boolean {
    const conditions = Array.isArray(raw) ? raw : [];
    for (const c of conditions) {
      if (!c || typeof c !== 'object') continue;
      const cond = c as { field?: string; op?: string; value?: unknown };
      const field = cond.field ?? '';
      const actual = data[field];
      const op = cond.op ?? 'eq';
      if (op === 'eq' && actual !== cond.value) return false;
      if (op === 'neq' && actual === cond.value) return false;
      if (op === 'exists' && (actual === undefined || actual === null || actual === '')) return false;
    }
    return true;
  }

  private async recordSkip(def: WorkflowDef, event: DomainEvent, reason: string) {
    await this.pool.query(
      `INSERT INTO automation_runs (
         tenant_id, organizer_id, workflow_key, trigger_kind, trigger_key, status, entity_id, context, finished_at
       ) VALUES ($1, $2, $3, 'event', $4, 'skipped', $5, $6::jsonb, now())`,
      [
        event.payload.tenantId,
        event.payload.organizerId ?? null,
        def.workflow_key,
        event.name,
        event.payload.entityId ?? null,
        JSON.stringify({ reason }),
      ],
    );
  }

  private async executeDefinition(
    def: WorkflowDef,
    opts: {
      triggerKind: string;
      triggerKey: string;
      tenantId: string;
      organizerId: string | null;
      entityId: string | null;
      context: Record<string, unknown>;
    },
  ) {
    const { rows: runRows } = await this.pool.query<{ id: string }>(
      `INSERT INTO automation_runs (
         tenant_id, organizer_id, workflow_key, trigger_kind, trigger_key, status, entity_id, context
       ) VALUES ($1, $2, $3, $4, $5, 'running', $6, $7::jsonb)
       RETURNING id`,
      [
        opts.tenantId,
        opts.organizerId,
        def.workflow_key,
        opts.triggerKind,
        opts.triggerKey,
        opts.entityId,
        JSON.stringify(opts.context),
      ],
    );
    const runId = runRows[0]!.id;

    let instanceId: string | null = null;
    try {
      const { rows: inst } = await this.pool.query<{ id: string }>(
        `INSERT INTO workflow_instances (definition_id, entity_id, current_state, status, context)
         VALUES ($1, $2, 'running', 'active', $3::jsonb)
         RETURNING id`,
        [def.id, opts.entityId ?? opts.triggerKey, JSON.stringify(opts.context)],
      );
      instanceId = inst[0]?.id ?? null;
    } catch (err) {
      this.logger.warn(`workflow_instances insert skipped: ${(err as Error).message}`);
    }

    const actions = (Array.isArray(def.actions) ? def.actions : []) as WorkflowAction[];
    let failed = false;
    let lastError: string | null = null;

    for (const action of actions) {
      const { rows: actionRows } = await this.pool.query<{ id: string }>(
        `INSERT INTO automation_run_actions (run_id, action_type, status, attempts)
         VALUES ($1, $2, 'pending', 1) RETURNING id`,
        [runId, action.type],
      );
      const actionId = actionRows[0]!.id;
      try {
        const detail = await this.dispatchAction(action, opts);
        await this.pool.query(
          `UPDATE automation_run_actions
           SET status = 'completed', detail = $2::jsonb, finished_at = now()
           WHERE id = $1`,
          [actionId, JSON.stringify(detail ?? {})],
        );
      } catch (err) {
        failed = true;
        lastError = (err as Error).message;
        await this.pool.query(
          `UPDATE automation_run_actions
           SET status = 'failed', error_message = $2, finished_at = now()
           WHERE id = $1`,
          [actionId, lastError],
        );
      }
    }

    await this.pool.query(
      `UPDATE automation_runs
       SET status = $2, error_message = $3, finished_at = now(), instance_id = $4
       WHERE id = $1`,
      [runId, failed ? 'failed' : 'completed', lastError, instanceId],
    );

    if (instanceId) {
      await this.pool.query(
        `INSERT INTO workflow_history (
           instance_id, from_state, to_state, transition_key, performed_by, reason, context_snapshot
         ) VALUES ($1, 'idle', $2, $3, 'automation', $4, $5::jsonb)`,
        [
          instanceId,
          failed ? 'failed' : 'done',
          opts.triggerKey,
          lastError ?? 'ok',
          JSON.stringify(opts.context),
        ],
      );
      await this.pool.query(
        `UPDATE workflow_instances
         SET current_state = $2, status = $3, updated_at = now()
         WHERE id = $1`,
        [instanceId, failed ? 'failed' : 'done', failed ? 'escalated' : 'completed'],
      );
    }

    try {
      await this.audit.logAction({
        tenantId: opts.tenantId,
        actorUserId: typeof opts.context.actorUserId === 'string' ? opts.context.actorUserId : opts.tenantId,
        action: failed ? 'automation.run.failed' : 'automation.run.completed',
        resourceType: 'automation_run',
        resourceId: runId,
        metadata: { workflowKey: def.workflow_key, triggerKey: opts.triggerKey },
      });
    } catch {
      /* audit must not fail the run */
    }
  }

  private async dispatchAction(
    action: WorkflowAction,
    opts: {
      tenantId: string;
      organizerId: string | null;
      entityId: string | null;
      context: Record<string, unknown>;
    },
  ): Promise<Record<string, unknown>> {
    switch (action.type) {
      case 'notify_organizer':
      case 'send_notification':
      case 'send_email':
        return this.actionNotifyOrganizer(action, opts);
      case 'generate_report':
      case 'export_report':
        return this.actionGenerateReport(action, opts);
      case 'process_due_jobs':
        // Nested due processing avoided — scheduler already processes jobs
        return { ok: true, note: 'due_jobs_handled_by_scheduler' };
      case 'update_workflow_state':
        return { ok: true, note: 'state_updated_via_instance' };
      default:
        throw new Error(`Unknown action type: ${action.type}`);
    }
  }

  private async actionNotifyOrganizer(
    action: WorkflowAction,
    opts: {
      tenantId: string;
      organizerId: string | null;
      context: Record<string, unknown>;
    },
  ) {
    const recipient = await this.resolveOrganizerEmail(opts.tenantId, opts.organizerId);
    if (!recipient) {
      return { ok: false, reason: 'organizer_email_unavailable' };
    }
    const subject =
      action.subject ??
      `Owambe automation: ${String(opts.context.summary ?? action.template ?? 'update')}`;
    const body =
      action.body ??
      `Automation notification\n\n${JSON.stringify(opts.context, null, 2)}\n`;
    const result = await this.notifications.send({
      tenantId: opts.tenantId,
      channel: (action.channel as 'email' | 'sms' | 'push') || 'email',
      template: action.template ?? 'automation_generic',
      recipient,
      subject,
      body,
      metadata: { organizerId: opts.organizerId, source: 'automation' },
    });
    return { ok: result.ok, deliveryId: result.deliveryId, reason: result.reason };
  }

  private async actionGenerateReport(
    action: WorkflowAction,
    opts: {
      tenantId: string;
      organizerId: string | null;
      context: Record<string, unknown>;
    },
  ) {
    if (!opts.organizerId) {
      return { ok: false, reason: 'organizer_required' };
    }
    // Portfolio export — consume OrganizerReportsService (read-only)
    const ownerUserId = await this.resolveOrganizerOwnerUserId(opts.tenantId, opts.organizerId);
    if (!ownerUserId) {
      return { ok: false, reason: 'owner_unavailable' };
    }
    const out = await this.reports.exportPortfolio(
      { userId: ownerUserId, tenantId: opts.tenantId },
      action.format === 'xlsx' ? 'xlsx' : 'csv',
    );
    this.events.emit(DOMAIN_EVENTS.REPORT_GENERATED, {
      tenantId: opts.tenantId,
      organizerId: opts.organizerId,
      entityId: out.filename,
      data: { filename: out.filename, pack: action.pack ?? 'portfolio' },
    });
    return { ok: true, filename: out.filename, bytes: out.body.length };
  }

  private async resolveOrganizerEmail(tenantId: string, organizerId: string | null) {
    if (!organizerId) return null;
    const { rows } = await this.pool.query<{ email: string }>(
      `SELECT u.email FROM organizers o
       INNER JOIN users u ON u.id = o.owner_user_id
       WHERE o.id = $1 AND o.tenant_id = $2`,
      [organizerId, tenantId],
    );
    return rows[0]?.email ?? null;
  }

  private async resolveOrganizerOwnerUserId(tenantId: string, organizerId: string) {
    const { rows } = await this.pool.query<{ owner_user_id: string }>(
      `SELECT owner_user_id FROM organizers WHERE id = $1 AND tenant_id = $2`,
      [organizerId, tenantId],
    );
    return rows[0]?.owner_user_id ?? null;
  }
}
