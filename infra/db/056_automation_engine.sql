-- Phase 23 — Automation & Workflow Engine
-- Extends 040 workflow_* tables; durable due-jobs; run history. No Bull/Redis.

BEGIN;

ALTER TABLE workflow_definitions
  ADD COLUMN IF NOT EXISTS trigger_kind TEXT NOT NULL DEFAULT 'event'
    CHECK (trigger_kind IN ('event', 'schedule')),
  ADD COLUMN IF NOT EXISTS trigger_key TEXT,
  ADD COLUMN IF NOT EXISTS schedule_expr TEXT,
  ADD COLUMN IF NOT EXISTS conditions JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS actions JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS scope TEXT NOT NULL DEFAULT 'platform'
    CHECK (scope IN ('platform', 'organizer')),
  ADD COLUMN IF NOT EXISTS enabled BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS workflow_definitions_trigger_idx
  ON workflow_definitions (trigger_kind, trigger_key)
  WHERE status = 'published' AND enabled = true;

CREATE TABLE IF NOT EXISTS automation_rule_overrides (
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  organizer_id    UUID NOT NULL REFERENCES organizers (id) ON DELETE CASCADE,
  workflow_key    TEXT NOT NULL REFERENCES workflow_definitions (workflow_key) ON DELETE CASCADE,
  enabled         BOOLEAN NOT NULL DEFAULT true,
  config          JSONB NOT NULL DEFAULT '{}'::JSONB,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (organizer_id, workflow_key)
);

CREATE TABLE IF NOT EXISTS automation_jobs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  organizer_id    UUID REFERENCES organizers (id) ON DELETE CASCADE,
  workflow_key    TEXT NOT NULL,
  run_at          TIMESTAMPTZ NOT NULL,
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'running', 'done', 'failed', 'cancelled')),
  payload         JSONB NOT NULL DEFAULT '{}'::JSONB,
  attempts        INT NOT NULL DEFAULT 0,
  max_attempts    INT NOT NULL DEFAULT 3,
  last_error      TEXT,
  dedupe_key      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS automation_jobs_dedupe_uidx
  ON automation_jobs (dedupe_key)
  WHERE dedupe_key IS NOT NULL AND status IN ('pending', 'running');

CREATE INDEX IF NOT EXISTS automation_jobs_due_idx
  ON automation_jobs (status, run_at)
  WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS automation_runs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  organizer_id    UUID,
  workflow_key    TEXT NOT NULL,
  trigger_kind    TEXT NOT NULL,
  trigger_key     TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'received'
                  CHECK (status IN ('received', 'running', 'completed', 'failed', 'skipped')),
  entity_id       TEXT,
  context         JSONB NOT NULL DEFAULT '{}'::JSONB,
  error_message   TEXT,
  started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at     TIMESTAMPTZ,
  instance_id     UUID REFERENCES workflow_instances (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS automation_runs_org_started_idx
  ON automation_runs (organizer_id, started_at DESC);

CREATE TABLE IF NOT EXISTS automation_run_actions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id          UUID NOT NULL REFERENCES automation_runs (id) ON DELETE CASCADE,
  action_type     TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'completed', 'failed', 'skipped', 'retrying')),
  attempts        INT NOT NULL DEFAULT 0,
  detail          JSONB NOT NULL DEFAULT '{}'::JSONB,
  error_message   TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at     TIMESTAMPTZ
);

-- Organizer automation templates (orchestration only — actions call existing services)
INSERT INTO workflow_definitions (
  workflow_key, label, description, version_number, status,
  states, transitions, trigger_kind, trigger_key, schedule_expr,
  conditions, actions, scope, enabled
) VALUES
(
  'notify_on_ticket_issued',
  'Notify organizer on ticket issued',
  'When a ticket entitlement is issued, notify the organizer (additive to buyer confirmation).',
  1, 'published',
  '{"idle":{"label":"Idle"},"done":{"label":"Done"}}'::JSONB,
  '[{"from":"idle","to":"done","trigger":"ticket.issued","actions":["notify_organizer"]}]'::JSONB,
  'event', 'ticket.issued', NULL,
  '[]'::JSONB,
  '[{"type":"notify_organizer","channel":"email","template":"automation_ticket_issued"}]'::JSONB,
  'organizer', true
),
(
  'notify_on_rsvp_changed',
  'Notify organizer on RSVP change',
  'When a guest RSVP is confirmed or declined, notify the organizer.',
  1, 'published',
  '{"idle":{"label":"Idle"},"done":{"label":"Done"}}'::JSONB,
  '[{"from":"idle","to":"done","trigger":"rsvp.changed","actions":["notify_organizer"]}]'::JSONB,
  'event', 'rsvp.changed', NULL,
  '[]'::JSONB,
  '[{"type":"notify_organizer","channel":"email","template":"automation_rsvp_changed"}]'::JSONB,
  'organizer', true
),
(
  'notify_on_vendor_stage',
  'Notify organizer on vendor stage change',
  'When a vendor CRM request stage changes, notify the organizer.',
  1, 'published',
  '{"idle":{"label":"Idle"},"done":{"label":"Done"}}'::JSONB,
  '[{"from":"idle","to":"done","trigger":"vendor.stage_changed","actions":["notify_organizer"]}]'::JSONB,
  'event', 'vendor.stage_changed', NULL,
  '[]'::JSONB,
  '[{"type":"notify_organizer","channel":"email","template":"automation_vendor_stage"}]'::JSONB,
  'organizer', true
),
(
  'notify_on_refund_completed',
  'Notify organizer on refund completed',
  'When a refund case completes, notify the organizer.',
  1, 'published',
  '{"idle":{"label":"Idle"},"done":{"label":"Done"}}'::JSONB,
  '[{"from":"idle","to":"done","trigger":"refund.completed","actions":["notify_organizer"]}]'::JSONB,
  'event', 'refund.completed', NULL,
  '[]'::JSONB,
  '[{"type":"notify_organizer","channel":"email","template":"automation_refund_completed"}]'::JSONB,
  'organizer', true
),
(
  'schedule_rsvp_reminder_sweep',
  'Scheduled RSVP reminder sweep',
  'Due-job sweeper template: process pending reminder notification jobs.',
  1, 'published',
  '{"idle":{"label":"Idle"},"done":{"label":"Done"}}'::JSONB,
  '[]'::JSONB,
  'schedule', 'schedule.tick', 'every_5m',
  '[]'::JSONB,
  '[{"type":"process_due_jobs"}]'::JSONB,
  'platform', true
),
(
  'schedule_export_portfolio_weekly',
  'Weekly portfolio export reminder',
  'Schedule-driven: enqueue portfolio report generation reminder for organizers.',
  1, 'published',
  '{"idle":{"label":"Idle"},"done":{"label":"Done"}}'::JSONB,
  '[]'::JSONB,
  'schedule', 'schedule.weekly_export', 'weekly',
  '[]'::JSONB,
  '[{"type":"notify_organizer","channel":"email","template":"automation_weekly_export"}]'::JSONB,
  'organizer', false
)
ON CONFLICT (workflow_key) DO UPDATE SET
  label = EXCLUDED.label,
  description = EXCLUDED.description,
  trigger_kind = EXCLUDED.trigger_kind,
  trigger_key = EXCLUDED.trigger_key,
  schedule_expr = EXCLUDED.schedule_expr,
  conditions = EXCLUDED.conditions,
  actions = EXCLUDED.actions,
  scope = EXCLUDED.scope,
  enabled = EXCLUDED.enabled,
  updated_at = now();

COMMIT;
