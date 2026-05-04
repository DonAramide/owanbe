-- Owanbe core schema (PostgreSQL 14+)
-- Production-oriented: multi-tenant hooks, strong FKs, immutable ledger, indexing.
-- Apply with a migration runner (Flyway/Liquibase/sqitch) in production.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- Enumerations
-- ---------------------------------------------------------------------------

CREATE TYPE user_status AS ENUM ('pending', 'active', 'suspended', 'deleted');
CREATE TYPE vendor_status AS ENUM ('draft', 'pending_review', 'active', 'suspended', 'rejected');
CREATE TYPE kyc_submission_status AS ENUM ('draft', 'submitted', 'in_review', 'approved', 'rejected', 'changes_requested');
CREATE TYPE kyc_document_kind AS ENUM ('identity', 'business_registration', 'proof_of_address', 'bank_statement', 'other');
CREATE TYPE package_billing_unit AS ENUM ('per_guest', 'fixed', 'hourly', 'custom_quote');
CREATE TYPE booking_status AS ENUM (
  'draft',
  'pending_payment',
  'confirmed',
  'in_progress',
  'completed',
  'cancelled',
  'refunded',
  'disputed'
);
CREATE TYPE payment_provider AS ENUM ('paystack', 'flutterwave', 'internal');
CREATE TYPE payment_status AS ENUM (
  'initiated',
  'requires_action',
  'authorized',
  'captured',
  'partially_refunded',
  'refunded',
  'voided',
  'failed'
);
CREATE TYPE ledger_account_kind AS ENUM (
  'platform_clearing',
  'platform_fees',
  'client_wallet',
  'vendor_payable',
  'escrow',
  'external_psp',
  'adjustment'
);
CREATE TYPE ledger_line_direction AS ENUM ('debit', 'credit');
CREATE TYPE notification_channel AS ENUM ('email', 'sms', 'push', 'in_app');
CREATE TYPE notification_status AS ENUM ('queued', 'sent', 'delivered', 'failed', 'read');

-- ---------------------------------------------------------------------------
-- Multi-tenant root
-- ---------------------------------------------------------------------------

CREATE TABLE tenants (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  metadata    JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX tenants_status_idx ON tenants (status);

-- ---------------------------------------------------------------------------
-- Identity: users + roles (M:N). Roles can be extended without schema churn.
-- ---------------------------------------------------------------------------

CREATE TABLE roles (
  id          SMALLSERIAL PRIMARY KEY,
  code        TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL DEFAULT ''
);

INSERT INTO roles (code, description) VALUES
  ('admin', 'Platform operator'),
  ('client', 'Event host / payer'),
  ('vendor', 'Service provider'),
  ('guest', 'Invite-scoped or lightweight attendee')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  email           TEXT NOT NULL,
  email_normalized TEXT GENERATED ALWAYS AS (lower(trim(email))) STORED,
  phone_e164      TEXT,
  display_name    TEXT,
  status          user_status NOT NULL DEFAULT 'pending',
  password_hash   TEXT,
  last_login_at   TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT users_email_unique_per_tenant UNIQUE (tenant_id, email_normalized)
);

CREATE INDEX users_tenant_status_idx ON users (tenant_id, status);
CREATE INDEX users_email_normalized_idx ON users (email_normalized);

CREATE TABLE user_roles (
  user_id    UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  role_id    SMALLINT NOT NULL REFERENCES roles (id) ON DELETE RESTRICT,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  granted_by UUID REFERENCES users (id) ON DELETE SET NULL,
  PRIMARY KEY (user_id, role_id)
);

CREATE INDEX user_roles_role_idx ON user_roles (role_id);

-- ---------------------------------------------------------------------------
-- Vendors (business profile) — owned by a user; future staff via vendor_users.
-- ---------------------------------------------------------------------------

CREATE TABLE vendors (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  owner_user_id    UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  business_name    TEXT NOT NULL,
  slug             TEXT NOT NULL,
  status           vendor_status NOT NULL DEFAULT 'draft',
  description      TEXT,
  country_code     CHAR(2) NOT NULL,
  city             TEXT,
  verified_at      TIMESTAMPTZ,
  suspended_reason TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT vendors_slug_unique_per_tenant UNIQUE (tenant_id, slug)
);

