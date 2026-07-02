-- Enterprise Workflow & Business Process Engine Schema
BEGIN;

CREATE TABLE IF NOT EXISTS workflow_definitions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_key    TEXT NOT NULL UNIQUE,
  label           TEXT NOT NULL,
  description     TEXT,
  version_number  INT NOT NULL DEFAULT 1,
  status          TEXT NOT NULL DEFAULT 'published', -- 'draft', 'published', 'archived'
  states          JSONB NOT NULL DEFAULT '{}'::JSONB,
  transitions     JSONB NOT NULL DEFAULT '[]'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workflow_instances (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  definition_id   UUID NOT NULL REFERENCES workflow_definitions (id) ON DELETE CASCADE,
  entity_id       TEXT NOT NULL,
  current_state   TEXT NOT NULL,
  assigned_to     TEXT, -- operator, role, or queue
  status          TEXT NOT NULL DEFAULT 'active', -- 'active', 'completed', 'escalated'
  context         JSONB NOT NULL DEFAULT '{}'::JSONB,
  sla_deadline    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workflow_history (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instance_id     UUID NOT NULL REFERENCES workflow_instances (id) ON DELETE CASCADE,
  from_state      TEXT NOT NULL,
  to_state        TEXT NOT NULL,
  transition_key  TEXT NOT NULL,
  performed_by    TEXT NOT NULL,
  reason          TEXT,
  context_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  duration_seconds INT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed Core Workflows
INSERT INTO workflow_definitions (workflow_key, label, description, version_number, status, states, transitions) VALUES
  (
    'vendor_approval',
    'Vendor Onboarding Verification',
    'Compliance routing for newly registered vendor accounts',
    1,
    'published',
    '{
      "draft": {"label": "Draft"},
      "under_review": {"label": "Compliance Audit"},
      "finance_check": {"label": "Finance Approval"},
      "approved": {"label": "Active Partner"},
      "rejected": {"label": "Rejected"}
    }'::JSONB,
    '[
      {"from": "draft", "to": "under_review", "trigger": "submit", "guards": [], "assignment": "round_robin", "actions": ["send_notification"]},
      {"from": "under_review", "to": "finance_check", "trigger": "approve_compliance", "guards": [], "assignment": "department", "actions": ["send_email"]},
      {"from": "finance_check", "to": "approved", "trigger": "approve_finance", "guards": ["vendor_verified"], "assignment": "system", "actions": ["send_whatsapp", "create_audit"]},
      {"from": "under_review", "to": "rejected", "trigger": "reject", "guards": [], "assignment": "system", "actions": ["send_email"]}
    ]'::JSONB
  ),
  (
    'refund_approval',
    'Refund Claim Approvals',
    'Conditional validation loops based on refund monetary value',
    1,
    'published',
    '{
      "pending": {"label": "Pending Claim"},
      "manager_review": {"label": "Manager Escrow Review"},
      "approved": {"label": "Refund Settled"},
      "rejected": {"label": "Claim Declined"}
    }'::JSONB,
    '[
      {"from": "pending", "to": "manager_review", "trigger": "evaluate", "guards": ["amount_threshold"], "assignment": "role_based", "actions": ["send_email"]},
      {"from": "manager_review", "to": "approved", "trigger": "grant", "guards": ["escrow_available"], "assignment": "system", "actions": ["release_payment", "create_audit"]}
    ]'::JSONB
  )
ON CONFLICT (workflow_key) DO UPDATE
  SET label = EXCLUDED.label,
      description = EXCLUDED.description,
      states = EXCLUDED.states,
      transitions = EXCLUDED.transitions;

COMMIT;
