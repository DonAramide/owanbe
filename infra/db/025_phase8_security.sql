-- Phase 8 — Identity, Access & Security Hardening
BEGIN;

-- Canonical permission codes (granular RBAC)
CREATE TABLE IF NOT EXISTS permissions (
  code        TEXT PRIMARY KEY,
  description TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO permissions (code, description) VALUES
  ('event.create', 'Create events'),
  ('event.publish', 'Publish events'),
  ('event.close', 'Force-close or complete events'),
  ('vendor.apply', 'Apply as vendor'),
  ('vendor.approve', 'Approve vendor applications'),
  ('finance.view', 'View finance data'),
  ('finance.refund', 'Issue or approve refunds'),
  ('finance.payout', 'Trigger or approve payouts'),
  ('tenant.manage', 'Manage tenant configuration'),
  ('tenant.suspend', 'Suspend or reactivate tenants')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id         SMALLINT NOT NULL REFERENCES roles (id) ON DELETE CASCADE,
  permission_code TEXT NOT NULL REFERENCES permissions (code) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_code)
);

-- Phase 8 canonical roles (additive; legacy codes retained)
INSERT INTO roles (code, description) VALUES
  ('organizer', 'Event organizer operator'),
  ('platform_admin', 'Platform operational administrator')
ON CONFLICT (code) DO NOTHING;

-- attendee → client role permissions
INSERT INTO role_permissions (role_id, permission_code)
SELECT r.id, p.code FROM roles r
CROSS JOIN (VALUES ('vendor.apply')) AS p(code)
WHERE r.code = 'client'
ON CONFLICT DO NOTHING;

-- organizer
INSERT INTO role_permissions (role_id, permission_code)
SELECT r.id, p.code FROM roles r
CROSS JOIN (VALUES
  ('event.create'), ('event.publish'), ('event.close'),
  ('finance.view'), ('finance.payout')
) AS p(code)
WHERE r.code = 'organizer'
ON CONFLICT DO NOTHING;

-- vendor
INSERT INTO role_permissions (role_id, permission_code)
SELECT r.id, p.code FROM roles r
CROSS JOIN (VALUES
  ('vendor.apply'), ('finance.view'), ('finance.payout')
) AS p(code)
WHERE r.code IN ('vendor', 'vendor_pending')
ON CONFLICT DO NOTHING;

-- platform_admin (maps admin tiers)
INSERT INTO role_permissions (role_id, permission_code)
SELECT r.id, p.code FROM roles r
CROSS JOIN permissions p
WHERE r.code IN ('admin_super', 'admin_ops', 'admin_support', 'platform_admin')
ON CONFLICT DO NOTHING;

-- super_admin — all permissions
INSERT INTO role_permissions (role_id, permission_code)
SELECT r.id, p.code FROM roles r
CROSS JOIN permissions p
WHERE r.code = 'super_admin'
ON CONFLICT DO NOTHING;

-- Dev organizer user gets organizer role
INSERT INTO user_roles (user_id, role_id)
SELECT '22222222-2222-4222-8222-222222222222', r.id
FROM roles r WHERE r.code = 'organizer'
ON CONFLICT DO NOTHING;

-- Extend security event types
ALTER TABLE platform_security_events DROP CONSTRAINT IF EXISTS platform_security_events_type_chk;
ALTER TABLE platform_security_events ADD CONSTRAINT platform_security_events_type_chk CHECK (
  event_type IN (
    'failed_login', 'permission_escalation', 'suspicious_activity', 'finance_exception',
    'rate_limit_violation', 'session_abuse'
  )
);

-- PII classification on users
ALTER TABLE users ADD COLUMN IF NOT EXISTS pii_classification TEXT NOT NULL DEFAULT 'standard'
  CHECK (pii_classification IN ('standard', 'sensitive', 'restricted'));

-- Compliance: retention policies per tenant
CREATE TABLE IF NOT EXISTS compliance_retention_policies (
  tenant_id           UUID PRIMARY KEY REFERENCES tenants (id) ON DELETE CASCADE,
  audit_retention_days INT NOT NULL DEFAULT 365 CHECK (audit_retention_days >= 30),
  finance_retention_days INT NOT NULL DEFAULT 2555 CHECK (finance_retention_days >= 365),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO compliance_retention_policies (tenant_id)
SELECT id FROM tenants
ON CONFLICT DO NOTHING;

-- Data deletion workflow
CREATE TABLE IF NOT EXISTS data_deletion_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  subject_user_id UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  status          TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'rejected')),
  requested_by    UUID REFERENCES users (id),
  reason          TEXT NOT NULL DEFAULT '',
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS data_deletion_requests_tenant_idx
  ON data_deletion_requests (tenant_id, status);

COMMIT;
