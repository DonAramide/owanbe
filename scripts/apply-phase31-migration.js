#!/usr/bin/env node
/** Apply migration 031 — Fashion & Attire marketplace categories */
const fs = require('fs');
const path = require('path');
const { Client } = require('../../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const sqlPath = path.join(__dirname, '../../infra/db/031_fashion_attire_categories.sql');

async function main() {
  const sql = fs.readFileSync(sqlPath, 'utf8');
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  try {
    await pg.query(sql);
    console.log('Applied 031_fashion_attire_categories.sql');
  } finally {
    await pg.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
