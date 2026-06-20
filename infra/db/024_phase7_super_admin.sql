-- Phase 7 — Super Admin Control Tower foundation
BEGIN;

INSERT INTO roles (code, description) VALUES
  ('super_admin', 'Owanbe control tower — cross-tenant platform operator')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS tenant_feature_flags (
  tenant_id    UUID NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  flag_key     TEXT NOT NULL,
  enabled      BOOLEAN NOT NULL DEFAULT true,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by   UUID REFERENCES users (id),
  PRIMARY KEY (tenant_id, flag_key),
  CONSTRAINT tenant_feature_flags_key_chk CHECK (
    flag_key IN ('ticket_commerce', 'vendor_commerce', 'live_operations', 'finance', 'reconciliation')
  )
);

CREATE TABLE IF NOT EXISTS platform_security_events (
  id             BIGSERIAL PRIMARY KEY,
  tenant_id      UUID REFERENCES tenants (id) ON DELETE SET NULL,
  event_type     TEXT NOT NULL,
  severity       TEXT NOT NULL DEFAULT 'warning' CHECK (severity IN ('info', 'warning', 'critical')),
  actor_user_id  UUID REFERENCES users (id) ON DELETE SET NULL,
  details        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT platform_security_events_type_chk CHECK (
    event_type IN ('failed_login', 'permission_escalation', 'suspicious_activity', 'finance_exception')
  )
);

CREATE INDEX IF NOT EXISTS platform_security_events_created_idx
  ON platform_security_events (created_at DESC);

INSERT INTO users (id, tenant_id, email, display_name, status)
VALUES (
  '88888888-8888-4888-8888-888888888888',
  '11111111-1111-4111-8111-111111111111',
  'superadmin@owanbe.dev',
  'Owanbe Control Tower',
  'active'
)
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT '88888888-8888-4888-8888-888888888888', r.id
FROM roles r
WHERE r.code = 'super_admin'
ON CONFLICT DO NOTHING;

INSERT INTO tenant_feature_flags (tenant_id, flag_key, enabled)
SELECT '11111111-1111-4111-8111-111111111111', f.flag_key, true
FROM (VALUES
  ('ticket_commerce'),
  ('vendor_commerce'),
  ('live_operations'),
  ('finance'),
  ('reconciliation')
) AS f(flag_key)
ON CONFLICT DO NOTHING;

INSERT INTO platform_security_events (tenant_id, event_type, severity, details)
VALUES
  (
    '11111111-1111-4111-8111-111111111111',
    'failed_login',
    'warning',
    '{"email":"unknown@example.com","ip":"203.0.113.10","attempts":3}'::JSONB
  ),
  (
    '11111111-1111-4111-8111-111111111111',
    'finance_exception',
    'info',
    '{"code":"PAYOUT_DELAY","message":"Organizer payout held in escrow"}'::JSONB
  );

COMMIT;
