-- Vendor onboarding: application lifecycle, business snapshot, bank, portfolio.
-- Application states: applied → under_review → approved | rejected
-- Marketplace vendor.status: use pending_review while in pipeline; active after approval; suspended/rejected as today.

BEGIN;

CREATE TYPE vendor_application_status AS ENUM (
  'applied',
  'under_review',
  'approved',
  'rejected'
);

CREATE TABLE vendor_applications (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id          UUID NOT NULL REFERENCES vendors (id) ON DELETE RESTRICT,
  status             vendor_application_status NOT NULL DEFAULT 'applied',
  submitted_at       TIMESTAMPTZ,
  reviewed_at        TIMESTAMPTZ,
  reviewer_user_id   UUID REFERENCES users (id) ON DELETE SET NULL,
  review_notes       TEXT,
  rejection_reason   TEXT,
  idempotency_key    TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT vendor_applications_idempotency_unique UNIQUE (tenant_id, idempotency_key)
);

CREATE INDEX vendor_applications_vendor_status_idx
  ON vendor_applications (vendor_id, status, created_at DESC);
CREATE INDEX vendor_applications_tenant_queue_idx
  ON vendor_applications (tenant_id, status, submitted_at NULLS LAST);

-- One "open" application per vendor (resubmit = new row after previous terminal rejected).
CREATE UNIQUE INDEX vendor_applications_one_open_per_vendor
  ON vendor_applications (vendor_id)
  WHERE status IN ('applied', 'under_review');

CREATE TABLE vendor_application_business (
  application_id     UUID PRIMARY KEY REFERENCES vendor_applications (id) ON DELETE CASCADE,
  legal_name         TEXT NOT NULL,
  trading_name       TEXT,
  registration_number TEXT,
  tax_id             TEXT,
  business_type      TEXT,
  address_line1      TEXT,
  address_line2      TEXT,
  city               TEXT,
  state_region       TEXT,
  postal_code        TEXT,
  country_code       CHAR(2) NOT NULL,
  phone_e164         TEXT,
  website_url        TEXT,
  metadata           JSONB NOT NULL DEFAULT '{}'::JSONB,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Bank settlement: store tokens/refs from PSP where possible; never raw PAN.
CREATE TABLE vendor_bank_accounts (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id            UUID NOT NULL REFERENCES vendors (id) ON DELETE RESTRICT,
  application_id       UUID REFERENCES vendor_applications (id) ON DELETE SET NULL,
  account_holder_name  TEXT NOT NULL,
  bank_name            TEXT NOT NULL,
  bank_code            TEXT,
  country_code         CHAR(2) NOT NULL,
  currency             CHAR(3) NOT NULL,
  account_number_last4 TEXT NOT NULL,
  psp_recipient_ref    TEXT,
  verification_status  TEXT NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending', 'verified', 'failed')),
  is_default           BOOLEAN NOT NULL DEFAULT TRUE,
  metadata             JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX vendor_bank_accounts_vendor_idx ON vendor_bank_accounts (vendor_id);
CREATE UNIQUE INDEX vendor_bank_accounts_one_default
  ON vendor_bank_accounts (vendor_id)
  WHERE is_default = TRUE;

CREATE TABLE vendor_portfolio_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id       UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
  application_id  UUID REFERENCES vendor_applications (id) ON DELETE SET NULL,
  title           TEXT,
  description     TEXT,
  sort_order      INT NOT NULL DEFAULT 0,
  storage_bucket  TEXT NOT NULL,
  storage_object_key TEXT NOT NULL,
  content_type    TEXT,
  byte_size       BIGINT CHECK (byte_size IS NULL OR byte_size >= 0),
  width           INT,
  height          INT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  retired_at      TIMESTAMPTZ
);

CREATE INDEX vendor_portfolio_vendor_sort_idx
  ON vendor_portfolio_items (vendor_id, sort_order)
  WHERE retired_at IS NULL;

-- Link KYC submissions to a specific application (nullable for legacy rows).
ALTER TABLE vendor_kyc_submissions
  ADD COLUMN IF NOT EXISTS application_id UUID REFERENCES vendor_applications (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS vendor_kyc_submissions_application_idx
  ON vendor_kyc_submissions (application_id);

-- Append-only audit of lifecycle transitions (optional but recommended for admin disputes).
CREATE TABLE vendor_application_events (
  id              BIGSERIAL PRIMARY KEY,
  application_id  UUID NOT NULL REFERENCES vendor_applications (id) ON DELETE RESTRICT,
  actor_user_id   UUID REFERENCES users (id) ON DELETE SET NULL,
  from_status     vendor_application_status,
  to_status       vendor_application_status NOT NULL,
  note            TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX vendor_application_events_app_idx
  ON vendor_application_events (application_id, created_at DESC);

COMMIT;
