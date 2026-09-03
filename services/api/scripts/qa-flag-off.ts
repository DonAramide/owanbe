import { Client } from 'pg';
import * as jwt from 'jsonwebtoken';

async function main() {
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();
  const { rows } = await pg.query<{ id: string; tenant_id: string }>(
    `SELECT id, tenant_id FROM users WHERE email = 'vendor@owanbe.dev' LIMIT 1`,
  );
  const u = rows[0]!;
  const { rows: roles } = await pg.query<{ code: string }>(
    `SELECT r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = $1`,
    [u.id],
  );
  const { rows: vendors } = await pg.query<{ id: string }>(
    `SELECT id FROM vendors WHERE owner_user_id = $1`,
    [u.id],
  );
  await pg.end();

  const token = jwt.sign(
    {
      sub: u.id,
      email: 'vendor@owanbe.dev',
      role: 'authenticated',
      app_metadata: { tenant_id: u.tenant_id, roles: roles.map((r) => r.code) },
    },
    process.env.SUPABASE_JWT_SECRET!,
    { expiresIn: '5m', algorithm: 'HS256' },
  );

  const sse = await fetch('http://127.0.0.1:8080/v1/me/crm/stream', {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${token}`,
      'X-Tenant-Id': u.tenant_id,
    },
  });
  const sseBody = await sse.text();
  console.log('SSE', sse.status, sseBody.slice(0, 200));

  const inbox = await fetch(`http://127.0.0.1:8080/v1/vendors/${vendors[0]!.id}/vendor-requests`, {
    headers: {
      Authorization: `Bearer ${token}`,
      'X-Tenant-Id': u.tenant_id,
    },
  });
  console.log('REST_INBOX', inbox.status);

  const ops = await fetch('http://127.0.0.1:8080/v1/events/not-a-real-event/feed/stream', {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${token}`,
      'X-Tenant-Id': u.tenant_id,
    },
  });
  console.log('EVENT_OPS_SSE', ops.status);
}

main();
