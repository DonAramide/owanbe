#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { Client } = require('../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const MIGRATION = path.join(__dirname, '../infra/db/026_phase9_integrations.sql');

async function main() {
  const sql = fs.readFileSync(MIGRATION, 'utf8');
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  try {
    await pg.query(sql);
    const tables = await pg.query(
      `SELECT to_regclass('public.notification_deliveries') IS NOT NULL AS notifications,
              to_regclass('public.media_objects') IS NOT NULL AS media`,
    );
    console.log(JSON.stringify({ ok: true, ...tables.rows[0] }, null, 2));
  } finally {
    await pg.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
