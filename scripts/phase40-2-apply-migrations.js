#!/usr/bin/env node
/**
 * Phase 40.2 — Apply migrations 034–038 and validate schema.
 */
const fs = require('fs');
const path = require('path');
const { Client } = require('../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';

const MIGRATIONS = [
  { id: '034', file: '034_event_seating.sql', tables: ['event_seating_layouts', 'event_seating_tables', 'event_seating_assignments'] },
  { id: '035', file: '035_event_programs.sql', tables: ['event_program_items', 'event_activity_log', 'event_program_reminders'] },
  { id: '036', file: '036_vendor_crm.sql', tables: ['vendor_event_requests', 'vendor_request_stage_history'] },
  { id: '037', file: '037_vendor_calendar.sql', tables: ['vendor_availability_settings', 'vendor_calendar_blocks'] },
  { id: '038', file: '038_event_guests_invitations.sql', tables: ['event_guests', 'event_invitations', 'event_invitation_tokens'] },
];

async function ensureHistoryTable(pg) {
  await pg.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id          TEXT PRIMARY KEY,
      filename    TEXT NOT NULL,
      applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

async function isApplied(pg, id) {
  const { rows } = await pg.query('SELECT 1 FROM schema_migrations WHERE id = $1', [id]);
  return rows.length > 0;
}

async function tableExists(pg, name) {
  const { rows } = await pg.query('SELECT to_regclass($1) AS reg', [`public.${name}`]);
  return rows[0]?.reg != null;
}

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  const report = { applied: [], skipped: [], failed: [], validation: [] };

  try {
    await ensureHistoryTable(pg);
    const dbDir = path.join(__dirname, '../infra/db');

    for (const m of MIGRATIONS) {
      const sqlPath = path.join(dbDir, m.file);
      if (!fs.existsSync(sqlPath)) {
        report.failed.push({ id: m.id, error: `missing file ${m.file}` });
        continue;
      }
      if (await isApplied(pg, m.id)) {
        report.skipped.push({ id: m.id, reason: 'already in schema_migrations' });
        continue;
      }
      const allTablesExist = (await Promise.all(m.tables.map((t) => tableExists(pg, t)))).every(Boolean);
      if (allTablesExist) {
        await pg.query('INSERT INTO schema_migrations (id, filename) VALUES ($1, $2) ON CONFLICT DO NOTHING', [m.id, m.file]);
        report.skipped.push({ id: m.id, reason: 'tables already exist' });
        continue;
      }
      const sql = fs.readFileSync(sqlPath, 'utf8');
      try {
        await pg.query(sql);
        await pg.query('INSERT INTO schema_migrations (id, filename) VALUES ($1, $2) ON CONFLICT DO NOTHING', [m.id, m.file]);
        report.applied.push({ id: m.id, file: m.file });
      } catch (e) {
        await pg.query('ROLLBACK').catch(() => undefined);
        report.failed.push({ id: m.id, error: e.message });
      }
    }

    for (const m of MIGRATIONS) {
      const tables = {};
      for (const t of m.tables) {
        tables[t] = await tableExists(pg, t);
      }
      const ok = Object.values(tables).every(Boolean);
      if (ok && !(await isApplied(pg, m.id))) {
        await pg.query('INSERT INTO schema_migrations (id, filename) VALUES ($1, $2) ON CONFLICT DO NOTHING', [m.id, m.file]);
      }
      report.validation.push({ id: m.id, tables, ok });
    }

    const { rows: history } = await pg.query(
      'SELECT id, filename, applied_at FROM schema_migrations WHERE id = ANY($1) ORDER BY id',
      [MIGRATIONS.map((m) => m.id)],
    );
    report.history = history;

    const allOk = report.failed.length === 0 && report.validation.every((v) => v.ok);
    report.result = allOk ? 'PASS' : 'FAIL';
    console.log(JSON.stringify(report, null, 2));
    process.exit(allOk ? 0 : 1);
  } finally {
    await pg.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
