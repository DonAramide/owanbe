/**
 * Phase 3A end-to-end: organizer creates vendor request → vendor SSE receives signal.
 *
 * npx --yes tsx -r dotenv/config scripts/crm-realtime-e2e-request.ts
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
  const databaseUrl = process.env.DATABASE_URL!;
  const secret = process.env.SUPABASE_JWT_SECRET!;
  const apiBase = 'http://127.0.0.1:8080/v1';

  const pg = new Client({ connectionString: databaseUrl });
  await pg.connect();

  const { rows: pairs } = await pg.query<{
    tenant_id: string;
    organizer_user_id: string;
    organizer_email: string | null;
    vendor_user_id: string;
    vendor_email: string | null;
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
            vu.email AS vendor_email,
            v.id AS vendor_id,
            e.id AS event_id,
            vs.id AS service_id,
            vs.service_key,
            vs.service_name
     FROM organizers o
     JOIN users ou ON ou.id = o.owner_user_id
     JOIN vendors v ON v.tenant_id = o.tenant_id AND v.owner_user_id IS NOT NULL
     JOIN users vu ON vu.id = v.owner_user_id
     JOIN events e ON e.tenant_id = o.tenant_id AND e.organizer_id = o.id
     JOIN vendor_services vs ON vs.vendor_id = v.id AND vs.status = 'active'
     WHERE o.owner_user_id IS DISTINCT FROM v.owner_user_id
     LIMIT 1`,
  );

  if (!pairs.length) {
    console.error('No organizer/vendor/event/service fixture found');
    await pg.end();
    process.exit(1);
  }

  const f = pairs[0]!;

  async function rolesFor(userId: string): Promise<string[]> {
    const { rows } = await pg.query<{ code: string }>(
      `SELECT r.code FROM user_roles ur
       JOIN roles r ON r.id = ur.role_id
       WHERE ur.user_id = $1`,
      [userId],
    );
    return rows.map((r) => r.code);
  }

  const organizerRoles = await rolesFor(f.organizer_user_id);
  const vendorRoles = await rolesFor(f.vendor_user_id);
  await pg.end();

  console.log('fixture', {
    tenantId: f.tenant_id,
    organizerRoles,
    vendorRoles,
    eventId: f.event_id,
    vendorId: f.vendor_id,
  });

  const vendorToken = sign(
    secret,
    f.vendor_user_id,
    f.tenant_id,
    f.vendor_email ?? 'vendor@test.local',
    vendorRoles.length ? vendorRoles : ['vendor'],
  );
  const organizerToken = sign(
    secret,
    f.organizer_user_id,
    f.tenant_id,
    f.organizer_email ?? 'org@test.local',
    organizerRoles.length ? organizerRoles : ['client'],
  );

  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), 45_000);

  const sseRes = await fetch(`${apiBase}/me/crm/stream`, {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${vendorToken}`,
      'X-Tenant-Id': f.tenant_id,
    },
    signal: abort.signal,
  });
  if (!sseRes.ok || !sseRes.body) {
    console.error('vendor SSE failed', sseRes.status, await sseRes.text());
    process.exit(1);
  }
  console.log('vendor SSE connected');

  // Give subscribe a moment
  await new Promise((r) => setTimeout(r, 500));

  const createRes = await fetch(`${apiBase}/events/${f.event_id}/vendor-requests`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${organizerToken}`,
      'X-Tenant-Id': f.tenant_id,
    },
    body: JSON.stringify({
      vendorId: f.vendor_id,
      vendorServiceId: f.service_id,
      serviceKey: f.service_key,
      serviceLabel: f.service_name,
      message: 'Phase 3A E2E realtime smoke',
      source: 'marketplace',
    }),
  });

  if (!createRes.ok) {
    console.error('create request failed', createRes.status, await createRes.text());
    process.exit(1);
  }
  console.log('organizer createRequest ok');

  const reader = sseRes.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let gotIncoming = false;

  while (!gotIncoming) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    while (true) {
      const sep = buffer.indexOf('\n\n');
      if (sep < 0) break;
      const frame = buffer.slice(0, sep);
      buffer = buffer.slice(sep + 2);
      const data = frame
        .split('\n')
        .filter((l) => l.startsWith('data:'))
        .map((l) => l.slice(5).trim())
        .join('\n');
      if (!data) continue;
      const json = JSON.parse(data);
      if (json.type === 'vendor_request_incoming') {
        gotIncoming = true;
        console.log('PASS vendor received vendor_request_incoming', {
          eventId: json.eventId,
          requestId: json.resource?.id,
          dedupeKey: json.dedupeKey,
        });
      }
    }
  }

  clearTimeout(timeout);
  abort.abort();

  if (!gotIncoming) {
    console.error('FAIL: no vendor_request_incoming on SSE');
    process.exit(1);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