CREATE INDEX vendors_tenant_status_idx ON vendors (tenant_id, status);
CREATE INDEX vendors_owner_idx ON vendors (owner_user_id);

-- Optional: vendor team members (not required for MVP integrity)
CREATE TABLE vendor_users (
  vendor_id  UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  title      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (vendor_id, user_id)
);

CREATE INDEX vendor_users_user_idx ON vendor_users (user_id);

-- ---------------------------------------------------------------------------
-- KYC / verification (append-friendly submissions + document metadata)
-- ---------------------------------------------------------------------------

CREATE TABLE vendor_kyc_submissions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id      UUID NOT NULL REFERENCES vendors (id) ON DELETE RESTRICT,
  status         kyc_submission_status NOT NULL DEFAULT 'draft',
  submitted_at   TIMESTAMPTZ,
  reviewed_at    TIMESTAMPTZ,
  reviewer_user_id UUID REFERENCES users (id) ON DELETE SET NULL,
  review_notes   TEXT,
  provider_reference TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX vendor_kyc_vendor_status_idx ON vendor_kyc_submissions (vendor_id, status, created_at DESC);

CREATE TABLE vendor_kyc_documents (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id UUID NOT NULL REFERENCES vendor_kyc_submissions (id) ON DELETE RESTRICT,
  kind          kyc_document_kind NOT NULL,
  storage_bucket TEXT NOT NULL,
  storage_object_key TEXT NOT NULL,
  content_type  TEXT,
  byte_size     BIGINT CHECK (byte_size IS NULL OR byte_size >= 0),
  sha256_hex    TEXT,
  uploaded_by   UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- No hard DELETE in production apps: revoke access via lifecycle; keep row for audit.
  retired_at    TIMESTAMPTZ
);

CREATE INDEX vendor_kyc_documents_submission_idx ON vendor_kyc_documents (submission_id);

-- ---------------------------------------------------------------------------
-- Packages (vendor pricing tiers)
-- ---------------------------------------------------------------------------

CREATE TABLE vendor_packages (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  vendor_id      UUID NOT NULL REFERENCES vendors (id) ON DELETE RESTRICT,
  code           TEXT NOT NULL,
  name           TEXT NOT NULL,
  description    TEXT,
  billing_unit   package_billing_unit NOT NULL,
  currency       CHAR(3) NOT NULL,
  unit_amount_minor BIGINT NOT NULL CHECK (unit_amount_minor >= 0),
  min_guests     INT CHECK (min_guests IS NULL OR min_guests >= 0),
  max_guests     INT CHECK (max_guests IS NULL OR max_guests >= 0),
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order     INT NOT NULL DEFAULT 0,
  metadata       JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT vendor_packages_code_unique UNIQUE (vendor_id, code),
  CONSTRAINT vendor_packages_guest_range_ok CHECK (
    min_guests IS NULL OR max_guests IS NULL OR max_guests >= min_guests
  )
);

CREATE INDEX vendor_packages_vendor_active_idx ON vendor_packages (vendor_id, is_active, sort_order);

-- ---------------------------------------------------------------------------
-- Bookings (commercial aggregate)
-- ---------------------------------------------------------------------------

