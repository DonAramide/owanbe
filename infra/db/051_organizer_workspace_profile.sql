-- Organizer workspace profile fields (dedicated organizer_profiles only — never users /
-- attendee_profiles / vendor_profiles).
-- Additive to organizer_profiles from 028_identity_v101.sql / 046_unified_identity.sql.
-- Multi-jurisdiction registration: authority is free text (not CAC-only).

BEGIN;

ALTER TABLE organizer_profiles
  ADD COLUMN IF NOT EXISTS business_type TEXT,
  ADD COLUMN IF NOT EXISTS years_of_experience INT,
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS support_email TEXT,
  ADD COLUMN IF NOT EXISTS support_phone TEXT,
  ADD COLUMN IF NOT EXISTS website TEXT,
  ADD COLUMN IF NOT EXISTS social_links JSONB NOT NULL DEFAULT '{}'::JSONB,
  ADD COLUMN IF NOT EXISTS business_address TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS state TEXT,
  ADD COLUMN IF NOT EXISTS country TEXT,
  ADD COLUMN IF NOT EXISTS registration_number TEXT,
  ADD COLUMN IF NOT EXISTS registration_authority TEXT,
  ADD COLUMN IF NOT EXISTS registration_country TEXT,
  ADD COLUMN IF NOT EXISTS tax_id TEXT,
  ADD COLUMN IF NOT EXISTS tax_authority TEXT,
  ADD COLUMN IF NOT EXISTS verification_status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS verification_documents JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT;

COMMENT ON COLUMN organizer_profiles.display_name IS
  'Organizer workspace display / organizer name (independent of users.display_name for workspace edits)';
COMMENT ON COLUMN organizer_profiles.organization_name IS
  'Business / organization name for organizer workspace';
COMMENT ON COLUMN organizer_profiles.business_type IS
  'Business type e.g. Individual Organizer, Event Company, Non-Profit, …';
COMMENT ON COLUMN organizer_profiles.registration_authority IS
  'Local registration authority name (multi-jurisdiction; not hard-coded to CAC)';
COMMENT ON COLUMN organizer_profiles.registration_country IS
  'Country of business registration';
COMMENT ON COLUMN organizer_profiles.verification_status IS
  'Extensible status: pending | submitted | verified | rejected (no workflow in this migration)';
COMMENT ON COLUMN organizer_profiles.verification_documents IS
  'JSON array of {url, name?, uploadedAt?} document refs';
COMMENT ON COLUMN organizer_profiles.logo_url IS
  'Organizer logo public media URL';
COMMENT ON COLUMN organizer_profiles.cover_image_url IS
  'Organizer cover image public media URL';

COMMIT;
