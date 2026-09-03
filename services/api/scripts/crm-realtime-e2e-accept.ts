/**
 * Phase 3A E2E: vendor accept → organizer receives vendor_request_update on SSE.
 * Uses an existing request in stage `new` when available.
 *
 * npx --yes tsx -r dotenv/config scripts/crm-realtime-e2e-accept.ts
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

  const { rows } = await pg.query<{
    tenant_id: string;
    request_id: string;
    vendor_user_id: string;
    organizer_user_id: string;
    vendor_email: string | null;
    organizer_email: string | null;
  }>(
    `SELECT r.tenant_id, r.id AS request_id,
            v.owner_user_id AS vendor_user_id,
            o.owner_user_id AS organizer_user_id,
            vu.email AS vendor_email,
            ou.email AS organizer_email
     FROM vendor_event_requests r
     JOIN vendors v ON v.id = r.vendor_id
     JOIN organizers o ON o.id = r.organizer_id
     JOIN users vu ON vu.id = v.owner_user_id
     JOIN users ou ON ou.id = o.owner_user_id
     WHERE r.stage = 'new'
       AND v.owner_user_id IS DISTINCT FROM o.owner_user_id
     ORDER BY r.updated_at DESC
     LIMIT 1`,
  );

  if (!rows.length) {
    console.error('No stage=new request for accept E2E');
    await pg.end();
    process.exit(1);
  }
  const f = rows[0]!;

  async function rolesFor(userId: string) {
    const { rows: rr } = await pg.query<{ code: string }>(
      `SELECT r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = $1`,
      [userId],
    );
    return rr.map((x) => x.code);
  }
  const vendorRoles = await rolesFor(f.vendor_user_id);
  const orgRoles = await rolesFor(f.organizer_user_id);
  await pg.end();

  console.log('fixture', {
    requestId: f.request_id,
    vendorRoles,
    orgRoles,
  });

  const orgToken = sign(
    secret,
    f.organizer_user_id,
    f.tenant_id,
    f.organizer_email ?? 'org@test.local',
    orgRoles,
  );
  const vendorToken = sign(
    secret,
    f.vendor_user_id,
    f.tenant_id,
    f.vendor_email ?? 'vendor@test.local',
    vendorRoles,
  );

  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), 45_000);

  const sseRes = await fetch(`${apiBase}/me/crm/stream`, {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': f.tenant_id,
    },
    signal: abort.signal,
  });
  if (!sseRes.ok || !sseRes.body) {
    console.error('organizer SSE failed', sseRes.status, await sseRes.text());
    process.exit(1);
  }
  console.log('organizer SSE connected');
  await new Promise((r) => setTimeout(r, 400));

  const stageRes = await fetch(`${apiBase}/vendor-requests/${f.request_id}/stage`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${vendorToken}`,
      'X-Tenant-Id': f.tenant_id,
    },
    body: JSON.stringify({ stage: 'accepted', note: 'Phase 3A accept E2E' }),
  });
  if (!stageRes.ok) {
    console.error('accept failed', stageRes.status, await stageRes.text());
    process.exit(1);
  }
  console.log('vendor accept ok');

  const reader = sseRes.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let got = false;
  while (!got) {
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
      if (json.type === 'vendor_request_update' && json.resource?.id === f.request_id) {
        got = true;
        console.log('PASS organizer received vendor_request_update', {
          eventId: json.eventId,
          dedupeKey: json.dedupeKey,
          stage: json.meta?.stage,
        });
      }
    }
  }

  clearTimeout(timeout);
  abort.abort();
  if (!got) {
    console.error('FAIL: no vendor_request_update on organizer SSE');
    process.exit(1);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