CREATE TABLE bookings (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  client_user_id       UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  vendor_id            UUID NOT NULL REFERENCES vendors (id) ON DELETE RESTRICT,
  package_id           UUID NOT NULL REFERENCES vendor_packages (id) ON DELETE RESTRICT,
  status               booking_status NOT NULL DEFAULT 'draft',
  currency             CHAR(3) NOT NULL,
  guest_count          INT NOT NULL CHECK (guest_count > 0),
  event_starts_at      TIMESTAMPTZ NOT NULL,
  event_ends_at        TIMESTAMPTZ,
  location_text        TEXT,
  -- Optional coordinates without PostGIS; migrate to GEOGRAPHY later if needed.
  location_latitude    DOUBLE PRECISION CHECK (location_latitude IS NULL OR (location_latitude >= -90 AND location_latitude <= 90)),
  location_longitude   DOUBLE PRECISION CHECK (location_longitude IS NULL OR (location_longitude >= -180 AND location_longitude <= 180)),
  client_notes         TEXT,
  pricing_snapshot     JSONB NOT NULL,
  subtotal_minor       BIGINT NOT NULL CHECK (subtotal_minor >= 0),
  platform_fee_minor   BIGINT NOT NULL DEFAULT 0 CHECK (platform_fee_minor >= 0),
  total_minor          BIGINT NOT NULL CHECK (total_minor >= 0),
  version              INT NOT NULL DEFAULT 1 CHECK (version >= 1),
  idempotency_key      TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT bookings_idempotency_unique UNIQUE (tenant_id, idempotency_key),
  CONSTRAINT bookings_time_order_ok CHECK (event_ends_at IS NULL OR event_ends_at >= event_starts_at)
);

CREATE INDEX bookings_client_status_idx ON bookings (client_user_id, status, event_starts_at DESC);
CREATE INDEX bookings_vendor_status_idx ON bookings (vendor_id, status, event_starts_at DESC);
CREATE INDEX bookings_tenant_created_idx ON bookings (tenant_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Payments (PSP orchestration; rows are lifecycle-updated, never deleted)
-- ---------------------------------------------------------------------------

CREATE TABLE payments (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  booking_id           UUID NOT NULL REFERENCES bookings (id) ON DELETE RESTRICT,
  provider             payment_provider NOT NULL,
  provider_customer_ref TEXT,
  provider_intent_ref   TEXT,
  provider_charge_ref   TEXT,
  status               payment_status NOT NULL DEFAULT 'initiated',
  currency             CHAR(3) NOT NULL,
  amount_authorized_minor BIGINT CHECK (amount_authorized_minor IS NULL OR amount_authorized_minor >= 0),
  amount_captured_minor   BIGINT NOT NULL DEFAULT 0 CHECK (amount_captured_minor >= 0),
  amount_refunded_minor   BIGINT NOT NULL DEFAULT 0 CHECK (amount_refunded_minor >= 0),
  idempotency_key      TEXT,
  raw_event_ids        TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  metadata             JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT payments_idempotency_unique UNIQUE (tenant_id, idempotency_key),
  CONSTRAINT payments_refund_lte_capture CHECK (amount_refunded_minor <= amount_captured_minor)
);

CREATE INDEX payments_booking_idx ON payments (booking_id, created_at DESC);
CREATE INDEX payments_provider_intent_idx ON payments (provider, provider_intent_ref);
CREATE INDEX payments_provider_charge_idx ON payments (provider, provider_charge_ref);
CREATE INDEX payments_status_idx ON payments (tenant_id, status);

CREATE OR REPLACE FUNCTION owanbe_forbid_payments_delete()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'payments rows must not be deleted (void/refund via status + ledger reversal)';
END;
$$;

CREATE TRIGGER payments_forbid_delete
BEFORE DELETE ON payments
FOR EACH ROW EXECUTE PROCEDURE owanbe_forbid_payments_delete();

-- Immutable audit of provider webhooks / async events (append-only)
CREATE TABLE payment_events (
  id            BIGSERIAL PRIMARY KEY,
  payment_id    UUID NOT NULL REFERENCES payments (id) ON DELETE RESTRICT,
  tenant_id     UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  provider      payment_provider NOT NULL,
  event_id      TEXT,
  event_type    TEXT NOT NULL,
  payload       JSONB NOT NULL,
  received_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT payment_events_dedupe UNIQUE (provider, event_id)
);

CREATE INDEX payment_events_payment_idx ON payment_events (payment_id, received_at DESC);

-- ---------------------------------------------------------------------------
-- Ledger (double-entry; logical lines are immutable; reversals via new txn)
-- ---------------------------------------------------------------------------

CREATE TABLE ledger_accounts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  kind         ledger_account_kind NOT NULL,
  currency     CHAR(3) NOT NULL,
  user_id      UUID REFERENCES users (id) ON DELETE RESTRICT,
  vendor_id    UUID REFERENCES vendors (id) ON DELETE RESTRICT,
  code         TEXT NOT NULL,
  metadata     JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ledger_accounts_owner_shape_chk CHECK (
    (kind IN ('vendor_payable') AND vendor_id IS NOT NULL)
    OR (kind IN ('client_wallet') AND user_id IS NOT NULL)
    OR (kind NOT IN ('vendor_payable', 'client_wallet'))
  ),
  CONSTRAINT ledger_accounts_code_unique UNIQUE (tenant_id, currency, code)
);

