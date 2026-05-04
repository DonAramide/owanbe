-- Hardening: admin segmentation, vendor_pending, read audit trail.
-- Apply after owanbe_core + 003 + 004.

BEGIN;

-- Rename legacy admin role code in-place (preserves user_roles FK).
UPDATE roles
SET code = 'admin_super',
    description = 'Full platform administrator'
WHERE code = 'admin';

INSERT INTO roles (code, description) VALUES
  ('vendor_pending', 'Vendor profile owner pending marketplace approval'),
  ('admin_ops', 'Operations administrator'),
  ('admin_support', 'Support administrator')
ON CONFLICT (code) DO NOTHING;

-- Ensure admin_super exists if DB was seeded without 'admin' row name.
INSERT INTO roles (code, description) VALUES
  ('admin_super', 'Full platform administrator')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS audit_log (
  id              BIGSERIAL PRIMARY KEY,
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  actor_user_id   UUID REFERENCES users (id) ON DELETE SET NULL,
  action          TEXT NOT NULL,
  resource_type   TEXT NOT NULL,
  resource_id     TEXT NOT NULL,
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS audit_log_tenant_created_idx
  ON audit_log (tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS audit_log_actor_created_idx
  ON audit_log (actor_user_id, created_at DESC);

COMMIT;
