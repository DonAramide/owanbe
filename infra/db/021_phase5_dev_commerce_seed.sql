-- Phase 5.1 dev seed — Lagos Sunset Owanbe event + tiers (mirrors mobile OrganizerEventStore).
-- Uses fixed UUIDs for reproducible local E2E. Safe to re-run (ON CONFLICT).

BEGIN;

-- Dev tenant + buyer user (adjust tenant_id to match your OWANBE_TENANT_ID env)
INSERT INTO tenants (id, slug, name)
VALUES ('11111111-1111-4111-8111-111111111111', 'owanbe-dev', 'Owanbe Dev')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO users (id, tenant_id, email, display_name, status)
VALUES (
  '22222222-2222-4222-8222-222222222222',
  '11111111-1111-4111-8111-111111111111',
  'attendee@owanbe.dev',
  'Dev Attendee',
  'active'
)
ON CONFLICT DO NOTHING;

INSERT INTO organizers (id, tenant_id, owner_user_id, display_name, slug, status)
VALUES (
  '33333333-3333-4333-8333-333333333333',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  'Lagos Events Co',
  'lagos-events-co',
  'active'
)
ON CONFLICT DO NOTHING;

INSERT INTO events (
  id, tenant_id, organizer_id, title, slug, status, starts_at, ends_at, external_ref, metadata
)
VALUES (
  '44444444-4444-4444-8444-444444444444',
  '11111111-1111-4111-8111-111111111111',
  '33333333-3333-4333-8333-333333333333',
  'Lagos Sunset Owanbe',
  'lagos-sunset-owanbe-2026',
  'published',
  '2026-08-15 18:00:00+00',
  '2026-08-15 23:30:00+00',
  'evt_lagos_owanbe_2026',
  '{"city":"Lagos","venue":"Eko Atlantic Waterfront"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  external_ref = EXCLUDED.external_ref,
  metadata = jsonb_build_object('city', 'Lagos', 'venue', 'Eko Atlantic Waterfront'),
  updated_at = now();

INSERT INTO event_ticket_tiers (
  tenant_id, event_id, external_tier_id, name, description, tier_type,
  price_minor, currency, capacity, remaining
)
VALUES
  (
    '11111111-1111-4111-8111-111111111111',
    '44444444-4444-4444-8444-444444444444',
    'tier_ga',
    'General Admission',
    'Standing floor access + vendor village',
    'regular',
    1500000, 'NGN', 1000, 200
  ),
  (
    '11111111-1111-4111-8111-111111111111',
    '44444444-4444-4444-8444-444444444444',
    'tier_vip',
    'VIP Lounge',
    'Reserved lounge, fast lane entry',
    'vip',
    4500000, 'NGN', 150, 30
  ),
  (
    '11111111-1111-4111-8111-111111111111',
    '44444444-4444-4444-8444-444444444444',
    'tier_vvip',
    'VVIP Royal Box',
    'Private box + concierge',
    'vvip',
    12000000, 'NGN', 20, 5
  )
ON CONFLICT (tenant_id, event_id, external_tier_id) DO UPDATE SET
  remaining = EXCLUDED.remaining,
  price_minor = EXCLUDED.price_minor,
  updated_at = now();

-- escrow_release_delay_hours=0 in dev so organizer payout rail is testable immediately after capture
INSERT INTO tenant_finance_settings (tenant_id, escrow_release_delay_hours, ticket_platform_fee_bps, vendor_platform_fee_bps)
VALUES ('11111111-1111-4111-8111-111111111111', 0, 500, 1000)
ON CONFLICT (tenant_id) DO UPDATE SET
  ticket_platform_fee_bps = 500,
  vendor_platform_fee_bps = 1000,
  escrow_release_delay_hours = 0,
  updated_at = now();

COMMIT;
