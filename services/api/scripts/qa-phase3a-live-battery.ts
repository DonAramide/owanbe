/**
 * QA: Organizer→Vendor SSE via stage cancel (createRequest blocked by missing custom_extras).
 * Also multi-session + reconnect recovery probes.
 */
import { Client } from 'pg';
import * as jwt from 'jsonwebtoken';
import { randomUUID } from 'crypto';

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

async function openSse(apiBase: string, token: string, tenantId: string, signal: AbortSignal) {
  const res = await fetch(`${apiBase}/me/crm/stream`, {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${token}`,
      'X-Tenant-Id': tenantId,
    },
    signal,
  });
  if (!res.ok || !res.body) throw new Error(`SSE ${res.status} ${await res.text()}`);
  return res.body.getReader();
}

async function readUntil(
  reader: ReadableStreamDefaultReader<Uint8Array>,
  pred: (json: Record<string, unknown>) => boolean,
  ms: number,
) {
  const decoder = new TextDecoder();
  let buffer = '';
  const deadline = Date.now() + ms;
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
      if (json.type === 'connected') continue;
      if (pred(json)) return json;
    }
  }
  return null;
}

async function main() {
  const apiBase = 'http://127.0.0.1:8080/v1';
  const secret = process.env.SUPABASE_JWT_SECRET!;
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();

  // Accounts inventory
  const accounts = await pg.query(
    `SELECT u.id, u.email, u.tenant_id,
            EXISTS(SELECT 1 FROM organizers o WHERE o.owner_user_id=u.id) AS is_org,
            EXISTS(SELECT 1 FROM vendors v WHERE v.owner_user_id=u.id) AS is_vendor
     FROM users u
     WHERE u.tenant_id = '11111111-1111-4111-8111-111111111111'
     ORDER BY u.email NULLS LAST
     LIMIT 20`,
  );
  console.log('ACCOUNTS', accounts.rows);

  const { rows: reqs } = await pg.query<{
    request_id: string;
    stage: string;
    tenant_id: string;
    vendor_user_id: string;
    organizer_user_id: string;
    vendor_email: string | null;
    organizer_email: string | null;
    event_id: string;
  }>(
    `SELECT r.id AS request_id, r.stage, r.tenant_id, r.event_id,
            v.owner_user_id AS vendor_user_id,
            o.owner_user_id AS organizer_user_id,
            vu.email AS vendor_email,
            ou.email AS organizer_email
     FROM vendor_event_requests r
     JOIN vendors v ON v.id = r.vendor_id
     JOIN organizers o ON o.id = r.organizer_id
     JOIN users vu ON vu.id = v.owner_user_id
     JOIN users ou ON ou.id = o.owner_user_id
     WHERE r.stage IN ('new', 'accepted')
       AND v.owner_user_id IS DISTINCT FROM o.owner_user_id
     ORDER BY r.updated_at DESC
     LIMIT 10`,
  );
  console.log('REQUESTS', reqs.map((r) => ({ id: r.request_id, stage: r.stage, eventId: r.event_id })));

  // --- Test E multi-session ---
  const vendorRow = reqs[0];
  if (!vendorRow) {
    console.log('NO_REQUESTS');
    await pg.end();
    process.exit(1);
  }
  const vRoles = await rolesFor(pg, vendorRow.vendor_user_id);
  const oRoles = await rolesFor(pg, vendorRow.organizer_user_id);
  const vToken = sign(
    secret,
    vendorRow.vendor_user_id,
    vendorRow.tenant_id,
    vendorRow.vendor_email ?? 'v@test',
    vRoles,
  );
  const oToken = sign(
    secret,
    vendorRow.organizer_user_id,
    vendorRow.tenant_id,
    vendorRow.organizer_email ?? 'o@test',
    oRoles,
  );

  const abortA = new AbortController();
  const abortB = new AbortController();
  const readerA = await openSse(apiBase, vToken, vendorRow.tenant_id, abortA.signal);
  const readerB = await openSse(apiBase, vToken, vendorRow.tenant_id, abortB.signal);
  await new Promise((r) => setTimeout(r, 400));

  const eventId = randomUUID();
  await pg.query(`SELECT pg_notify($1, $2)`, [
    'crm_realtime',
    JSON.stringify({
      recipientUserId: vendorRow.vendor_user_id,
      envelope: {
        eventId,
        type: 'vendor_request_incoming',
        tenantId: vendorRow.tenant_id,
        resource: { type: 'vendor_request', id: randomUUID() },
        revision: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        dedupeKey: `multisession:${eventId}`,
        occurredAt: new Date().toISOString(),
        _source: 'qa-multisession',
      },
    }),
  ]);

  const hitA = await readUntil(readerA, (j) => j.eventId === eventId, 5000);
  const hitB = await readUntil(readerB, (j) => j.eventId === eventId, 5000);
  abortA.abort();
  abortB.abort();
  console.log('TEST_E_MULTISESSION', hitA && hitB ? 'PASS' : 'FAIL', {
    sessionA: !!hitA,
    sessionB: !!hitB,
  });

  // --- Organizer → Vendor via cancel if stage=new exists ---
  const newReq = reqs.find((r) => r.stage === 'new');
  if (newReq) {
    const abortV = new AbortController();
    const readerV = await openSse(apiBase, vToken, newReq.tenant_id, abortV.signal);
    await new Promise((r) => setTimeout(r, 400));
    const cancelRes = await fetch(`${apiBase}/vendor-requests/${newReq.request_id}/stage`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${oToken}`,
        'X-Tenant-Id': newReq.tenant_id,
      },
      body: JSON.stringify({ stage: 'cancelled', note: 'QA org→vendor SSE' }),
    });
    const cancelBody = await cancelRes.text();
    console.log('CANCEL_HTTP', cancelRes.status, cancelBody.slice(0, 200));
    const got = await readUntil(
      readerV,
      (j) => j.type === 'vendor_request_update' && (j.resource as { id?: string })?.id === newReq.request_id,
      8000,
    );
    abortV.abort();
    console.log('TEST_A_PROXY_ORG_TO_VENDOR', got ? 'PASS' : 'FAIL', {
      requestId: newReq.request_id,
      type: got?.type,
      dedupeKey: got?.dedupeKey,
    });
  } else {
    console.log('TEST_A_PROXY_ORG_TO_VENDOR', 'BLOCKED', 'no stage=new request');
  }

  // --- Decline path if another new exists, else accept then we already proved ---
  const declineCandidate = (
    await pg.query<{
      request_id: string;
      tenant_id: string;
      vendor_user_id: string;
      organizer_user_id: string;
      vendor_email: string | null;
      organizer_email: string | null;
    }>(
      `SELECT r.id AS request_id, r.tenant_id,
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
    )
  ).rows[0];

  if (declineCandidate) {
    const dVRoles = await rolesFor(pg, declineCandidate.vendor_user_id);
    const dORoles = await rolesFor(pg, declineCandidate.organizer_user_id);
    const dVToken = sign(
      secret,
      declineCandidate.vendor_user_id,
      declineCandidate.tenant_id,
      declineCandidate.vendor_email ?? 'v@test',
      dVRoles,
    );
    const dOToken = sign(
      secret,
      declineCandidate.organizer_user_id,
      declineCandidate.tenant_id,
      declineCandidate.organizer_email ?? 'o@test',
      dORoles,
    );
    const abortO = new AbortController();
    const readerO = await openSse(apiBase, dOToken, declineCandidate.tenant_id, abortO.signal);
    await new Promise((r) => setTimeout(r, 400));
    const dec = await fetch(`${apiBase}/vendor-requests/${declineCandidate.request_id}/stage`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${dVToken}`,
        'X-Tenant-Id': declineCandidate.tenant_id,
      },
      body: JSON.stringify({ stage: 'declined', note: 'QA decline SSE' }),
    });
    console.log('DECLINE_HTTP', dec.status);
    const got = await readUntil(
      readerO,
      (j) =>
        j.type === 'vendor_request_update' &&
        (j.resource as { id?: string })?.id === declineCandidate.request_id,
      8000,
    );
    abortO.abort();
    console.log('TEST_C_DECLINE', got ? 'PASS' : 'FAIL', {
      requestId: declineCandidate.request_id,
      type: got?.type,
      stage: (got?.meta as { stage?: string } | undefined)?.stage,
    });
  } else {
    console.log('TEST_C_DECLINE', 'BLOCKED', 'no remaining stage=new request');
  }

  await pg.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
