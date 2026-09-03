/**
 * Controlled clean-event probe for create → SSE → accept → message → change-request.
 */
import { Client } from 'pg';
import * as jwt from 'jsonwebtoken';

function sign(secret: string, userId: string, tenantId: string, email: string, roles: string[]) {
  return jwt.sign(
    { sub: userId, email, role: 'authenticated', app_metadata: { tenant_id: tenantId, roles } },
    secret,
    { expiresIn: '20m', algorithm: 'HS256' },
  );
}

async function rolesFor(pg: Client, userId: string) {
  const { rows } = await pg.query<{ code: string }>(
    `SELECT r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = $1`,
    [userId],
  );
  return rows.map((r) => r.code);
}

async function openSse(apiBase: string, token: string, tenantId: string, signal: AbortSignal) {
  const res = await fetch(`${apiBase}/me/crm/stream`, {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${token}`,
      'X-Tenant-Id': tenantId,
    },
    signal,
  });
  if (!res.ok || !res.body) throw new Error(`SSE ${res.status}`);
  return res.body.getReader();
}

async function readUntil(
  reader: ReadableStreamDefaultReader<Uint8Array>,
  pred: (json: Record<string, unknown>) => boolean,
  ms: number,
) {
  const decoder = new TextDecoder();
  let buffer = '';
  const start = Date.now();
  const deadline = start + ms;
  while (Date.now() < deadline) {
    const remaining = Math.max(50, deadline - Date.now());
    const raced = await Promise.race([
      reader.read().then((r) => ({ kind: 'read' as const, r })),
      new Promise<{ kind: 'timeout' }>((resolve) => setTimeout(() => resolve({ kind: 'timeout' }), remaining)),
    ]);
    if (raced.kind === 'timeout') return null;
    const { done, value } = raced.r;
    if (done) return null;
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
      if (json.type === 'connected' || json.type === 'heartbeat') continue;
      if (pred(json)) return { json, elapsedMs: Date.now() - start };
    }
  }
  return null;
}

async function main() {
  const apiBase = 'http://127.0.0.1:8080/v1';
  const secret = process.env.SUPABASE_JWT_SECRET!;
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();

  const org = (
    await pg.query<{ id: string; email: string; tenant_id: string }>(
      `SELECT id, email, tenant_id FROM users WHERE email='organizer@owanbe.dev'`,
    )
  ).rows[0]!;
  const ven = (
    await pg.query<{ id: string; email: string; tenant_id: string }>(
      `SELECT id, email, tenant_id FROM users WHERE email='vendor@owanbe.dev'`,
    )
  ).rows[0]!;
  const orgToken = sign(secret, org.id, org.tenant_id, org.email, await rolesFor(pg, org.id));
  const venToken = sign(secret, ven.id, ven.tenant_id, ven.email, await rolesFor(pg, ven.id));
  const vendor = (await pg.query<{ id: string }>(`SELECT id FROM vendors WHERE owner_user_id=$1`, [ven.id])).rows[0]!;
  const svc = (
    await pg.query<{ id: string; service_key: string; service_name: string }>(
      `SELECT id, service_key, service_name FROM vendor_services
       WHERE vendor_id=$1 AND status='active'
         AND (lower(service_key) LIKE '%dj%' OR lower(service_name) LIKE '%dj%')
       LIMIT 1`,
      [vendor.id],
    )
  ).rows[0]!;

  // Ensure speakers is provided for ADD_CAPABILITY path
  await fetch(`${apiBase}/me/vendor-services/${svc.id}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${venToken}`,
      'X-Tenant-Id': ven.tenant_id,
    },
    body: JSON.stringify({
      capabilities: [
        { key: 'sound_system', label: 'Sound System', provided: true },
        { key: 'microphones', label: 'Microphones', provided: true },
        { key: 'speakers', label: 'Speakers', provided: true },
        { key: 'led_screen', label: 'LED Screen', provided: false },
      ],
    }),
  });

  const starts = new Date(Date.now() + 90 * 86400e3);
  starts.setUTCHours(17, 0, 0, 0);
  const ends = new Date(starts.getTime() + 5 * 3600e3);
  const createEv = await fetch(`${apiBase}/events`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': org.tenant_id,
    },
    body: JSON.stringify({
      title: `QA E2E Clean ${Date.now()}`,
      startsAt: starts.toISOString(),
      endsAt: ends.toISOString(),
      timezone: 'Africa/Lagos',
    }),
  });
  const event = (await createEv.json()) as { id?: string };
  console.log('CREATE_EVENT', createEv.status, event.id);
  if (!event.id) process.exit(1);

  const abort = new AbortController();
  const reader = await openSse(apiBase, venToken, ven.tenant_id, abort.signal);
  await readUntil(reader, () => false, 400);

  const createReq = await fetch(`${apiBase}/events/${event.id}/vendor-requests`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': org.tenant_id,
    },
    body: JSON.stringify({
      vendorId: vendor.id,
      vendorServiceId: svc.id,
      serviceKey: svc.service_key,
      serviceLabel: svc.service_name,
      message: 'QA clean create',
      source: 'marketplace',
      selectedCapabilities: [
        { key: 'sound_system', label: 'Sound System' },
        { key: 'microphones', label: 'Microphones' },
      ],
    }),
  });
  const reqWrap = (await createReq.json()) as {
    id?: string;
    items?: Array<{ id?: string; selectedCapabilities?: unknown; stage?: string }>;
    selectedCapabilities?: unknown;
  };
  const req = {
    id: reqWrap.id ?? reqWrap.items?.[0]?.id,
    selectedCapabilities: reqWrap.selectedCapabilities ?? reqWrap.items?.[0]?.selectedCapabilities,
    stage: reqWrap.items?.[0]?.stage,
  };
  console.log('CREATE_REQUEST', createReq.status, req.id, req.stage, JSON.stringify(req.selectedCapabilities));
  const sseIn = await readUntil(reader, (j) => j.type === 'vendor_request_incoming', 4000);
  console.log('SSE_INCOMING', sseIn ? { type: sseIn.json.type, elapsedMs: sseIn.elapsedMs } : null);
  abort.abort();

  if (!req.id) {
    await pg.end();
    process.exit(1);
  }

  const orgAbort = new AbortController();
  const orgReader = await openSse(apiBase, orgToken, org.tenant_id, orgAbort.signal);
  await readUntil(orgReader, () => false, 300);

  const accept = await fetch(`${apiBase}/vendor-requests/${req.id}/stage`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${venToken}`,
      'X-Tenant-Id': ven.tenant_id,
    },
    body: JSON.stringify({ stage: 'accepted' }),
  });
  console.log('ACCEPT', accept.status);
  const sseAcc = await readUntil(orgReader, (j) => j.type === 'vendor_request_update', 4000);
  console.log('SSE_ACCEPT', sseAcc ? { type: sseAcc.json.type, elapsedMs: sseAcc.elapsedMs } : null);

  const msg = await fetch(`${apiBase}/vendor-requests/${req.id}/messages`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${venToken}`,
      'X-Tenant-Id': ven.tenant_id,
    },
    body: JSON.stringify({ message: 'QA structured CRM note' }),
  });
  console.log('MESSAGE', msg.status);
  const sseMsg = await readUntil(
    orgReader,
    (j) => j.type === 'vendor_request_message' || j.type === 'vendor_request_update',
    4000,
  );
  console.log('SSE_MESSAGE', sseMsg ? { type: sseMsg.json.type, elapsedMs: sseMsg.elapsedMs } : null);

  const venAbort2 = new AbortController();
  const venReader2 = await openSse(apiBase, venToken, ven.tenant_id, venAbort2.signal);
  await readUntil(venReader2, () => false, 300);

  const cr = await fetch(`${apiBase}/vendor-requests/${req.id}/change-requests`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': org.tenant_id,
    },
    body: JSON.stringify({ type: 'ADD_CAPABILITY', capabilityKey: 'speakers' }),
  });
  const crJson = (await cr.json()) as {
    id?: string;
    status?: string;
    originalSnapshot?: unknown;
    requestedPayload?: unknown;
  };
  console.log('CR_CREATE', cr.status, crJson.status, JSON.stringify(crJson.requestedPayload));
  const sseCr = await readUntil(venReader2, (j) => j.type === 'vendor_change_request_created', 4000);
  console.log('SSE_CR', sseCr ? { type: sseCr.json.type, elapsedMs: sseCr.elapsedMs } : null);

  const acceptCr = await fetch(`${apiBase}/change-requests/${crJson.id}/accept`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${venToken}`,
      'X-Tenant-Id': ven.tenant_id,
    },
  });
  console.log('CR_ACCEPT', acceptCr.status);
  const sseCrAcc = await readUntil(orgReader, (j) => j.type === 'vendor_change_request_accepted', 4000);
  console.log('SSE_CR_ACCEPT', sseCrAcc ? { type: sseCrAcc.json.type, elapsedMs: sseCrAcc.elapsedMs } : null);

  // Decline path
  const cr2 = await fetch(`${apiBase}/vendor-requests/${req.id}/change-requests`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': org.tenant_id,
    },
    body: JSON.stringify({
      type: 'SPECIAL_REQUIREMENT',
      requirement: 'Please provide an additional wireless microphone.',
    }),
  });
  const cr2Json = (await cr2.json()) as { id?: string; status?: string };
  console.log('CR_SPECIAL', cr2.status, cr2Json.status);
  const decline = await fetch(`${apiBase}/change-requests/${cr2Json.id}/decline`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${venToken}`,
      'X-Tenant-Id': ven.tenant_id,
    },
    body: JSON.stringify({ note: 'QA decline' }),
  });
  console.log('CR_DECLINE', decline.status);
  const sseDec = await readUntil(orgReader, (j) => j.type === 'vendor_change_request_declined', 4000);
  console.log('SSE_CR_DECLINE', sseDec ? { type: sseDec.json.type, elapsedMs: sseDec.elapsedMs } : null);

  // Venue
  const crV = await fetch(`${apiBase}/vendor-requests/${req.id}/change-requests`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': org.tenant_id,
    },
    body: JSON.stringify({ type: 'CHANGE_VENUE', venueName: 'QA Hall VI', venueAddress: 'Victoria Island' }),
  });
  const crVJson = (await crV.json()) as { id?: string };
  console.log('CR_VENUE', crV.status, crVJson.id);
  if (crVJson.id) {
    const accV = await fetch(`${apiBase}/change-requests/${crVJson.id}/accept`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${venToken}`, 'X-Tenant-Id': ven.tenant_id },
    });
    console.log('CR_VENUE_ACCEPT', accV.status);
  }

  // LED invalid (not provided)
  const crBad = await fetch(`${apiBase}/vendor-requests/${req.id}/change-requests`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': org.tenant_id,
    },
    body: JSON.stringify({ type: 'ADD_CAPABILITY', capabilityKey: 'led_screen' }),
  });
  console.log('CR_LED_REJECT', crBad.status, (await crBad.text()).slice(0, 180));

  const meta = (
    await pg.query(`SELECT metadata, stage FROM vendor_event_requests WHERE id=$1`, [req.id])
  ).rows[0];
  console.log('FINAL', JSON.stringify(meta).slice(0, 500));
  console.log(
    'FIXTURE_IDS',
    JSON.stringify({ eventId: event.id, requestId: req.id, changeRequestId: crJson.id, specialId: cr2Json.id }),
  );

  orgAbort.abort();
  venAbort2.abort();
  await pg.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
