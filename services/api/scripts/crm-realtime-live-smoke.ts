/**
 * Phase 3A live SSE smoke script.
 *
 * Usage (from services/api with API running):
 *   npx ts-node -r dotenv/config scripts/crm-realtime-live-smoke.ts
 *
 * Requires DATABASE_URL + SUPABASE_JWT_SECRET in env.
 * Proves: JWT auth → SSE connect → publishToUser → frame received.
 */
import { Client } from 'pg';
import * as jwt from 'jsonwebtoken';
import { createHash, randomUUID } from 'crypto';

async function main() {
  const databaseUrl = process.env.DATABASE_URL;
  const secret = process.env.SUPABASE_JWT_SECRET;
  const apiBase = process.env.PUBLIC_API_BASE_URL
    ? `${process.env.PUBLIC_API_BASE_URL.replace(/\/$/, '')}/v1`
    : 'http://127.0.0.1:8080/v1';

  if (!databaseUrl || !secret) {
    console.error('DATABASE_URL and SUPABASE_JWT_SECRET required');
    process.exit(1);
  }

  const pg = new Client({ connectionString: databaseUrl });
  await pg.connect();
  const { rows } = await pg.query<{
    user_id: string;
    tenant_id: string;
    email: string | null;
  }>(
    `SELECT u.id AS user_id, u.tenant_id, u.email
     FROM users u
     JOIN vendors v ON v.owner_user_id = u.id AND v.tenant_id = u.tenant_id
     WHERE u.tenant_id IS NOT NULL
     LIMIT 1`,
  );
  await pg.end();

  if (!rows.length) {
    console.error('No vendor owner user found for smoke test');
    process.exit(1);
  }

  const user = rows[0]!;
  const token = jwt.sign(
    {
      sub: user.user_id,
      email: user.email ?? 'crm-smoke@local.test',
      role: 'authenticated',
      app_metadata: { tenant_id: user.tenant_id, roles: ['vendor', 'client'] },
    },
    secret,
    { expiresIn: '10m', algorithm: 'HS256' },
  );

  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), 20_000);

  const res = await fetch(`${apiBase}/me/crm/stream`, {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${token}`,
      'X-Tenant-Id': user.tenant_id,
    },
    signal: abort.signal,
  });

  if (!res.ok || !res.body) {
    console.error('SSE connect failed', res.status, await res.text());
    process.exit(1);
  }
  console.log('crm_sse_connect ok', { tenantId: user.tenant_id, userId: user.user_id });

  // Trigger a local fan-out via internal HTTP is not available; use pg_notify mimicking service.
  const eventId = randomUUID();
  const envelope = {
    recipientUserId: user.user_id,
    envelope: {
      eventId,
      type: 'vendor_request_incoming',
      tenantId: user.tenant_id,
      resource: { type: 'vendor_request', id: randomUUID() },
      revision: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      dedupeKey: `vendor_request:smoke:${eventId}`,
      occurredAt: new Date().toISOString(),
      _source: 'smoke-script',
    },
  };

  const notifyPg = new Client({ connectionString: databaseUrl });
  await notifyPg.connect();
  await notifyPg.query(`SELECT pg_notify($1, $2)`, ['crm_realtime', JSON.stringify(envelope)]);
  await notifyPg.end();

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let sawConnected = false;
  let sawEvent = false;

  while (!sawEvent) {
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
      if (json.type === 'connected') {
        sawConnected = true;
        console.log('connected frame ok');
        continue;
      }
      if (json.eventId === eventId) {
        sawEvent = true;
        console.log('crm_realtime_deliver ok', {
          type: json.type,
          dedupeKey: json.dedupeKey,
        });
      }
    }
  }

  clearTimeout(timeout);
  abort.abort();

  if (!sawConnected || !sawEvent) {
    console.error('FAIL', { sawConnected, sawEvent });
    process.exit(1);
  }
  console.log('PASS Phase 3A SSE live smoke', {
    fingerprint: createHash('sha256').update(eventId).digest('hex').slice(0, 8),
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
