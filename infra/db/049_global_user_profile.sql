-- Global User Profile (Hub) — additive fields on users only.
-- Does NOT touch attendee_profiles / organizer_profiles / vendor_profiles.

BEGIN;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS first_name TEXT,
  ADD COLUMN IF NOT EXISTS last_name TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS occupation TEXT,
  ADD COLUMN IF NOT EXISTS company TEXT,
  ADD COLUMN IF NOT EXISTS interests JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS social_links JSONB NOT NULL DEFAULT '{}'::JSONB;

COMMENT ON COLUMN users.first_name IS 'Global profile first name (Hub)';
COMMENT ON COLUMN users.last_name IS 'Global profile last name (Hub)';
COMMENT ON COLUMN users.avatar_url IS 'Global profile avatar public URL (Hub)';
COMMENT ON COLUMN users.bio IS 'Global profile bio (Hub)';
COMMENT ON COLUMN users.occupation IS 'Global profile occupation (Hub)';
COMMENT ON COLUMN users.company IS 'Global profile company (Hub)';
COMMENT ON COLUMN users.interests IS 'Global profile interests array (Hub) — not attendee_profiles.interests';
COMMENT ON COLUMN users.social_links IS 'Global profile social links object (Hub)';

COMMIT;
