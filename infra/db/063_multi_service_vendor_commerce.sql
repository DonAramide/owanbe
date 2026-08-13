-- Phase 63 — Multi-service vendor requests + pricing rules + event fund allocations
-- Preserves existing vendor_event_requests / conversation spine (request id timeline).

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Service-level request identity (same vendor + event, multiple services)
-- ---------------------------------------------------------------------------
ALTER TABLE vendor_event_requests
  ADD COLUMN IF NOT EXISTS service_key TEXT;

UPDATE vendor_event_requests
SET service_key = lower(
  regexp_replace(
    coalesce(nullif(trim(service_label), ''), 'general'),
    '[^a-zA-Z0-9]+',
    '_',
    'g'
  )
)
WHERE service_key IS NULL OR service_key = '';

ALTER TABLE vendor_event_requests
  ALTER COLUMN service_key SET DEFAULT 'general';

ALTER TABLE vendor_event_requests
  ALTER COLUMN service_key SET NOT NULL;

-- Dual commercial amounts (party-scoped; margin never returned to clients)
ALTER TABLE vendor_event_requests
  ADD COLUMN IF NOT EXISTS vendor_payout_minor BIGINT,
  ADD COLUMN IF NOT EXISTS customer_price_minor BIGINT,
  ADD COLUMN IF NOT EXISTS platform_margin_minor BIGINT,
  ADD COLUMN IF NOT EXISTS agreement_confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS completion_requested_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS completion_confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS funding_status TEXT NOT NULL DEFAULT 'unfunded'
    CHECK (funding_status IN ('unfunded', 'reserved', 'funded', 'released', 'held', 'insufficient'));

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'vendor_event_requests_event_id_vendor_id_key'
  ) THEN
    ALTER TABLE vendor_event_requests
      DROP CONSTRAINT vendor_event_requests_event_id_vendor_id_key;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'vendor_event_requests_event_vendor_service_key'
  ) THEN
    ALTER TABLE vendor_event_requests
      ADD CONSTRAINT vendor_event_requests_event_vendor_service_key
      UNIQUE (event_id, vendor_id, service_key);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS vendor_event_requests_service_key_idx
  ON vendor_event_requests (tenant_id, service_key, stage);

-- ---------------------------------------------------------------------------
-- 2) Configurable Owanbe markup (default 40% = 4000 bps). Service-specific optional.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS platform_vendor_pricing_rules (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  service_key     TEXT,
  markup_bps      INTEGER NOT NULL DEFAULT 4000
    CHECK (markup_bps >= 0 AND markup_bps <= 9000),
  is_default      BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS platform_vendor_pricing_rules_default_uidx
  ON platform_vendor_pricing_rules (tenant_id)
  WHERE is_default = true;

CREATE UNIQUE INDEX IF NOT EXISTS platform_vendor_pricing_rules_service_uidx
  ON platform_vendor_pricing_rules (tenant_id, service_key)
  WHERE service_key IS NOT NULL;

INSERT INTO platform_vendor_pricing_rules (tenant_id, service_key, markup_bps, is_default)
SELECT t.id, NULL, 4000, true
FROM tenants t
WHERE NOT EXISTS (
  SELECT 1 FROM platform_vendor_pricing_rules r
  WHERE r.tenant_id = t.id AND r.is_default = true
);

-- ---------------------------------------------------------------------------
-- 3) Event funds + per-request allocations (reuse wallet concepts; no parallel wallet)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS event_vendor_funds (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id            UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  currency            TEXT NOT NULL DEFAULT 'NGN',
  total_funded_minor  BIGINT NOT NULL DEFAULT 0 CHECK (total_funded_minor >= 0),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (event_id)
);

CREATE TABLE IF NOT EXISTS vendor_request_fund_allocations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id        UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  request_id      UUID NOT NULL REFERENCES vendor_event_requests (id) ON DELETE CASCADE,
  amount_minor    BIGINT NOT NULL CHECK (amount_minor > 0),
  status          TEXT NOT NULL DEFAULT 'reserved'
    CHECK (status IN ('reserved', 'funded', 'released', 'held', 'cancelled')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (request_id)
);

CREATE INDEX IF NOT EXISTS vendor_request_fund_allocations_event_idx
  ON vendor_request_fund_allocations (tenant_id, event_id, status);

COMMIT;
