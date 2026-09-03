/**
 * QA-only: walk createRequest SQL in order until 42703 surfaces with full message.
 */
import { Client } from 'pg';

async function main() {
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();
  pg.on('error', () => undefined);

  const tenantId = '11111111-1111-4111-8111-111111111111';
  const vendorId = '401c71d5-5067-42da-a0c3-f1ab03f3aeec';
  const eventId = '437cdbfb-c8a3-4416-be51-abab6330b428';
  const serviceId = '186336f2-5e1c-4d57-87b3-b852268c5ac0';
  const organizerUserId = '33333333-3333-4333-8333-333333333331';

  const steps: Array<[string, string, unknown[]]> = [
    [
      'vendors lookup',
      `SELECT id FROM vendors WHERE tenant_id = $1 AND id = $2 AND owner_user_id IS NOT NULL`,
      [tenantId, vendorId],
    ],
    [
      'vendor_services getById-like',
      `SELECT * FROM vendor_services WHERE tenant_id = $1 AND vendor_id = $2 AND id = $3`,
      [tenantId, vendorId, serviceId],
    ],
    [
      'allowedCapabilityKeys categories',
      `SELECT slug, label, metadata FROM tenant_vendor_categories
       WHERE tenant_id = $1 AND is_active = true`,
      [tenantId],
    ],
    [
      'event window',
      `SELECT starts_at, ends_at FROM events WHERE tenant_id = $1 AND id = $2`,
      [tenantId, eventId],
    ],
    [
      'available_for_bookings',
      `SELECT available_for_bookings FROM vendor_profiles
       WHERE tenant_id = $1 AND vendor_id = $2 LIMIT 1`,
      [tenantId, vendorId],
    ],
    [
      'vacation settings',
      `SELECT vacation_mode, vacation_until FROM vendor_availability_settings WHERE vendor_id = $1`,
      [vendorId],
    ],
    [
      'calendar blocks',
      `SELECT starts_at, ends_at, kind FROM vendor_calendar_blocks
       WHERE tenant_id = $1 AND vendor_id = $2
         AND kind IN ('blackout', 'vacation')
         AND starts_at < now() + interval '1 year' AND ends_at > now()`,
      [tenantId, vendorId],
    ],
    [
      'pricing rules',
      `SELECT * FROM vendor_pricing_rules WHERE tenant_id = $1 AND vendor_id = $2 LIMIT 5`,
      [tenantId, vendorId],
    ],
    [
      'tenant finance markup',
      `SELECT * FROM tenant_finance_settings WHERE tenant_id = $1 LIMIT 1`,
      [tenantId],
    ],
    [
      'organizer resolve',
      `SELECT id FROM organizers WHERE tenant_id = $1 AND owner_user_id = $2`,
      [tenantId, organizerUserId],
    ],
  ];

  for (const [label, sql, params] of steps) {
    try {
      const r = await pg.query(sql, params);
      console.log('OK', label, 'rows=', r.rowCount);
    } catch (e: unknown) {
      const err = e as { code?: string; message?: string; position?: string };
      console.log('FAIL', label);
      console.log(JSON.stringify({ code: err.code, message: err.message, position: err.position }, null, 2));
      await pg.end();
      return;
    }
  }

  // Probe custom extras / 069 columns if referenced
  const extrasTables = await pg.query(
    `SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ILIKE '%extra%'`,
  );
  console.log('extra tables', extrasTables.rows);

  // Try INSERT shape used by createRequest (dry-run via prepare)
  const insertSql = `INSERT INTO vendor_event_requests (
         tenant_id, event_id, vendor_id, organizer_id, stage, service_label, service_key,
         vendor_service_id, message, source,
         customer_price_minor, vendor_payout_minor, platform_margin_minor, pricing_markup_bps,
         metadata
       ) VALUES (
         $1, $2, $3, $4, 'new', $5, $6, $7, $8, $9,
         $10::bigint, $11::bigint, $12::bigint, $13,
         $14::jsonb
       ) RETURNING id`;
  try {
    await pg.query('BEGIN');
    // get organizer id
    const org = await pg.query(`SELECT id FROM organizers WHERE tenant_id=$1 AND owner_user_id=$2`, [
      tenantId,
      organizerUserId,
    ]);
    await pg.query(insertSql, [
      tenantId,
      eventId,
      vendorId,
      org.rows[0].id,
      'test',
      'test_key',
      serviceId,
      'qa',
      'marketplace',
      null,
      null,
      null,
      null,
      JSON.stringify({}),
    ]);
    console.log('OK insert dry-run');
    await pg.query('ROLLBACK');
  } catch (e: unknown) {
    await pg.query('ROLLBACK').catch(() => undefined);
    const err = e as { code?: string; message?: string; position?: string };
    console.log('FAIL insert');
    console.log(JSON.stringify({ code: err.code, message: err.message, position: err.position }, null, 2));
  }

  await pg.end();
}

main();
