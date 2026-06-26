const { Client } = require('../services/api/node_modules/pg');
(async () => {
  const c = new Client({ connectionString: process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe' });
  await c.connect();
  await c.query(
    `UPDATE ticket_tiers SET capacity = GREATEST(capacity, 500), sold_count = LEAST(sold_count, capacity - 50)
     WHERE event_id IN (SELECT id FROM events WHERE external_ref = 'evt_lagos_owanbe_2026')`,
  );
  const r = await c.query(
    `SELECT id, name, capacity, sold_count FROM ticket_tiers
     WHERE event_id IN (SELECT id FROM events WHERE external_ref = 'evt_lagos_owanbe_2026')`,
  );
  console.log(JSON.stringify(r.rows, null, 2));
  await c.end();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