CREATE INDEX ledger_accounts_tenant_kind_idx ON ledger_accounts (tenant_id, kind);

CREATE TABLE ledger_transactions (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  booking_id           UUID REFERENCES bookings (id) ON DELETE RESTRICT,
  payment_id           UUID REFERENCES payments (id) ON DELETE RESTRICT,
  idempotency_key      TEXT,
  reason               TEXT NOT NULL,
  reversal_of_id       UUID REFERENCES ledger_transactions (id) ON DELETE RESTRICT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ledger_txn_idempotency_unique UNIQUE (tenant_id, idempotency_key),
  CONSTRAINT ledger_txn_reversal_cycle_chk CHECK (reversal_of_id IS DISTINCT FROM id)
);

CREATE INDEX ledger_transactions_booking_idx ON ledger_transactions (booking_id, created_at DESC);
CREATE INDEX ledger_transactions_payment_idx ON ledger_transactions (payment_id, created_at DESC);

CREATE OR REPLACE FUNCTION owanbe_forbid_ledger_transaction_delete()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'ledger_transactions must not be deleted (reversal = new transaction)';
END;
$$;

CREATE TRIGGER ledger_transactions_forbid_delete
BEFORE DELETE ON ledger_transactions
FOR EACH ROW EXECUTE PROCEDURE owanbe_forbid_ledger_transaction_delete();

CREATE TABLE ledger_lines (
  id             BIGSERIAL PRIMARY KEY,
  transaction_id UUID NOT NULL REFERENCES ledger_transactions (id) ON DELETE RESTRICT,
  account_id     UUID NOT NULL REFERENCES ledger_accounts (id) ON DELETE RESTRICT,
  direction      ledger_line_direction NOT NULL,
  amount_minor   BIGINT NOT NULL CHECK (amount_minor > 0),
  currency       CHAR(3) NOT NULL,
  memo           TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ledger_lines_currency_consistency_chk CHECK (char_length(currency) = 3)
);

CREATE INDEX ledger_lines_account_created_idx ON ledger_lines (account_id, created_at DESC);
CREATE INDEX ledger_lines_txn_idx ON ledger_lines (transaction_id);

-- Prevent UPDATE/DELETE on financial audit tables (reversal = new rows)
CREATE OR REPLACE FUNCTION owanbe_forbid_ledger_line_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'ledger_lines are immutable (use reversal transactions)';
  RETURN NULL;
END;
$$;

CREATE TRIGGER ledger_lines_forbid_update
BEFORE UPDATE ON ledger_lines
FOR EACH ROW EXECUTE PROCEDURE owanbe_forbid_ledger_line_mutation();

CREATE TRIGGER ledger_lines_forbid_delete
BEFORE DELETE ON ledger_lines
FOR EACH ROW EXECUTE PROCEDURE owanbe_forbid_ledger_line_mutation();

CREATE OR REPLACE FUNCTION owanbe_forbid_payment_event_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'payment_events are append-only';
  RETURN NULL;
END;
$$;

CREATE TRIGGER payment_events_forbid_update
BEFORE UPDATE ON payment_events
FOR EACH ROW EXECUTE PROCEDURE owanbe_forbid_payment_event_mutation();

CREATE TRIGGER payment_events_forbid_delete
BEFORE DELETE ON payment_events
FOR EACH ROW EXECUTE PROCEDURE owanbe_forbid_payment_event_mutation();

