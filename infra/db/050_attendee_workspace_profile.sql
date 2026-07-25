-- Attendee workspace profile fields (dedicated table only — never users).
-- Additive to attendee_profiles from 046_unified_identity.sql.

BEGIN;

ALTER TABLE attendee_profiles
  ADD COLUMN IF NOT EXISTS preferred_display_name TEXT,
  ADD COLUMN IF NOT EXISTS preferred_event_categories JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS accessibility_requirements TEXT,
  ADD COLUMN IF NOT EXISTS dietary_preferences TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_name TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_relationship TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS notify_email BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_sms BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS notify_push BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS privacy_show_to_organizers BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS privacy_show_to_attendees BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN attendee_profiles.preferred_display_name IS
  'Attendee-workspace preferred display name (independent of users.display_name)';
COMMENT ON COLUMN attendee_profiles.preferred_event_categories IS
  'Attendee preferred event categories JSON array';
COMMENT ON COLUMN attendee_profiles.interests IS
  'Attendee-specific interests JSON array (not users.interests)';

COMMIT;
