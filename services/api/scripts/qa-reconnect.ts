/**
 * QA Test F: disconnect SSE, mutate while down, reconnect → REST recovery required.
 * Simulates client reconnect contract: after reconnect, fetch REST snapshot.
 */
import { Client } from 'pg';
import * as jwt from 'jsonwebtoken';

function sign(secret: string, userId: string, tenantId: string, roles: string[]) {
  return jwt.sign(
    {
      sub: userId,
      email: 'qa@test.local',
      role: 'authenticated',
      app_metadata: { tenant_id: tenantId, roles },
    },
    secret,
    { expiresIn: '15m', algorithm: 'HS256' },
  );
}

async function main() {
  const apiBase = 'http://127.0.0.1:8080/v1';
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();
  const { rows } = await pg.query<{
    request_id: string;
    tenant_id: string;
    vendor_id: string;
    vendor_user_id: string;
    organizer_user_id: string;
    stage: string;
  }>(
    `SELECT r.id AS request_id, r.tenant_id, r.vendor_id, r.stage,
            v.owner_user_id AS vendor_user_id,
            o.owner_user_id AS organizer_user_id
     FROM vendor_event_requests r
     JOIN vendors v ON v.id = r.vendor_id
     JOIN organizers o ON o.id = r.organizer_id
     WHERE r.stage = 'accepted'
       AND v.owner_user_id IS DISTINCT FROM o.owner_user_id
     ORDER BY r.updated_at DESC
     LIMIT 1`,
  );
  if (!rows.length) {
    console.log('BLOCKED no accepted request');
    await pg.end();
    process.exit(1);
  }
  const f = rows[0]!;
  const { rows: vr } = await pg.query<{ code: string }>(
    `SELECT r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id=$1`,
    [f.organizer_user_id],
  );
  const { rows: vv } = await pg.query<{ code: string }>(
    `SELECT r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id=$1`,
    [f.vendor_user_id],
  );
  await pg.end();

  const secret = process.env.SUPABASE_JWT_SECRET!;
  const orgToken = sign(secret, f.organizer_user_id, f.tenant_id, vr.map((x) => x.code));
  const vendorToken = sign(secret, f.vendor_user_id, f.tenant_id, vv.map((x) => x.code));

  // 1) Connect organizer SSE
  const abort1 = new AbortController();
  const sse1 = await fetch(`${apiBase}/me/crm/stream`, {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': f.tenant_id,
    },
    signal: abort1.signal,
  });
  if (!sse1.ok) {
    console.log('FAIL connect', sse1.status);
    process.exit(1);
  }
  console.log('sse_connected');

  // 2) Disconnect
  abort1.abort();
  console.log('sse_disconnected');
  await new Promise((r) => setTimeout(r, 300));

  // 3) Mutate while disconnected (vendor posts message if allowed, else stage note via arrived)
  // Prefer message on accepted
  const mut = await fetch(`${apiBase}/vendor-requests/${f.request_id}/messages`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${vendorToken}`,
      'X-Tenant-Id': f.tenant_id,
    },
    body: JSON.stringify({ message: 'QA reconnect recovery message — platform only' }),
  });
  console.log('mutate_while_down', mut.status, (await mut.text()).slice(0, 120));

  // 4) Reconnect
  const abort2 = new AbortController();
  const sse2 = await fetch(`${apiBase}/me/crm/stream`, {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': f.tenant_id,
    },
    signal: abort2.signal,
  });
  console.log('sse_reconnected', sse2.status);

  // 5) REST recovery (mandatory per Phase 3A client contract)
  const rest = await fetch(`${apiBase}/events/${encodeURIComponent(
    (
      await (
        await fetch(`${apiBase}/vendor-requests/${f.request_id}/timeline`, {
          headers: {
            Authorization: `Bearer ${orgToken}`,
            'X-Tenant-Id': f.tenant_id,
          },
        })
      ).json() as { request?: { eventId?: string } }
    ).request?.eventId ?? ''
  )}/vendor-requests`, {
    headers: {
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': f.tenant_id,
    },
  });

  // Simpler: timeline REST
  const timeline = await fetch(`${apiBase}/vendor-requests/${f.request_id}/timeline`, {
    headers: {
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': f.tenant_id,
    },
  });
  const tl = await timeline.json();
  const history = (tl.history as Array<{ note?: string }>) ?? [];
  const sawMsg = history.some((h) => (h.note ?? '').includes('QA reconnect recovery'));
  abort2.abort();

  console.log('TEST_F_RECONNECT', sse2.ok && sawMsg ? 'PASS' : 'FAIL', {
    sseReconnectOk: sse2.ok,
    restRecoverySawMutation: sawMsg,
    timelineStatus: timeline.status,
    mutateStatus: mut.status,
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
