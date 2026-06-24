#!/usr/bin/env node
/** Apply migrations 032–033 — rentals equipment */
const fs = require('fs');
const path = require('path');
const { Client } = require('../../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  try {
    for (const file of ['032_rentals_equipment.sql', '033_rentals_categories.sql']) {
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
