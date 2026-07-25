-- Vendor workspace profile fields (dedicated vendor_profiles only — never users /
-- attendee_profiles / organizer_profiles).
-- Additive to vendor_profiles from 046_unified_identity.sql.

BEGIN;

ALTER TABLE vendor_profiles
  ADD COLUMN IF NOT EXISTS subcategory TEXT,
  ADD COLUMN IF NOT EXISTS years_of_experience INT,
  ADD COLUMN IF NOT EXISTS services_offered JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS service_areas JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS portfolio_images JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS portfolio_videos JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS portfolio_website TEXT,
  ADD COLUMN IF NOT EXISTS starting_price TEXT,
  ADD COLUMN IF NOT EXISTS price_range TEXT,
  ADD COLUMN IF NOT EXISTS team_size INT,
  ADD COLUMN IF NOT EXISTS max_event_capacity INT,
  ADD COLUMN IF NOT EXISTS available_for_bookings BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS advance_booking_notice TEXT,
  ADD COLUMN IF NOT EXISTS business_address TEXT,
  ADD COLUMN IF NOT EXISTS contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS contact_email TEXT,
  ADD COLUMN IF NOT EXISTS verification_documents JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS business_registration_number TEXT,
  ADD COLUMN IF NOT EXISTS tax_id TEXT,
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT;

COMMENT ON COLUMN vendor_profiles.business_name IS
  'Vendor workspace business name (independent of users.display_name)';
COMMENT ON COLUMN vendor_profiles.category IS
  'Primary vendor category';
COMMENT ON COLUMN vendor_profiles.subcategory IS
  'Vendor subcategory within category';
COMMENT ON COLUMN vendor_profiles.bio IS
  'Business description / about text for vendor workspace';
COMMENT ON COLUMN vendor_profiles.services_offered IS
  'JSON array of service labels offered';
COMMENT ON COLUMN vendor_profiles.service_areas IS
  'JSON array of geographic service areas';
COMMENT ON COLUMN vendor_profiles.portfolio_images IS
  'JSON array of portfolio image URLs';
COMMENT ON COLUMN vendor_profiles.portfolio_videos IS
  'JSON array of portfolio video URLs';
COMMENT ON COLUMN vendor_profiles.verification_documents IS
  'JSON array of {url, name?, uploadedAt?} document refs';

COMMIT;
