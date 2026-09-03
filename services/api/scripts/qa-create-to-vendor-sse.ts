/**
 * Post-069: Organizer create → Vendor SSE vendor_request_incoming
 * Accounts: organizer@owanbe.dev → vendor@owanbe.dev
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

async function rolesFor(pg: Client, userId: string) {
  const { rows } = await pg.query<{ code: string }>(
    `SELECT r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = $1`,
    [userId],
  );
  return rows.map((r) => r.code);
}

async function main() {
  const apiBase = 'http://127.0.0.1:8080/v1';
  const secret = process.env.SUPABASE_JWT_SECRET!;
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();

  const { rows: users } = await pg.query<{ id: string; email: string; tenant_id: string }>(
    `SELECT id, email, tenant_id FROM users WHERE email IN ('organizer@owanbe.dev','vendor@owanbe.dev')`,
  );
  const org = users.find((u) => u.email === 'organizer@owanbe.dev');
  const ven = users.find((u) => u.email === 'vendor@owanbe.dev');
  if (!org || !ven) {
    console.error('MISSING_ACCOUNTS', users);
    process.exit(1);
  }

  const { rows: events } = await pg.query<{ id: string; title: string }>(
    `SELECT e.id, e.title FROM events e
     JOIN organizers o ON o.id = e.organizer_id
     WHERE o.owner_user_id = $1
     ORDER BY e.updated_at DESC NULLS LAST
     LIMIT 5`,
    [org.id],
  );
  const { rows: services } = await pg.query<{
    id: string;
    service_key: string;
    service_name: string;
    vendor_id: string;
  }>(
    `SELECT vs.id, vs.service_key, vs.service_name, vs.vendor_id
     FROM vendor_services vs
     JOIN vendors v ON v.id = vs.vendor_id
     WHERE v.owner_user_id = $1 AND vs.status = 'active'
     LIMIT 5`,
    [ven.id],
  );

  if (!events.length || !services.length) {
    console.error('NO_EVENT_OR_SERVICE', { events, services });
    await pg.end();
    process.exit(1);
  }

  const event = events[0]!;
  const service = services[0]!;
  const orgRoles = await rolesFor(pg, org.id);
  const venRoles = await rolesFor(pg, ven.id);

  console.log('FIXTURE', {
    tenantId: org.tenant_id,
    organizerUserId: org.id,
    vendorUserId: ven.id,
    eventId: event.id,
    eventTitle: event.title,
    vendorId: service.vendor_id,
    serviceId: service.id,
    serviceKey: service.service_key,
  });

  const orgToken = sign(secret, org.id, org.tenant_id, org.email, orgRoles);
  const venToken = sign(secret, ven.id, ven.tenant_id, ven.email, venRoles);

  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), 45_000);
  const sseRes = await fetch(`${apiBase}/me/crm/stream`, {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${venToken}`,
      'X-Tenant-Id': ven.tenant_id,
    },
    signal: abort.signal,
  });
  if (!sseRes.ok || !sseRes.body) {
    console.error('VENDOR_SSE_FAIL', sseRes.status, await sseRes.text());
    process.exit(1);
  }
  console.log('vendor_sse_connected');
  await new Promise((r) => setTimeout(r, 500));

  const t0 = new Date().toISOString();
  const createRes = await fetch(`${apiBase}/events/${event.id}/vendor-requests`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': org.tenant_id,
    },
    body: JSON.stringify({
      vendorId: service.vendor_id,
      vendorServiceId: service.id,
      serviceKey: service.service_key,
      serviceLabel: service.service_name,
      message: 'Phase 3A post-069 create → SSE proof',
      source: 'marketplace',
    }),
  });
  const createBody = await createRes.text();
  console.log('CREATE_HTTP', createRes.status, createBody.slice(0, 400));
  if (!createRes.ok) {
    process.exit(1);
  }

  let createdRequestId: string | null = null;
  try {
    const parsed = JSON.parse(createBody) as { items?: Array<{ id: string; vendorId: string; stage: string }> };
    const match = parsed.items?.find(
      (i) => i.vendorId === service.vendor_id && i.stage === 'new',
    );
    createdRequestId = match?.id ?? parsed.items?.[0]?.id ?? null;
  } catch {
    /* ignore */
  }

  const { rows: dbRows } = await pg.query<{ id: string; stage: string; created_at: Date }>(
    `SELECT id, stage, created_at FROM vendor_event_requests
     WHERE tenant_id = $1 AND event_id = $2 AND vendor_id = $3 AND service_key = $4
     ORDER BY updated_at DESC LIMIT 1`,
    [org.tenant_id, event.id, service.vendor_id, service.service_key],
  );
  console.log('DB_ROW', dbRows[0] ?? null);
  createdRequestId = createdRequestId ?? dbRows[0]?.id ?? null;

  const reader = sseRes.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let got: Record<string, unknown> | null = null;
  const deadline = Date.now() + 12_000;
  while (Date.now() < deadline && !got) {
    const remaining = Math.max(50, deadline - Date.now());
    const raced = await Promise.race([
      reader.read().then((r) => ({ kind: 'read' as const, r })),
      new Promise<{ kind: 'timeout' }>((resolve) => setTimeout(() => resolve({ kind: 'timeout' }), remaining)),
    ]);
    if (raced.kind === 'timeout') break;
    const { done, value } = raced.r;
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
      const json = JSON.parse(data) as Record<string, unknown>;
      if (json.type === 'connected') continue;
      if (
        json.type === 'vendor_request_incoming' &&
        (!createdRequestId || (json.resource as { id?: string })?.id === createdRequestId)
      ) {
        got = json;
        break;
      }
    }
  }

  clearTimeout(timeout);
  abort.abort();
  await pg.end();

  console.log('TEST_CREATE_TO_VENDOR_SSE', got ? 'PASS' : 'FAIL', {
    sentAt: t0,
    requestId: createdRequestId,
    eventId: event.id,
    sseType: got?.type,
    sseEventId: got?.eventId,
    dedupeKey: got?.dedupeKey,
    organizerUserId: org.id,
    vendorUserId: ven.id,
  });
  if (!got) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
