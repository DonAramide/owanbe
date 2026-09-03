/**
 * Phase 3B lifecycle SSE coverage:
 * create, accept, decline, message, patch update, mark-complete
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

function result(name: string, ok: boolean, detail: Record<string, unknown> = {}) {
  console.log(ok ? 'PASS' : 'FAIL', name, detail);
  return ok;
}

async function main() {
  const apiBase = 'http://127.0.0.1:8080/v1';
  const secret = process.env.SUPABASE_JWT_SECRET!;
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();

  const { rows: users } = await pg.query<{ id: string; email: string; tenant_id: string }>(
    `SELECT id, email, tenant_id FROM users WHERE email IN ('organizer@owanbe.dev','vendor@owanbe.dev')`,
  );
  const org = users.find((u) => u.email === 'organizer@owanbe.dev')!;
  const ven = users.find((u) => u.email === 'vendor@owanbe.dev')!;
  const orgRoles = await rolesFor(pg, org.id);
  const venRoles = await rolesFor(pg, ven.id);
  const orgToken = sign(secret, org.id, org.tenant_id, org.email, orgRoles);
  const venToken = sign(secret, ven.id, ven.tenant_id, ven.email, venRoles);

  const { rows: events } = await pg.query<{ id: string }>(
    `SELECT e.id FROM events e JOIN organizers o ON o.id = e.organizer_id WHERE o.owner_user_id = $1 LIMIT 1`,
    [org.id],
  );
  const { rows: services } = await pg.query<{ id: string; vendor_id: string; service_key: string; service_name: string }>(
    `SELECT vs.id, vs.vendor_id, vs.service_key, vs.service_name
     FROM vendor_services vs JOIN vendors v ON v.id = vs.vendor_id
     WHERE v.owner_user_id = $1 AND vs.status = 'active' LIMIT 1`,
    [ven.id],
  );
  const eventId = events[0]!.id;
  const service = services[0]!;

  let fails = 0;

  // 1) Create → vendor incoming
  {
    const abort = new AbortController();
    const reader = await openSse(apiBase, venToken, ven.tenant_id, abort.signal);
    await new Promise((r) => setTimeout(r, 300));
    const createRes = await fetch(`${apiBase}/events/${eventId}/vendor-requests`, {
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
        message: 'Phase 3B lifecycle create',
        source: 'marketplace',
      }),
    });
    const body = await createRes.json();
    const requestId = (body.items as Array<{ id: string; vendorId: string; stage: string }>)?.find(
      (i) => i.vendorId === service.vendor_id,
    )?.id;
    const got = await readUntil(
      reader,
      (j) => j.type === 'vendor_request_incoming' && (j.resource as { id?: string })?.id === requestId,
      10000,
    );
    abort.abort();
    if (!result('create→vendor_request_incoming', createRes.ok && !!got, { requestId, type: got?.type })) fails++;
  }

  // Resolve a new request for accept/decline/message paths
  const { rows: newReqs } = await pg.query<{ id: string }>(
    `SELECT id FROM vendor_event_requests
     WHERE tenant_id = $1 AND vendor_id = $2 AND stage = 'new'
     ORDER BY updated_at DESC LIMIT 2`,
    [org.tenant_id, service.vendor_id],
  );
  const acceptId = newReqs[0]?.id;
  const declineId = newReqs[1]?.id;

  // 2) Accept → organizer update
  if (acceptId) {
    const abort = new AbortController();
    const reader = await openSse(apiBase, orgToken, org.tenant_id, abort.signal);
    await new Promise((r) => setTimeout(r, 300));
    const res = await fetch(`${apiBase}/vendor-requests/${acceptId}/stage`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${venToken}`,
        'X-Tenant-Id': ven.tenant_id,
      },
      body: JSON.stringify({ stage: 'accepted', note: '3B accept' }),
    });
    const got = await readUntil(
      reader,
      (j) => j.type === 'vendor_request_update' && (j.resource as { id?: string })?.id === acceptId,
      10000,
    );
    abort.abort();
    if (!result('accept→vendor_request_update', res.ok && !!got, { requestId: acceptId, type: got?.type })) fails++;

    // 3) Message → organizer
    {
      const abortM = new AbortController();
      const readerM = await openSse(apiBase, orgToken, org.tenant_id, abortM.signal);
      await new Promise((r) => setTimeout(r, 300));
      const msgRes = await fetch(`${apiBase}/vendor-requests/${acceptId}/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${venToken}`,
          'X-Tenant-Id': ven.tenant_id,
        },
        body: JSON.stringify({ message: 'Phase 3B structured CRM message — platform only' }),
      });
      const gotM = await readUntil(
        readerM,
        (j) => j.type === 'vendor_request_message' && (j.resource as { id?: string })?.id === acceptId,
        10000,
      );
      abortM.abort();
      if (!result('message→vendor_request_message', msgRes.ok && !!gotM, { requestId: acceptId, type: gotM?.type }))
        fails++;
    }

    // 4) Patch update → vendor
    {
      const abortP = new AbortController();
      const readerP = await openSse(apiBase, venToken, ven.tenant_id, abortP.signal);
      await new Promise((r) => setTimeout(r, 300));
      const patchRes = await fetch(`${apiBase}/vendor-requests/${acceptId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${orgToken}`,
          'X-Tenant-Id': org.tenant_id,
        },
        body: JSON.stringify({ message: 'Phase 3B organizer patch update' }),
      });
      const gotP = await readUntil(
        readerP,
        (j) => j.type === 'vendor_request_update' && (j.resource as { id?: string })?.id === acceptId,
        10000,
      );
      abortP.abort();
      if (!result('patch→vendor_request_update', patchRes.ok && !!gotP, { requestId: acceptId, type: gotP?.type }))
        fails++;
    }

    // 5) mark-complete → organizer vendor_service_complete (need arrived-friendly stage)
    // transition to arrived first if needed for mark-complete business rules — markServiceComplete sets arrived
    {
      const abortC = new AbortController();
      const readerC = await openSse(apiBase, orgToken, org.tenant_id, abortC.signal);
      await new Promise((r) => setTimeout(r, 300));
      const completeRes = await fetch(`${apiBase}/vendor-requests/${acceptId}/mark-complete`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${venToken}`,
          'X-Tenant-Id': ven.tenant_id,
        },
      });
      const gotC = await readUntil(
        readerC,
        (j) =>
          j.type === 'vendor_service_complete' && (j.resource as { id?: string })?.id === acceptId,
        10000,
      );
      abortC.abort();
      if (
        !result('mark-complete→vendor_service_complete', completeRes.ok && !!gotC, {
          requestId: acceptId,
          status: completeRes.status,
          type: gotC?.type,
        })
      )
        fails++;
    }
  } else {
    console.log('FAIL accept/message/patch/complete skipped — no new request');
    fails += 4;
  }

  // 6) Decline → organizer
  if (declineId) {
    const abort = new AbortController();
    const reader = await openSse(apiBase, orgToken, org.tenant_id, abort.signal);
    await new Promise((r) => setTimeout(r, 300));
    const res = await fetch(`${apiBase}/vendor-requests/${declineId}/stage`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${venToken}`,
        'X-Tenant-Id': ven.tenant_id,
      },
      body: JSON.stringify({ stage: 'declined', note: '3B decline' }),
    });
    const got = await readUntil(
      reader,
      (j) => j.type === 'vendor_request_update' && (j.resource as { id?: string })?.id === declineId,
      10000,
    );
    abort.abort();
    if (!result('decline→vendor_request_update', res.ok && !!got, { requestId: declineId, type: got?.type })) fails++;
  } else {
    console.log('FAIL decline skipped — need second new request');
    fails++;
  }

  // Isolation quick check
  {
    const other = await pg.query<{ id: string; tenant_id: string }>(
      `SELECT id, tenant_id FROM users WHERE id NOT IN ($1,$2) AND tenant_id = $3 LIMIT 1`,
      [org.id, ven.id, org.tenant_id],
    );
    if (other.rows[0]) {
      const oRoles = await rolesFor(pg, other.rows[0].id);
      const oToken = sign(secret, other.rows[0].id, other.rows[0].tenant_id, 'other@test', oRoles);
      const abort = new AbortController();
      const reader = await openSse(apiBase, oToken, other.rows[0].tenant_id, abort.signal);
      await new Promise((r) => setTimeout(r, 200));
      // create another request; other user must not see
      await fetch(`${apiBase}/events/${eventId}/vendor-requests`, {
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
          message: '3B isolation create',
          source: 'marketplace',
        }),
      });
      const leaked = await readUntil(reader, (j) => j.type === 'vendor_request_incoming', 3500);
      abort.abort();
      if (!result('wrong-user isolation', !leaked, { leaked: !!leaked })) fails++;
    }
  }

  await pg.end();
  console.log(fails === 0 ? 'PHASE_3B_LIFECYCLE_ALL_PASS' : `PHASE_3B_LIFECYCLE_FAILS=${fails}`);
  process.exit(fails === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
