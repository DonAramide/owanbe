/**
 * QA-only: reproduce createRequest 42703 and print exact PG message.
 * Does not modify schema or application code.
 */
import { Client } from 'pg';
import * as jwt from 'jsonwebtoken';

function sign(secret: string, userId: string, tenantId: string, email: string, roles: string[]) {
  return jwt.sign(
    {
      sub: userId,
      email,
      role: 'authenticated',
      app_metadata: { tenant_id: tenantId, roles },
    },
    secret,
    { expiresIn: '15m', algorithm: 'HS256' },
  );
}

async function main() {
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();

  const { rows: pairs } = await pg.query<{
    tenant_id: string;
    organizer_user_id: string;
    organizer_email: string | null;
    vendor_user_id: string;
    vendor_id: string;
    event_id: string;
    service_id: string;
    service_key: string;
    service_name: string;
  }>(
    `SELECT o.tenant_id,
            o.owner_user_id AS organizer_user_id,
            ou.email AS organizer_email,
            v.owner_user_id AS vendor_user_id,
            v.id AS vendor_id,
            e.id AS event_id,
            vs.id AS service_id,
            vs.service_key,
            vs.service_name
     FROM organizers o
     JOIN users ou ON ou.id = o.owner_user_id
     JOIN vendors v ON v.tenant_id = o.tenant_id AND v.owner_user_id IS NOT NULL
     JOIN events e ON e.tenant_id = o.tenant_id AND e.organizer_id = o.id
     JOIN vendor_services vs ON vs.vendor_id = v.id AND vs.status = 'active'
     WHERE o.owner_user_id IS DISTINCT FROM v.owner_user_id
     LIMIT 1`,
  );

  if (!pairs.length) {
    console.log('NO_FIXTURE');
    await pg.end();
    process.exit(1);
  }
  const f = pairs[0]!;

  const { rows: roleRows } = await pg.query<{ code: string }>(
    `SELECT r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = $1`,
    [f.organizer_user_id],
  );
  const organizerRoles = roleRows.map((r) => r.code);

  // Columns that createRequest / availability / pricing may touch
  for (const table of [
    'vendor_event_requests',
    'vendor_services',
    'vendor_availability_windows',
    'vendor_availability_blocks',
    'vendors',
    'events',
  ]) {
    const exists = await pg.query(
      `SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name=$1`,
      [table],
    );
    if (!exists.rows.length) {
      console.log(`TABLE_MISSING ${table}`);
      continue;
    }
    const cols = await pg.query(
      `SELECT column_name FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position`,
      [table],
    );
    console.log(`TABLE ${table}:`, cols.rows.map((r) => r.column_name).join(', '));
  }

  await pg.end();

  const token = sign(
    process.env.SUPABASE_JWT_SECRET!,
    f.organizer_user_id,
    f.tenant_id,
    f.organizer_email ?? 'org@test.local',
    organizerRoles,
  );

  console.log('FIXTURE', {
    tenantId: f.tenant_id,
    organizerUserId: f.organizer_user_id,
    organizerRoles,
    vendorId: f.vendor_id,
    eventId: f.event_id,
    serviceId: f.service_id,
  });

  const res = await fetch(`http://127.0.0.1:8080/v1/events/${f.event_id}/vendor-requests`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      'X-Tenant-Id': f.tenant_id,
    },
    body: JSON.stringify({
      vendorId: f.vendor_id,
      vendorServiceId: f.service_id,
      serviceKey: f.service_key,
      serviceLabel: f.service_name,
      message: 'Phase 3A QA 42703 reproduce',
      source: 'marketplace',
    }),
  });

  const body = await res.text();
  console.log('HTTP', res.status, body);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
