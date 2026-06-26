#!/usr/bin/env node
/** Apply migrations 036 + 037 — Vendor CRM and unified calendar */
const fs = require('fs');
const path = require('path');
const { Client } = require('../../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  try {
    for (const file of ['036_vendor_crm.sql', '037_vendor_calendar.sql']) {
      const sql = fs.readFileSync(path.join(__dirname, '../../infra/db', file), 'utf8');
      await pg.query(sql);
      console.log(`Applied ${file}`);
    }
  } finally {
    await pg.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
