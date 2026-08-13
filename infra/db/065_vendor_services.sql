-- Phase 065 — First-class vendor_services (additive)
-- Keeps vendor_profiles.services_offered and vendor_event_requests.service_key for compatibility.
-- Does not change pricing rules schema.

BEGIN;

CREATE TABLE IF NOT EXISTS vendor_services (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id       UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
  service_key     TEXT NOT NULL,
  service_name    TEXT NOT NULL,
  description     TEXT,
  status          TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'archived')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT vendor_services_vendor_key_uidx UNIQUE (vendor_id, service_key)
);

CREATE INDEX IF NOT EXISTS vendor_services_tenant_vendor_idx
  ON vendor_services (tenant_id, vendor_id, status);

CREATE INDEX IF NOT EXISTS vendor_services_tenant_key_idx
  ON vendor_services (tenant_id, service_key)
  WHERE status = 'active';

COMMENT ON TABLE vendor_services IS
  'First-class per-vendor service entities. Labels in vendor_profiles.services_offered remain for backward compatibility.';

ALTER TABLE vendor_event_requests
  ADD COLUMN IF NOT EXISTS vendor_service_id UUID NULL
    REFERENCES vendor_services (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS vendor_event_requests_vendor_service_id_idx
  ON vendor_event_requests (vendor_service_id)
  WHERE vendor_service_id IS NOT NULL;

-- Backfill from existing JSON labels (do not delete services_offered).
INSERT INTO vendor_services (tenant_id, vendor_id, service_key, service_name, status)
SELECT
  v.tenant_id,
  v.id AS vendor_id,
  lower(
    regexp_replace(
      regexp_replace(trim(label), '[^a-zA-Z0-9]+', '_', 'g'),
      '^_+|_+$',
      '',
      'g'
    )
  ) AS service_key,
  trim(label) AS service_name,
  'active' AS status
FROM vendors v
INNER JOIN vendor_profiles vp
  ON vp.vendor_id = v.id AND vp.tenant_id = v.tenant_id
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(vp.services_offered, '[]'::jsonb)) AS label
WHERE nullif(trim(label), '') IS NOT NULL
  AND lower(
    regexp_replace(
      regexp_replace(trim(label), '[^a-zA-Z0-9]+', '_', 'g'),
      '^_+|_+$',
      '',
      'g'
    )
  ) <> ''
  AND lower(
    regexp_replace(
      regexp_replace(trim(label), '[^a-zA-Z0-9]+', '_', 'g'),
      '^_+|_+$',
      '',
      'g'
    )
  ) <> 'general'
ON CONFLICT (vendor_id, service_key) DO NOTHING;

-- Link existing requests to matching vendor_services when possible.
UPDATE vendor_event_requests r
SET vendor_service_id = vs.id
FROM vendor_services vs
WHERE r.vendor_service_id IS NULL
  AND r.vendor_id = vs.vendor_id
  AND r.service_key = vs.service_key
  AND vs.status = 'active';

COMMIT;
