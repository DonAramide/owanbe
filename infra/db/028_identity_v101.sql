-- Identity & Account Experience v1.0.1
-- Guest ticket discovery + linking before / after account creation.
-- Apply after 027_phase_event_v2.sql (or latest commerce migration).

BEGIN;

-- Allow entitlements issued to a guest contact before the holder account exists.
ALTER TABLE ticket_entitlements
  ALTER COLUMN holder_user_id DROP NOT NULL;

ALTER TABLE ticket_entitlements
  ADD COLUMN IF NOT EXISTS guest_email TEXT,
  ADD COLUMN IF NOT EXISTS guest_phone_e164 TEXT,
  ADD COLUMN IF NOT EXISTS linked_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS ticket_entitlements_guest_email_idx
  ON ticket_entitlements (tenant_id, lower(guest_email))
  WHERE guest_email IS NOT NULL;

CREATE INDEX IF NOT EXISTS ticket_entitlements_guest_phone_idx
  ON ticket_entitlements (tenant_id, guest_phone_e164)
  WHERE guest_phone_e164 IS NOT NULL;

COMMENT ON COLUMN ticket_entitlements.guest_email IS
  'Pre-registration invitation email; linked to holder_user_id after attendee signup.';
COMMENT ON COLUMN ticket_entitlements.guest_phone_e164 IS
  'Pre-registration invitation phone (E.164); linked after phone verification.';

-- Organizer profile completion (post email/phone verify).
CREATE TABLE IF NOT EXISTS organizer_profiles (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  user_id         UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  organizer_id    UUID REFERENCES organizers (id) ON DELETE SET NULL,
  display_name    TEXT NOT NULL DEFAULT '',
  organization_name TEXT NOT NULL DEFAULT '',
  phone_e164      TEXT,
  email_verified_at TIMESTAMPTZ,
  phone_verified_at TIMESTAMPTZ,
  onboarding_step TEXT NOT NULL DEFAULT 'profile',
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT organizer_profiles_user_unique UNIQUE (tenant_id, user_id)
);

CREATE INDEX IF NOT EXISTS organizer_profiles_organizer_idx
  ON organizer_profiles (organizer_id);

COMMIT;
