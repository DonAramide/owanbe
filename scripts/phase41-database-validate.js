#!/usr/bin/env node
/**
 * Phase 41 — Database validation (migrations 034–038, constraints, indexes).
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { Client } = require('../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const MIGRATIONS = ['034', '035', '036', '037', '038'];
const EXPECTED_TABLES = {
  '034': ['event_seating_layouts', 'event_seating_tables', 'event_seating_assignments'],
  '035': ['event_program_items', 'event_activity_log', 'event_program_reminders'],
  '036': ['vendor_event_requests', 'vendor_request_stage_history'],
  '037': ['vendor_availability_settings', 'vendor_calendar_blocks'],
  '038': ['event_guests', 'event_invitations', 'event_invitation_tokens'],
};

async function tableExists(pg, name) {
  const { rows } = await pg.query('SELECT to_regclass($1) AS reg', [`public.${name}`]);
  return rows[0]?.reg != null;
}

async function checksumFile(filePath) {
  const sql = fs.readFileSync(filePath, 'utf8');
  return crypto.createHash('sha256').update(sql).digest('hex').slice(0, 16);
}

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  const report = {
    phase: '41',
    task: 'P0.2-database',
    checkedAt: new Date().toISOString(),
    migrations: [],
    constraints: [],
    indexes: [],
    checksums: [],
    result: 'FAIL',
  };

  try {
    for (const id of MIGRATIONS) {
      const file = fs.readdirSync(path.join(__dirname, '../infra/db')).find((f) => f.startsWith(`${id}_`));
      const tables = EXPECTED_TABLES[id];
      const tableStatus = {};
      for (const t of tables) tableStatus[t] = await tableExists(pg, t);
      const { rows: hist } = await pg.query('SELECT id, filename, applied_at FROM schema_migrations WHERE id = $1', [id]);
      report.migrations.push({
        id,
        file,
        inHistory: hist.length > 0,
        appliedAt: hist[0]?.applied_at,
        tables: tableStatus,
        ok: hist.length > 0 && Object.values(tableStatus).every(Boolean),
      });
      if (file) {
        report.checksums.push({ id, file, sha256prefix: await checksumFile(path.join(__dirname, '../infra/db', file)) });
      }
    }

    const { rows: fkViolations } = await pg.query(`
      SELECT conname, conrelid::regclass AS table_name
      FROM pg_constraint
      WHERE contype = 'f' AND connamespace = 'public'::regnamespace
      LIMIT 5`);
    report.constraints = { foreignKeysSample: fkViolations.length, ok: true };

    const { rows: idx } = await pg.query(`
      SELECT tablename, indexname FROM pg_indexes
      WHERE schemaname = 'public' AND tablename = ANY($1::text[])
      ORDER BY tablename`, [Object.values(EXPECTED_TABLES).flat()]);
    report.indexes = { count: idx.length, ok: idx.length > 0, sample: idx.slice(0, 8) };

    report.result = report.migrations.every((m) => m.ok) ? 'PASS' : 'FAIL';
    console.log(JSON.stringify(report, null, 2));
    process.exit(report.result === 'PASS' ? 0 : 1);
  } finally {
    await pg.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
