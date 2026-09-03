/**
 * Phase 3B focused: create incoming + decline update (fresh fixtures).
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

  const org = (
    await pg.query<{ id: string; email: string; tenant_id: string }>(
      `SELECT id, email, tenant_id FROM users WHERE email='organizer@owanbe.dev'`,
    )
  ).rows[0]!;

  // Pick two distinct vendor services on different vendors for create + decline
  const { rows: svcs } = await pg.query<{
    service_id: string;
    vendor_id: string;
    service_key: string;
    service_name: string;
    vendor_user_id: string;
    vendor_email: string | null;
  }>(
    `SELECT vs.id AS service_id, vs.vendor_id, vs.service_key, vs.service_name,
            v.owner_user_id AS vendor_user_id, u.email AS vendor_email
     FROM vendor_services vs
     JOIN vendors v ON v.id = vs.vendor_id
     JOIN users u ON u.id = v.owner_user_id
     WHERE vs.status = 'active' AND v.owner_user_id IS DISTINCT FROM $1
     ORDER BY vs.updated_at DESC
     LIMIT 2`,
    [org.id],
  );
  const eventId = (
    await pg.query<{ id: string }>(
      `SELECT e.id FROM events e JOIN organizers o ON o.id=e.organizer_id WHERE o.owner_user_id=$1 LIMIT 1`,
      [org.id],
    )
  ).rows[0]!.id;

  const orgToken = sign(secret, org.id, org.tenant_id, org.email, await rolesFor(pg, org.id));
  let fails = 0;

  for (const [label, stageTarget, svc] of [
    ['create', 'incoming', svcs[0]!],
    ['decline_setup', 'decline', svcs[1] ?? svcs[0]!],
  ] as const) {
    const venToken = sign(
      secret,
      svc.vendor_user_id,
      org.tenant_id,
      svc.vendor_email ?? 'v@test',
      await rolesFor(pg, svc.vendor_user_id),
    );

    if (label === 'create') {
      const abort = new AbortController();
      const reader = await openSse(apiBase, venToken, org.tenant_id, abort.signal);
      await new Promise((r) => setTimeout(r, 300));
      const res = await fetch(`${apiBase}/events/${eventId}/vendor-requests`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${orgToken}`,
          'X-Tenant-Id': org.tenant_id,
        },
        body: JSON.stringify({
          vendorId: svc.vendor_id,
          vendorServiceId: svc.service_id,
          serviceKey: svc.service_key,
          serviceLabel: svc.service_name,
          message: `Phase 3B ${label}`,
          source: 'marketplace',
        }),
      });
      const body = await res.json();
      const requestId = (body.items as Array<{ id: string; vendorId: string }> | undefined)?.find(
        (i) => i.vendorId === svc.vendor_id,
      )?.id;
      const got = await readUntil(
        reader,
        (j) =>
          j.type === 'vendor_request_incoming' &&
          (!requestId || (j.resource as { id?: string })?.id === requestId),
        12000,
      );
      abort.abort();
      console.log(res.ok && got ? 'PASS' : 'FAIL', 'create→incoming', {
        status: res.status,
        requestId,
        type: got?.type,
      });
      if (!(res.ok && got)) fails++;
    } else {
      // Ensure a stage=new request for this vendor+event (reset if needed)
      await pg.query(
        `UPDATE vendor_event_requests SET stage='new', updated_at=now()
         WHERE tenant_id=$1 AND event_id=$2 AND vendor_id=$3 AND service_key=$4`,
        [org.tenant_id, eventId, svc.vendor_id, svc.service_key],
      );
      // Create/upsert to new
      await fetch(`${apiBase}/events/${eventId}/vendor-requests`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${orgToken}`,
          'X-Tenant-Id': org.tenant_id,
        },
        body: JSON.stringify({
          vendorId: svc.vendor_id,
          vendorServiceId: svc.service_id,
          serviceKey: svc.service_key,
          serviceLabel: svc.service_name,
          message: 'Phase 3B decline fixture',
          source: 'marketplace',
        }),
      });
      const { rows } = await pg.query<{ id: string }>(
        `SELECT id FROM vendor_event_requests
         WHERE tenant_id=$1 AND event_id=$2 AND vendor_id=$3 AND service_key=$4 AND stage='new'
         LIMIT 1`,
        [org.tenant_id, eventId, svc.vendor_id, svc.service_key],
      );
      const requestId = rows[0]?.id;
      if (!requestId) {
        console.log('FAIL decline — no new request fixture');
        fails++;
        continue;
      }
      const abort = new AbortController();
      const reader = await openSse(apiBase, orgToken, org.tenant_id, abort.signal);
      await new Promise((r) => setTimeout(r, 300));
      const res = await fetch(`${apiBase}/vendor-requests/${requestId}/stage`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${venToken}`,
          'X-Tenant-Id': org.tenant_id,
        },
        body: JSON.stringify({ stage: 'declined', note: '3B decline' }),
      });
      const got = await readUntil(
        reader,
        (j) => j.type === 'vendor_request_update' && (j.resource as { id?: string })?.id === requestId,
        12000,
      );
      abort.abort();
      console.log(res.ok && got ? 'PASS' : 'FAIL', 'decline→update', {
        status: res.status,
        requestId,
        type: got?.type,
      });
      if (!(res.ok && got)) fails++;
    }
  }

  await pg.end();
  console.log(fails === 0 ? 'CREATE_DECLINE_PASS' : `CREATE_DECLINE_FAILS=${fails}`);
  process.exit(fails === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
