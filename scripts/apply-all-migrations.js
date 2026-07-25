const fs = require('fs');
const path = require('path');
const { Client } = require('../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5436/owanbe';

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  console.log('Connected to database.');

  try {
    // 1. Create schema_migrations table
    await pg.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id          TEXT PRIMARY KEY,
        filename    TEXT NOT NULL,
        applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);

    // 2. Read all SQL files in infra/db
    const dbDir = path.join(__dirname, '../infra/db');
    const files = fs.readdirSync(dbDir).filter(f => f.endsWith('.sql'));

    // Sort files:
    // - owanbe_core.sql first
    // - then alphabetically (which sorts 002_, 003_... sequentially)
    const sortedFiles = files.sort((a, b) => {
      if (a === 'owanbe_core.sql') return -1;
      if (b === 'owanbe_core.sql') return 1;
      return a.localeCompare(b);
    });

    // Count prefixes to detect duplicates
    const prefixCounts = {};
    for (const file of sortedFiles) {
      const match = file.match(/^(\d{3})_/);
      if (match) {
        const prefix = match[1];
        prefixCounts[prefix] = (prefixCounts[prefix] || 0) + 1;
      }
    }

    for (const file of sortedFiles) {
      let id;
      if (file === 'owanbe_core.sql') {
        id = '001';
      } else {
        const match = file.match(/^(\d{3})_/);
        if (!match) {
          console.log(`Skipping file: ${file}`);
          continue;
        }
        const prefix = match[1];
        if (prefixCounts[prefix] > 1) {
          // Duplicate prefix (like 028 or 029). Use filename without .sql to keep IDs unique
          id = file.replace(/\.sql$/, '');
        } else {
          // Unique prefix. Use the 3-digit prefix as ID
          id = prefix;
        }
      }

      // Check if already applied
      const { rows } = await pg.query('SELECT 1 FROM schema_migrations WHERE id = $1', [id]);
      if (rows.length > 0) {
        console.log(`Migration ${file} (ID: ${id}) is already applied. Skipping.`);
        continue;
      }

      console.log(`Applying migration: ${file} (ID: ${id})...`);
      const sql = fs.readFileSync(path.join(dbDir, file), 'utf8');
      
      try {
        await pg.query(sql);
        await pg.query('INSERT INTO schema_migrations (id, filename) VALUES ($1, $2)', [id, file]);
        console.log(`Successfully applied ${file}.`);
      } catch (err) {
        console.error(`Error applying ${file}:`, err.message);
        throw err;
      }
    }

    console.log('All migrations applied successfully!');
  } finally {
    await pg.end();
  }
}

main().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