-- Optional: DB-enforced balanced transactions (debits = credits) via constraint trigger
CREATE OR REPLACE FUNCTION owanbe_ledger_transaction_balance_chk()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
  tid UUID;
  debit_sum BIGINT;
  credit_sum BIGINT;
BEGIN
  IF TG_OP = 'DELETE' THEN
    tid := OLD.transaction_id;
  ELSE
    tid := NEW.transaction_id;
  END IF;

  SELECT COALESCE(SUM(amount_minor), 0) INTO debit_sum
  FROM ledger_lines WHERE transaction_id = tid AND direction = 'debit';

  SELECT COALESCE(SUM(amount_minor), 0) INTO credit_sum
  FROM ledger_lines WHERE transaction_id = tid AND direction = 'credit';

  IF debit_sum <> credit_sum THEN
    RAISE EXCEPTION 'ledger transaction % is not balanced (debit % vs credit %)', tid, debit_sum, credit_sum;
  END IF;

  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER ledger_lines_balance_after_insert
AFTER INSERT ON ledger_lines
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE PROCEDURE owanbe_ledger_transaction_balance_chk();

-- ---------------------------------------------------------------------------
-- Chat (threads bound to commercial context; messages append-only)
-- ---------------------------------------------------------------------------

CREATE TABLE chat_threads (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  booking_id  UUID REFERENCES bookings (id) ON DELETE RESTRICT,
  subject     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chat_threads_booking_unique UNIQUE (booking_id)
);

CREATE INDEX chat_threads_tenant_created_idx ON chat_threads (tenant_id, created_at DESC);

CREATE TABLE chat_participants (
  thread_id UUID NOT NULL REFERENCES chat_threads (id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  role      TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'vendor_staff', 'system')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (thread_id, user_id)
);

CREATE INDEX chat_participants_user_idx ON chat_participants (user_id);

CREATE TABLE chat_messages (
  id          BIGSERIAL PRIMARY KEY,
  thread_id   UUID NOT NULL REFERENCES chat_threads (id) ON DELETE RESTRICT,
  sender_id   UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  body        TEXT NOT NULL,
  attachments JSONB NOT NULL DEFAULT '[]'::JSONB,
  client_msg_id TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chat_messages_dedupe UNIQUE (thread_id, client_msg_id)
);

CREATE INDEX chat_messages_thread_created_idx ON chat_messages (thread_id, created_at DESC);

CREATE OR REPLACE FUNCTION owanbe_forbid_chat_message_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'chat_messages are append-only (use compensating messages or tombstone pattern elsewhere if needed)';
  RETURN NULL;
END;
$$;

CREATE TRIGGER chat_messages_forbid_update
BEFORE UPDATE ON chat_messages
FOR EACH ROW EXECUTE PROCEDURE owanbe_forbid_chat_message_mutation();

CREATE TRIGGER chat_messages_forbid_delete
BEFORE DELETE ON chat_messages
FOR EACH ROW EXECUTE PROCEDURE owanbe_forbid_chat_message_mutation();

-- ---------------------------------------------------------------------------
-- Notifications (durable user inbox + delivery audit)
-- ---------------------------------------------------------------------------

CREATE TABLE notifications (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  user_id       UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  channel       notification_channel NOT NULL,
  status        notification_status NOT NULL DEFAULT 'queued',
  kind          TEXT NOT NULL,
  title         TEXT,
  body          TEXT,
  data          JSONB NOT NULL DEFAULT '{}'::JSONB,
  dedupe_key    TEXT,
  sent_at       TIMESTAMPTZ,
  delivered_at  TIMESTAMPTZ,
  read_at       TIMESTAMPTZ,
  error         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT notifications_dedupe_unique UNIQUE (tenant_id, user_id, dedupe_key)
);

CREATE INDEX notifications_user_unread_idx
  ON notifications (user_id, created_at DESC)
  WHERE read_at IS NULL;

CREATE INDEX notifications_user_kind_idx ON notifications (user_id, kind, created_at DESC);

COMMIT;
