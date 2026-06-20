#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { Client } = require('../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const MIGRATION = path.join(__dirname, '../infra/db/024_phase7_super_admin.sql');

async function main() {
  const sql = fs.readFileSync(MIGRATION, 'utf8');
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  try {
    await pg.query(sql);
    const role = await pg.query(
      `SELECT r.code FROM user_roles ur INNER JOIN roles r ON r.id = ur.role_id
       WHERE ur.user_id = '88888888-8888-4888-8888-888888888888'`,
    );
    console.log(JSON.stringify({ ok: true, roles: role.rows.map((r) => r.code) }, null, 2));
  } finally {
    await pg.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
