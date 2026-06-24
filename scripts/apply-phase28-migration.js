#!/usr/bin/env node
/** Apply migration 028 — event website builder */
const fs = require('fs');
const path = require('path');
const { Client } = require('../../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const sqlPath = path.join(__dirname, '../../infra/db/028_event_website.sql');

async function main() {
  const sql = fs.readFileSync(sqlPath, 'utf8');
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  try {
    await pg.query(sql);
    console.log('Applied 028_event_website.sql');
  } finally {
    await pg.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
