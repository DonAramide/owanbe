#!/usr/bin/env node
/**
 * Backfill Owanbe 2.0 workspace state for existing users.
 * - Ensures signup_portal_deprecated is set from existing roles
 * - Creates profile stub rows for activated workspaces
 */
const { Client } = require('../services/api/node_modules/pg');

const DATABASE_URL =
  process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5436/owanbe';

function portalFromRoles(roles) {
  if (roles.some((r) => r.startsWith('admin') || r === 'platform_admin' || r === 'super_admin')) {
    return 'admin';
  }
  if (roles.includes('organizer')) return 'organizer';
  if (roles.includes('vendor') || roles.includes('vendor_pending')) return 'vendor';
  if (roles.includes('client')) return 'client';
  return null;
}

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  console.log('Connected:', DATABASE_URL);

  const { rows: users } = await pg.query(`
    SELECT u.id, u.tenant_id, u.signup_portal_deprecated, u.onboarding_complete,
      COALESCE(array_agg(r.code) FILTER (WHERE r.code IS NOT NULL), '{}') AS roles
    FROM users u
    LEFT JOIN user_roles ur ON ur.user_id = u.id
    LEFT JOIN roles r ON r.id = ur.role_id
    GROUP BY u.id, u.tenant_id, u.signup_portal_deprecated, u.onboarding_complete
  `);

  let updated = 0;
  for (const user of users) {
    const roles = user.roles || [];
    const portal = user.signup_portal_deprecated || portalFromRoles(roles);
    if (!portal) continue;

    if (!user.signup_portal_deprecated) {
      await pg.query(
        `UPDATE users SET signup_portal_deprecated = $2, last_active_workspace = COALESCE(last_active_workspace, $2) WHERE id = $1`,
        [user.id, portal],
      );
      updated++;
    }

    if (roles.includes('client') && user.onboarding_complete) {
      await pg.query(
        `INSERT INTO attendee_profiles (tenant_id, user_id, onboarding_step, activated_at)
         VALUES ($1, $2, 'complete', now())
         ON CONFLICT (tenant_id, user_id) DO NOTHING`,
        [user.tenant_id, user.id],
      );
    }

    if (roles.includes('organizer')) {
      await pg.query(
        `INSERT INTO organizer_profiles (tenant_id, user_id, display_name, onboarding_step, activated_at)
         VALUES ($1, $2, 'Organizer', 'profile', now())
         ON CONFLICT (tenant_id, user_id) DO NOTHING`,
        [user.tenant_id, user.id],
      );
    }

    if (roles.includes('vendor') || roles.includes('vendor_pending')) {
      await pg.query(
        `INSERT INTO vendor_profiles (tenant_id, user_id, onboarding_step, activated_at)
         VALUES ($1, $2, 'personal', now())
         ON CONFLICT (tenant_id, user_id) DO NOTHING`,
        [user.tenant_id, user.id],
      );
    }
  }

  console.log(`Backfill complete. Updated signup_portal_deprecated for ${updated} users.`);
  await pg.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
