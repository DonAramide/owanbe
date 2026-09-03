/**
 * QA: probe pricing + booked ranges SQL used by createRequest.
 */
import { Client } from 'pg';

async function trySql(pg: Client, label: string, sql: string, params: unknown[] = []) {
  try {
    const r = await pg.query(sql, params);
    console.log('OK', label, 'rows=', r.rowCount);
  } catch (e: unknown) {
    const err = e as { code?: string; message?: string; position?: string };
    console.log('FAIL', label);
    console.log(JSON.stringify({ code: err.code, message: err.message, position: err.position }, null, 2));
  }
}

async function main() {
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();
  const tenantId = '11111111-1111-4111-8111-111111111111';
  const vendorId = '401c71d5-5067-42da-a0c3-f1ab03f3aeec';
  const eventId = '437cdbfb-c8a3-4416-be51-abab6330b428';
  const serviceId = '186336f2-5e1c-4d57-87b3-b852268c5ac0';

  // Show service_key for fixture
  const vs = await pg.query(`SELECT service_key, service_name, base_payout_minor FROM vendor_services WHERE id=$1`, [
    serviceId,
  ]);
  console.log('service', vs.rows[0]);
  const serviceKey = vs.rows[0].service_key;

  await trySql(
    pg,
    'platform_vendor_pricing_rules',
    `SELECT vendor_id, service_key, markup_bps, is_default
     FROM platform_vendor_pricing_rules
     WHERE tenant_id = $1 AND (vendor_id IS NULL OR vendor_id = $2)
     ORDER BY vendor_id NULLS LAST, service_key NULLS LAST
     LIMIT 20`,
    [tenantId, vendorId],
  );

  await trySql(
    pg,
    'resolveBasePayoutMinor',
    `SELECT id, base_payout_minor::text, currency, service_name
     FROM vendor_services
     WHERE tenant_id = $1 AND vendor_id = $2 AND id = $3`,
    [tenantId, vendorId, serviceId],
  );

  // loadBookedRanges
  const ev = await pg.query(`SELECT starts_at, ends_at FROM events WHERE id=$1`, [eventId]);
  const start = ev.rows[0].starts_at;
  const end = ev.rows[0].ends_at ?? new Date(new Date(start).getTime() + 86400000);

  await trySql(
    pg,
    'loadBookedRanges',
    `SELECT e.starts_at, e.ends_at
     FROM vendor_event_requests r
     JOIN events e ON e.id = r.event_id
     WHERE r.tenant_id = $1
       AND r.vendor_id = $2
       AND r.stage IN ('accepted', 'scheduled', 'arrived', 'completed')
       AND ($6::uuid IS NULL OR r.id <> $6)
       AND (
         (r.vendor_service_id IS NOT NULL AND r.vendor_service_id = $3)
         OR (r.vendor_service_id IS NULL AND r.service_key = $4)
       )
       AND e.starts_at < $5
       AND COALESCE(e.ends_at, e.starts_at + interval '24 hours') > $7`,
    [tenantId, vendorId, serviceId, serviceKey, end, null, start],
  );

  // Columns on platform_vendor_pricing_rules
  const cols = await pg.query(
    `SELECT column_name FROM information_schema.columns WHERE table_name='platform_vendor_pricing_rules' ORDER BY ordinal_position`,
  );
  console.log('platform_vendor_pricing_rules', cols.rows.map((r) => r.column_name));

  // Search recent migrations for is_active on tenant_vendor_categories
  const catCols = await pg.query(
    `SELECT column_name FROM information_schema.columns WHERE table_name='tenant_vendor_categories' ORDER BY ordinal_position`,
  );
  console.log('tenant_vendor_categories', catCols.rows.map((r) => r.column_name));

  // Capture Nest-style: set log_min_messages and re-run via direct client simulating wrong SQL
  // Check writeFeed / notifications tables
  await trySql(
    pg,
    'notifications insert cols',
    `SELECT column_name FROM information_schema.columns WHERE table_name='notifications' AND column_name='dedupe_key'`,
  );

  // Check if custom_extras column expected
  await trySql(
    pg,
    'vendor_services.custom_extras',
    `SELECT custom_extras FROM vendor_services WHERE id = $1`,
    [serviceId],
  );

  await pg.end();
}

main();
