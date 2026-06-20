#!/usr/bin/env node
const { Client } = require('../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const TENANT_ID = process.env.TENANT_ID || '11111111-1111-4111-8111-111111111111';

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  await pg.query(
    `UPDATE tenant_finance_settings
     SET escrow_release_delay_hours = 0, updated_at = now()
     WHERE tenant_id = $1`,
    [TENANT_ID],
  );
  const orders = await pg.query(
    `UPDATE ticket_orders
     SET escrow_release_not_before = now() - interval '1 hour', updated_at = now()
     WHERE tenant_id = $1 AND status IN ('fulfilled', 'confirmed')
     RETURNING id`,
    [TENANT_ID],
  );
  const settings = await pg.query(
    `SELECT escrow_release_delay_hours FROM tenant_finance_settings WHERE tenant_id = $1`,
    [TENANT_ID],
  );
  console.log(JSON.stringify({
    escrow_release_delay_hours: settings.rows[0]?.escrow_release_delay_hours,
    ordersReleased: orders.rowCount,
  }, null, 2));
  await pg.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
