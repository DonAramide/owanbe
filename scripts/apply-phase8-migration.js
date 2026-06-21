#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { Client } = require('../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const MIGRATION = path.join(__dirname, '../infra/db/025_phase8_security.sql');

async function main() {
  const sql = fs.readFileSync(MIGRATION, 'utf8');
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  try {
    await pg.query(sql);
    const perms = await pg.query(
      `SELECT COUNT(*)::int AS n FROM permissions`,
    );
    const organizerRole = await pg.query(
      `SELECT COUNT(*)::int AS n FROM user_roles ur
       INNER JOIN roles r ON r.id = ur.role_id
       WHERE ur.user_id = '22222222-2222-4222-8222-222222222222' AND r.code = 'organizer'`,
    );
    console.log(
      JSON.stringify(
        {
          ok: true,
          permissionCount: perms.rows[0].n,
          organizerRoleAssigned: organizerRole.rows[0].n > 0,
        },
        null,
        2,
      ),
    );
  } finally {
    await pg.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
