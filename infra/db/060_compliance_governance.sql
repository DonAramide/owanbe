-- Phase 27 — Enterprise Compliance & Data Governance

BEGIN;

-- Expand retention categories (additive)
ALTER TABLE compliance_retention_policies
  ADD COLUMN IF NOT EXISTS marketing_retention_days INT NOT NULL DEFAULT 730
    CHECK (marketing_retention_days >= 30),
  ADD COLUMN IF NOT EXISTS notification_retention_days INT NOT NULL DEFAULT 365
    CHECK (notification_retention_days >= 30),
  ADD COLUMN IF NOT EXISTS guest_retention_days INT NOT NULL DEFAULT 1095
    CHECK (guest_retention_days >= 90);

-- Export request lifecycle (compose existing export bundle — not a second engine)
CREATE TABLE IF NOT EXISTS compliance_export_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  requested_by      UUID REFERENCES users (id) ON DELETE SET NULL,
  export_kind       TEXT NOT NULL DEFAULT 'audit_bundle'
                    CHECK (export_kind IN ('audit_bundle', 'subject_package')),
  subject_user_id   UUID REFERENCES users (id) ON DELETE SET NULL,
  status            TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  result_summary    JSONB NOT NULL DEFAULT '{}'::JSONB,
  error_message     TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS compliance_export_requests_tenant_idx
  ON compliance_export_requests (tenant_id, created_at DESC);

-- Deletion lifecycle enrichment
ALTER TABLE data_deletion_requests
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES users (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE data_deletion_requests DROP CONSTRAINT IF EXISTS data_deletion_requests_status_check;
ALTER TABLE data_deletion_requests
  ADD CONSTRAINT data_deletion_requests_status_check
  CHECK (status IN (
    'pending', 'reviewing', 'approved', 'processing', 'completed', 'rejected'
  ));

COMMIT;
