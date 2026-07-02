-- v1.0.1 identity dev seed — Postgres users, roles, sample guest ticket invitation.
-- Run after 021_phase5_dev_commerce_seed.sql and 028_identity_v101.sql

BEGIN;

-- Remove stale dev rows that block canonical v1.0.1 account IDs/emails.
DELETE FROM users
WHERE tenant_id = '11111111-1111-4111-8111-111111111111'
  AND email IN ('organizer@owanbe.dev', 'vendor@owanbe.dev', 'attendee@owanbe.dev')
  AND id NOT IN (
    '22222222-2222-4222-8222-222222222222',
    '33333333-3333-4333-8333-333333333331',
    '55555555-5555-4555-8555-555555555555',
    '77777777-7777-4777-8777-777777777777',
    '88888888-8888-4888-8888-888888888888'
  );

INSERT INTO tenants (id, slug, name)
VALUES ('11111111-1111-4111-8111-111111111111', 'owanbe-dev', 'Owanbe Dev')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO users (id, tenant_id, email, display_name, phone_e164, status)
VALUES
  ('22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111', 'attendee@owanbe.dev', 'Ada Attendee', '+2348010000001', 'active'),
  ('33333333-3333-4333-8333-333333333331', '11111111-1111-4111-8111-111111111111', 'organizer@owanbe.dev', 'Lagos Events Co', '+2348010000002', 'active'),
  ('55555555-5555-4555-8555-555555555555', '11111111-1111-4111-8111-111111111111', 'vendor@owanbe.dev', 'Golden Pot Catering', '+2348010000003', 'active'),
  ('77777777-7777-4777-8777-777777777777', '11111111-1111-4111-8111-111111111111', 'admin@owanbe.dev', 'Platform Admin', NULL, 'active'),
  ('88888888-8888-4888-8888-888888888888', '11111111-1111-4111-8111-111111111111', 'superadmin@owanbe.dev', 'Owanbe Control Tower', NULL, 'active')
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  display_name = EXCLUDED.display_name,
  phone_e164 = EXCLUDED.phone_e164,
  status = 'active';

INSERT INTO organizers (id, tenant_id, owner_user_id, display_name, slug, status)
VALUES (
  '33333333-3333-4333-8333-333333333333',
  '11111111-1111-4111-8111-111111111111',
  '33333333-3333-4333-8333-333333333331',
  'Lagos Events Co',
  'lagos-events-co',
  'active'
)
ON CONFLICT (id) DO UPDATE SET owner_user_id = EXCLUDED.owner_user_id;

INSERT INTO organizer_profiles (tenant_id, user_id, organizer_id, display_name, organization_name, phone_e164, onboarding_step)
VALUES (
  '11111111-1111-4111-8111-111111111111',
  '33333333-3333-4333-8333-333333333331',
  '33333333-3333-4333-8333-333333333333',
  'Lagos Events Co',
  'Lagos Events Co',
  '+2348010000002',
  'complete'
)
ON CONFLICT (tenant_id, user_id) DO UPDATE SET onboarding_step = 'complete';

INSERT INTO vendors (id, tenant_id, owner_user_id, business_name, slug, status, country_code, city)
VALUES (
  '55555555-5555-4555-8555-555555555555',
  '11111111-1111-4111-8111-111111111111',
  '55555555-5555-4555-8555-555555555555',
  'Golden Pot Catering',
  'golden-pot-catering',
  'active',
  'NG',
  'Lagos'
)
ON CONFLICT (id) DO UPDATE SET owner_user_id = EXCLUDED.owner_user_id, status = 'active';

-- Linked ticket for seeded attendee account
INSERT INTO ticket_entitlements (
  id, tenant_id, ticket_order_id, ticket_order_line_id, event_id,
  holder_user_id, ticket_code, status, metadata
)
SELECT
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  '11111111-1111-4111-8111-111111111111',
  o.id,
  l.id,
  '44444444-4444-4444-8444-444444444444',
  '22222222-2222-4222-8222-222222222222',
  'OWANBE-ATTENDEE-DEMO-01',
  'issued',
  '{"tier_name":"VIP","qr_payload":"OWANBE-ATTENDEE-DEMO-01"}'::jsonb
FROM ticket_orders o
INNER JOIN ticket_order_lines l ON l.ticket_order_id = o.id
WHERE o.event_id = '44444444-4444-4444-8444-444444444444'
LIMIT 1
ON CONFLICT (id) DO UPDATE SET holder_user_id = EXCLUDED.holder_user_id;

-- Guest invitation awaiting account link (discovery flow demo)
INSERT INTO ticket_entitlements (
  id, tenant_id, ticket_order_id, ticket_order_line_id, event_id,
  holder_user_id, guest_email, guest_phone_e164, ticket_code, status, metadata
)
SELECT
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  o.id,
  l.id,
  '44444444-4444-4444-8444-444444444444',
  NULL,
  'newguest@owanbe.dev',
  '+2348099999999',
  'OWANBE-GUEST-DEMO-01',
  'issued',
  '{"tier_name":"General Admission","qr_payload":"OWANBE-GUEST-DEMO-01"}'::jsonb
FROM ticket_orders o
INNER JOIN ticket_order_lines l ON l.ticket_order_id = o.id
WHERE o.event_id = '44444444-4444-4444-8444-444444444444'
LIMIT 1
ON CONFLICT (id) DO UPDATE SET
  guest_email = EXCLUDED.guest_email,
  guest_phone_e164 = EXCLUDED.guest_phone_e164,
  holder_user_id = NULL;

COMMIT;
