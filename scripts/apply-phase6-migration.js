#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { Client } = require('../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const MIGRATION = path.join(__dirname, '../infra/db/023_phase6_admin_seed.sql');

async function main() {
  const sql = fs.readFileSync(MIGRATION, 'utf8');
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  try {
    await pg.query(sql);
    const admin = await pg.query(
      `SELECT u.id, array_agg(r.code) AS roles
       FROM users u
       LEFT JOIN user_roles ur ON ur.user_id = u.id
       LEFT JOIN roles r ON r.id = ur.role_id
       WHERE u.id = '77777777-7777-4777-8777-777777777777'
       GROUP BY u.id`,
    );
    console.log(JSON.stringify({ ok: true, admin: admin.rows[0] }, null, 2));
  } finally {
    await pg.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
