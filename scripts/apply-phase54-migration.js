#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { Client } = require('../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const MIGRATION = path.join(__dirname, '../infra/db/022_phase54_persistence.sql');

async function main() {
  const sql = fs.readFileSync(MIGRATION, 'utf8');
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  try {
    await pg.query(sql);
    const tables = await pg.query(
      `SELECT table_name FROM information_schema.tables
       WHERE table_schema = 'public'
         AND table_name IN (
           'vendor_event_participations',
           'event_check_ins',
           'event_incidents',
           'event_feed_items'
         )
       ORDER BY table_name`,
    );
    console.log(JSON.stringify({ ok: true, tables: tables.rows.map((r) => r.table_name) }, null, 2));
  } finally {
    await pg.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
