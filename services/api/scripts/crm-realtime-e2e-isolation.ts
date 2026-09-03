/**
 * Isolation: wrong user must not receive CRM SSE events for another user's room.
 * npx --yes tsx -r dotenv/config scripts/crm-realtime-e2e-isolation.ts
 */
import { Client } from 'pg';
import * as jwt from 'jsonwebtoken';
import { randomUUID } from 'crypto';

function sign(secret: string, userId: string, tenantId: string, roles: string[]) {
  return jwt.sign(
    {
      sub: userId,
      email: 'iso@test.local',
      role: 'authenticated',
      app_metadata: { tenant_id: tenantId, roles },
    },
    secret,
    { expiresIn: '10m', algorithm: 'HS256' },
  );
}

async function main() {
  const pg = new Client({ connectionString: process.env.DATABASE_URL });
  await pg.connect();
  const { rows } = await pg.query<{
    tenant_id: string;
    user_a: string;
    user_b: string;
  }>(
    `SELECT a.tenant_id, a.id AS user_a, b.id AS user_b
     FROM users a
     JOIN users b ON b.tenant_id = a.tenant_id AND b.id <> a.id
     LIMIT 1`,
  );
  await pg.end();
  if (!rows.length) {
    console.error('need two users');
    process.exit(1);
  }
  const f = rows[0]!;
  const secret = process.env.SUPABASE_JWT_SECRET!;
  const tokenB = sign(secret, f.user_b, f.tenant_id, ['vendor']);

  const abort = new AbortController();
  const sse = await fetch('http://127.0.0.1:8080/v1/me/crm/stream', {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${tokenB}`,
      'X-Tenant-Id': f.tenant_id,
    },
    signal: abort.signal,
  });
  if (!sse.ok || !sse.body) {
    console.error('SSE fail', sse.status);
    process.exit(1);
  }

  const eventId = randomUUID();
  const notify = new Client({ connectionString: process.env.DATABASE_URL });
  await notify.connect();
  // Publish to user A only
  await notify.query(`SELECT pg_notify($1, $2)`, [
    'crm_realtime',
    JSON.stringify({
      recipientUserId: f.user_a,
      envelope: {
        eventId,
        type: 'vendor_request_incoming',
        tenantId: f.tenant_id,
        resource: { type: 'vendor_request', id: randomUUID() },
        revision: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        dedupeKey: `iso:${eventId}`,
        occurredAt: new Date().toISOString(),
        _source: 'isolation-script',
      },
    }),
  ]);
  await notify.end();

  const reader = sse.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let leaked = false;
  const deadline = Date.now() + 3500;
  try {
    while (Date.now() < deadline) {
      const remaining = Math.max(50, deadline - Date.now());
      const readPromise = reader.read();
      const timed = await Promise.race([
        readPromise.then((r) => ({ kind: 'read' as const, r })),
        new Promise<{ kind: 'timeout' }>((resolve) =>
          setTimeout(() => resolve({ kind: 'timeout' }), remaining),
        ),
      ]);
      if (timed.kind === 'timeout') break;
      const { done, value } = timed.r;
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      if (buffer.includes(eventId)) {
        leaked = true;
        break;
      }
    }
  } finally {
    abort.abort();
  }
  if (leaked) {
    console.error('FAIL: wrong user received event');
    process.exit(1);
  }
  console.log('PASS isolation — wrong user received nothing');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
