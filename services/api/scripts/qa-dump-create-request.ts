import { Client } from 'pg';
import * as jwt from 'jsonwebtoken';

async function main() {
  const api = 'http://127.0.0.1:8080/v1';
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();
  const org = (
    await pg.query<{ id: string; email: string; tenant_id: string }>(
      `SELECT id, email, tenant_id FROM users WHERE email='organizer@owanbe.dev'`,
    )
  ).rows[0]!;
  const roles = (
    await pg.query<{ code: string }>(
      `SELECT r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = $1`,
      [org.id],
    )
  ).rows.map((r) => r.code);
  const token = jwt.sign(
    {
      sub: org.id,
      email: org.email,
      role: 'authenticated',
      app_metadata: { tenant_id: org.tenant_id, roles },
    },
    process.env.SUPABASE_JWT_SECRET!,
    { expiresIn: '10m', algorithm: 'HS256' },
  );
  const starts = new Date(Date.now() + 100 * 86400e3);
  starts.setUTCHours(18, 0, 0, 0);
  const ends = new Date(starts.getTime() + 4 * 3600e3);
  const evRes = await fetch(`${api}/events`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      'X-Tenant-Id': org.tenant_id,
    },
    body: JSON.stringify({
      title: `QA dump ${Date.now()}`,
      startsAt: starts.toISOString(),
      endsAt: ends.toISOString(),
    }),
  });
  const ev = (await evRes.json()) as { id: string };
  const ven = (
    await pg.query<{ id: string }>(
      `SELECT v.id FROM vendors v JOIN users u ON u.id=v.owner_user_id WHERE u.email='vendor@owanbe.dev'`,
    )
  ).rows[0]!;
  const svc = (
    await pg.query<{ id: string; service_key: string; service_name: string }>(
      `SELECT id, service_key, service_name FROM vendor_services WHERE vendor_id=$1 AND status='active' LIMIT 1`,
      [ven.id],
    )
  ).rows[0]!;
  const res = await fetch(`${api}/events/${ev.id}/vendor-requests`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      'X-Tenant-Id': org.tenant_id,
    },
    body: JSON.stringify({
      vendorId: ven.id,
      vendorServiceId: svc.id,
      serviceKey: svc.service_key,
      serviceLabel: svc.service_name,
      message: 'dump',
      source: 'marketplace',
      selectedCapabilities: [{ key: 'sound_system', label: 'Sound System' }],
    }),
  });
  console.log('STATUS', res.status);
  console.log('BODY', await res.text());
  const row = (
    await pg.query(
      `SELECT id, stage, metadata FROM vendor_event_requests WHERE event_id=$1 ORDER BY created_at DESC LIMIT 1`,
      [ev.id],
    )
  ).rows[0];
  console.log('DB', row);
  await pg.end();
}

main();
