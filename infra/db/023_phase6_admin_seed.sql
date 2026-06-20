-- Phase 6 — Dev platform admin user seed
BEGIN;

INSERT INTO users (id, tenant_id, email, display_name, status)
VALUES (
  '77777777-7777-4777-8777-777777777777',
  '11111111-1111-4111-8111-111111111111',
  'admin@owanbe.dev',
  'Platform Admin',
  'active'
)
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT '77777777-7777-4777-8777-777777777777', r.id
FROM roles r
WHERE r.code = 'admin_super'
ON CONFLICT DO NOTHING;

COMMIT;
