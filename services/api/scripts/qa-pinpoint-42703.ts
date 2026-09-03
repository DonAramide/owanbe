/**
 * QA-only: pinpoint which SQL in createRequest path throws 42703.
 */
import { Client } from 'pg';

async function trySql(pg: Client, label: string, sql: string, params: unknown[] = []) {
  try {
    await pg.query(sql, params);
    console.log('OK', label);
  } catch (e: unknown) {
    const err = e as { code?: string; message?: string; detail?: string };
    console.log('FAIL', label, err.code, err.message);
  }
}

async function main() {
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();

  const tenantId = '11111111-1111-4111-8111-111111111111';
  const vendorId = '401c71d5-5067-42da-a0c3-f1ab03f3aeec';
  const eventId = '437cdbfb-c8a3-4416-be51-abab6330b428';
  const serviceId = '186336f2-5e1c-4d57-87b3-b852268c5ac0';

  const tables = await pg.query(
    `SELECT table_name FROM information_schema.tables
     WHERE table_schema='public' AND (
       table_name ILIKE '%avail%' OR table_name ILIKE '%vendor_profile%'
       OR table_name ILIKE '%calendar%' OR table_name ILIKE '%categor%'
     ) ORDER BY table_name`,
  );
  console.log('related tables', tables.rows.map((r) => r.table_name));

  await trySql(
    pg,
    'vendor_profiles.available_for_bookings',
    `SELECT available_for_bookings FROM vendor_profiles WHERE vendor_id = $1 LIMIT 1`,
    [vendorId],
  );
  await trySql(
    pg,
    'vendor_availability_settings',
    `SELECT vacation_mode, vacation_until FROM vendor_availability_settings WHERE vendor_id = $1`,
    [vendorId],
  );
  await trySql(
    pg,
    'vendor_calendar_blocks',
    `SELECT starts_at, ends_at, kind FROM vendor_calendar_blocks WHERE tenant_id = $1 AND vendor_id = $2 LIMIT 1`,
    [tenantId, vendorId],
  );
  await trySql(
    pg,
    'vendor_services capabilities',
    `SELECT capabilities FROM vendor_services WHERE id = $1`,
    [serviceId],
  );
  await trySql(
    pg,
    'tenant_vendor_categories metadata',
    `SELECT metadata FROM tenant_vendor_categories LIMIT 1`,
  );
  await trySql(
    pg,
    'events starts_at',
    `SELECT starts_at, ends_at FROM events WHERE tenant_id = $1 AND id = $2`,
    [tenantId, eventId],
  );

  // List vendor_profiles columns if table exists
  const vp = await pg.query(
    `SELECT column_name FROM information_schema.columns WHERE table_name='vendor_profiles' ORDER BY ordinal_position`,
  );
  console.log('vendor_profiles cols', vp.rows.map((r) => r.column_name));

  const vas = await pg.query(
    `SELECT column_name FROM information_schema.columns WHERE table_name='vendor_availability_settings' ORDER BY ordinal_position`,
  );
  console.log('vendor_availability_settings cols', vas.rows.map((r) => r.column_name));

  await pg.end();
}

main();
