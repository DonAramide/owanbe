/**
 * INVESTIGATION ONLY — SSE emit → receive diagnosis.
 * Does not modify product code or schema.
 *
 * Critical harness fix vs prior probe:
 * Never abandon an in-flight ReadableStreamDefaultReader.read() via Promise.race timeout.
 * Use a continuous pump into a queue; waiters only poll the queue.
 */
import { Client } from 'pg';
import * as jwt from 'jsonwebtoken';
import { createHash } from 'crypto';

type Frame = { raw: string; json: Record<string, unknown> | null; at: number };

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

function tokenFingerprint(token: string) {
  return createHash('sha256').update(token).digest('hex').slice(0, 12);
}

class SseSession {
  readonly frames: Frame[] = [];
  status = 0;
  connectedJson: Record<string, unknown> | null = null;
  done = false;
  error: string | null = null;
  private buffer = '';
  private decoder = new TextDecoder();
  private pumpPromise: Promise<void> | null = null;

  constructor(
    readonly label: string,
    readonly userId: string,
    readonly tenantId: string,
    readonly expectedRoom: string,
  ) {}

  async connect(apiBase: string, token: string, signal: AbortSignal) {
    const res = await fetch(`${apiBase}/me/crm/stream`, {
      headers: {
        Accept: 'text/event-stream',
        Authorization: `Bearer ${token}`,
        'X-Tenant-Id': this.tenantId,
      },
      signal,
    });
    this.status = res.status;
    if (!res.ok || !res.body) {
      this.error = `SSE HTTP ${res.status} ${await res.text()}`;
      return;
    }
    const reader = res.body.getReader();
    this.pumpPromise = this.pump(reader);
  }

  private async pump(reader: ReadableStreamDefaultReader<Uint8Array>) {
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) {
          this.done = true;
          return;
        }
        this.buffer += this.decoder.decode(value, { stream: true });
        while (true) {
          const sep = this.buffer.indexOf('\n\n');
          if (sep < 0) break;
          const frame = this.buffer.slice(0, sep);
          this.buffer = this.buffer.slice(sep + 2);
          const data = frame
            .split('\n')
            .filter((l) => l.startsWith('data:'))
            .map((l) => l.slice(5).trimStart())
            .join('\n');
          if (!data) {
            // comment/ping frames (: ping) — keep connection alive; record lightly
            if (frame.trim().startsWith(':')) {
              this.frames.push({ raw: frame, json: { type: '_comment' }, at: Date.now() });
            }
            continue;
          }
          let json: Record<string, unknown> | null = null;
          try {
            json = JSON.parse(data) as Record<string, unknown>;
          } catch {
            json = null;
          }
          const f: Frame = { raw: data, json, at: Date.now() };
          this.frames.push(f);
          if (json?.type === 'connected' && !this.connectedJson) {
            this.connectedJson = json;
          }
        }
      }
    } catch (e) {
      if ((e as Error).name === 'AbortError') {
        this.done = true;
        return;
      }
      this.error = String(e);
      this.done = true;
    }
  }

  async waitConnected(ms: number) {
    const deadline = Date.now() + ms;
    while (Date.now() < deadline) {
      if (this.connectedJson) return this.connectedJson;
      if (this.error) throw new Error(this.error);
      await new Promise((r) => setTimeout(r, 25));
    }
    return null;
  }

  async waitFor(
    pred: (json: Record<string, unknown>) => boolean,
    ms: number,
    afterAt = 0,
  ): Promise<{ json: Record<string, unknown>; elapsedMs: number; eventId?: string; dedupeKey?: string } | null> {
    const start = Date.now();
    const deadline = start + ms;
    while (Date.now() < deadline) {
      for (const f of this.frames) {
        if (f.at < afterAt) continue;
        if (!f.json) continue;
        if (f.json.type === 'connected' || f.json.type === '_comment') continue;
        if (pred(f.json)) {
          return {
            json: f.json,
            elapsedMs: f.at - start,
            eventId: f.json.eventId?.toString(),
            dedupeKey: f.json.dedupeKey?.toString(),
          };
        }
      }
      if (this.error) throw new Error(this.error);
      await new Promise((r) => setTimeout(r, 25));
    }
    return null;
  }

  businessFrames() {
    return this.frames.filter(
      (f) => f.json && f.json.type !== 'connected' && f.json.type !== '_comment',
    );
  }
}

function room(tenantId: string, userId: string) {
  return `crm:${tenantId}:user:${userId}`;
}

async function main() {
  const apiBase = 'http://127.0.0.1:8080/v1';
  const secret = process.env.SUPABASE_JWT_SECRET!;
  const dbUrl = process.env.DATABASE_URL!;
  const pg = new Client({ connectionString: dbUrl });
  await pg.connect();

  const report: Record<string, unknown> = {
    classification: null,
    harness: {},
    steps: {},
  };

  // Independent LISTEN observer (proves NOTIFY reaches Postgres clients)
  const listenPg = new Client({ connectionString: dbUrl });
  await listenPg.connect();
  let notifyCount = 0;
  const notifies: Array<{ at: number; payloadLen: number; type?: string; recipientUserId?: string }> = [];
  await listenPg.query('LISTEN crm_realtime');
  listenPg.on('notification', (msg) => {
    if (msg.channel !== 'crm_realtime' || !msg.payload) return;
    notifyCount += 1;
    try {
      const parsed = JSON.parse(msg.payload) as {
        recipientUserId?: string;
        envelope?: { type?: string };
      };
      notifies.push({
        at: Date.now(),
        payloadLen: msg.payload.length,
        type: parsed.envelope?.type,
        recipientUserId: parsed.recipientUserId,
      });
    } catch {
      notifies.push({ at: Date.now(), payloadLen: msg.payload.length });
    }
  });

  const listeners = await pg.query<{ pid: number; query: string; state: string }>(
    `SELECT pid, state, query FROM pg_stat_activity
     WHERE datname = current_database()
       AND query ILIKE '%LISTEN%crm_realtime%'`,
  );
  report.steps = {
    ...(report.steps as object),
    pgListenActivity: listeners.rows,
  };

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
  const other = (
    await pg.query<{ id: string; email: string; tenant_id: string }>(
      `SELECT id, email, tenant_id FROM users
       WHERE email NOT IN ('organizer@owanbe.dev','vendor@owanbe.dev')
         AND tenant_id=$1 LIMIT 1`,
      [org.tenant_id],
    )
  ).rows[0];

  const orgRoles = await rolesFor(pg, org.id);
  const venRoles = await rolesFor(pg, ven.id);
  const orgToken = sign(secret, org.id, org.tenant_id, org.email, orgRoles);
  const venToken = sign(secret, ven.id, ven.tenant_id, ven.email, venRoles);
  const otherToken = other
    ? sign(secret, other.id, other.tenant_id, other.email, await rolesFor(pg, other.id))
    : null;

  const vendor = (
    await pg.query<{ id: string }>(`SELECT id FROM vendors WHERE owner_user_id=$1`, [ven.id])
  ).rows[0]!;
  const svc = (
    await pg.query<{ id: string; service_key: string; service_name: string }>(
      `SELECT id, service_key, service_name FROM vendor_services
       WHERE vendor_id=$1 AND status='active'
         AND (lower(service_key) LIKE '%dj%' OR lower(service_name) LIKE '%dj%')
       LIMIT 1`,
      [vendor.id],
    )
  ).rows[0]!;

  report.harness = {
    apiBase,
    orgUserId: org.id,
    venUserId: ven.id,
    orgTenantId: org.tenant_id,
    venTenantId: ven.tenant_id,
    orgRoom: room(org.tenant_id, org.id),
    venRoom: room(ven.tenant_id, ven.id),
    orgTokenFp: tokenFingerprint(orgToken),
    venTokenFp: tokenFingerprint(venToken),
    note: 'Tokens fingerprinted only; secrets not printed',
    priorProbeBug:
      'Previous clean probe abandoned in-flight reader.read() via Promise.race timeout, which can drop the next SSE chunk into an orphaned promise — classic harness defect.',
  };

  // --- Open SSE BEFORE mutation (continuous pump) ---
  const vendorA = new AbortController();
  const vendorB = new AbortController();
  const orgAbort = new AbortController();
  const otherAbort = new AbortController();

  const sessA = new SseSession('vendorA', ven.id, ven.tenant_id, room(ven.tenant_id, ven.id));
  const sessB = new SseSession('vendorB', ven.id, ven.tenant_id, room(ven.tenant_id, ven.id));
  const sessOrg = new SseSession('organizer', org.id, org.tenant_id, room(org.tenant_id, org.id));
  const sessOther = otherToken
    ? new SseSession('other', other!.id, other!.tenant_id, room(other!.tenant_id, other!.id))
    : null;

  await sessA.connect(apiBase, venToken, vendorA.signal);
  await sessB.connect(apiBase, venToken, vendorB.signal);
  await sessOrg.connect(apiBase, orgToken, orgAbort.signal);
  if (sessOther && otherToken) await sessOther.connect(apiBase, otherToken, otherAbort.signal);

  const connectedA = await sessA.waitConnected(5000);
  const connectedB = await sessB.waitConnected(5000);
  const connectedOrg = await sessOrg.waitConnected(5000);
  const connectedOther = sessOther ? await sessOther.waitConnected(5000) : null;

  report.steps = {
    ...(report.steps as object),
    sseConnect: {
      vendorA: {
        http: sessA.status,
        connected: connectedA,
        channelMatch: connectedA?.channel === sessA.expectedRoom,
        error: sessA.error,
      },
      vendorB: {
        http: sessB.status,
        connected: connectedB,
        channelMatch: connectedB?.channel === sessB.expectedRoom,
        error: sessB.error,
      },
      organizer: {
        http: sessOrg.status,
        connected: connectedOrg,
        channelMatch: connectedOrg?.channel === sessOrg.expectedRoom,
        error: sessOrg.error,
      },
      other: sessOther
        ? {
            http: sessOther.status,
            connected: !!connectedOther,
            channelMatch: connectedOther?.channel === sessOther.expectedRoom,
          }
        : 'no other user',
    },
  };

  if (!connectedA || sessA.status !== 200) {
    report.classification = 'C. INCONCLUSIVE — MORE EVIDENCE REQUIRED';
    report.reason = 'Vendor SSE failed to connect; cannot diagnose delivery';
    console.log(JSON.stringify(report, null, 2));
    await cleanup();
    process.exit(2);
  }

  // Mark timeline: only count frames after this
  const mark = Date.now();
  await new Promise((r) => setTimeout(r, 200)); // settle

  // --- Controlled mutation 1: create request on clean future event ---
  const starts = new Date(Date.now() + 110 * 86400e3);
  starts.setUTCHours(16, 0, 0, 0);
  const ends = new Date(starts.getTime() + 4 * 3600e3);
  const evRes = await fetch(`${apiBase}/events`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${orgToken}`,
      'X-Tenant-Id': org.tenant_id,
    },
    body: JSON.stringify({
      title: `SSE DIAG ${Date.now()}`,
      startsAt: starts.toISOString(),
      endsAt: ends.toISOString(),
    }),
  });
  const ev = (await evRes.json()) as { id?: string };
  const notifyBeforeCreate = notifyCount;

  const createRes = await fetch(`${apiBase}/events/${ev.id}/vendor-requests`, {
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
      message: 'SSE transport diagnosis',
      source: 'marketplace',
      selectedCapabilities: [{ key: 'sound_system', label: 'Sound System' }],
    }),
  });
  const createBody = (await createRes.json()) as {
    items?: Array<{ id: string; stage: string }>;
  };
  const requestId = createBody.items?.[0]?.id;
  const dbRow = requestId
    ? (
        await pg.query<{ id: string; stage: string; vendor_id: string }>(
          `SELECT id, stage, vendor_id FROM vendor_event_requests WHERE id=$1`,
          [requestId],
        )
      ).rows[0]
    : null;

  // Wait briefly for NOTIFY observer
  await new Promise((r) => setTimeout(r, 300));

  const incomingA = await sessA.waitFor((j) => j.type === 'vendor_request_incoming', 5000, mark);
  const incomingB = await sessB.waitFor((j) => j.type === 'vendor_request_incoming', 2000, mark);
  const leakOther = sessOther
    ? await sessOther.waitFor((j) => j.type === 'vendor_request_incoming', 1500, mark)
    : null;

  report.steps = {
    ...(report.steps as object),
    mutationCreate: {
      eventHttp: evRes.status,
      eventId: ev.id,
      requestHttp: createRes.status,
      requestId,
      dbPersisted: !!dbRow && dbRow.stage === 'new',
      dbStage: dbRow?.stage,
      pgNotifyDelta: notifyCount - notifyBeforeCreate,
      notifiesSample: notifies.slice(-3),
      sseVendorA: incomingA,
      sseVendorB: incomingB,
      sseOtherLeak: leakOther,
      expectedRecipientUserId: ven.id,
      expectedRoom: room(ven.tenant_id, ven.id),
    },
  };

  // --- Mutation 2: accept → organizer update ---
  if (requestId) {
    const mark2 = Date.now();
    const notifyBefore = notifyCount;
    const acceptRes = await fetch(`${apiBase}/vendor-requests/${requestId}/stage`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${venToken}`,
        'X-Tenant-Id': ven.tenant_id,
      },
      body: JSON.stringify({ stage: 'accepted' }),
    });
    await new Promise((r) => setTimeout(r, 200));
    const updateOrg = await sessOrg.waitFor((j) => j.type === 'vendor_request_update', 5000, mark2);
    report.steps = {
      ...(report.steps as object),
      mutationAccept: {
        http: acceptRes.status,
        pgNotifyDelta: notifyCount - notifyBefore,
        sseOrganizer: updateOrg,
        expectedRecipientUserId: org.id,
        expectedRoom: room(org.tenant_id, org.id),
      },
    };

    // --- Mutation 3: message → organizer ---
    const mark3 = Date.now();
    const notifyBeforeMsg = notifyCount;
    const msgRes = await fetch(`${apiBase}/vendor-requests/${requestId}/messages`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${venToken}`,
        'X-Tenant-Id': ven.tenant_id,
      },
      body: JSON.stringify({ message: 'SSE diagnosis structured note' }),
    });
    await new Promise((r) => setTimeout(r, 200));
    const msgOrg = await sessOrg.waitFor(
      (j) => j.type === 'vendor_request_message' || j.type === 'vendor_request_update',
      5000,
      mark3,
    );
    report.steps = {
      ...(report.steps as object),
      mutationMessage: {
        http: msgRes.status,
        pgNotifyDelta: notifyCount - notifyBeforeMsg,
        sseOrganizer: msgOrg,
      },
    };
  }

  // Frame inventory (no secrets)
  report.steps = {
    ...(report.steps as object),
    frameCounts: {
      vendorA: { total: sessA.frames.length, business: sessA.businessFrames().length },
      vendorB: { total: sessB.frames.length, business: sessB.businessFrames().length },
      organizer: { total: sessOrg.frames.length, business: sessOrg.businessFrames().length },
      other: sessOther
        ? { total: sessOther.frames.length, business: sessOther.businessFrames().length }
        : null,
    },
    notifyTotalObservedByDiagListen: notifyCount,
  };

  // Classification
  const gotIncoming = !!incomingA;
  const gotUpdate = !!(report.steps as { mutationAccept?: { sseOrganizer?: unknown } }).mutationAccept
    ?.sseOrganizer;
  const gotMessage = !!(report.steps as { mutationMessage?: { sseOrganizer?: unknown } }).mutationMessage
    ?.sseOrganizer;
  const multiOk = !!incomingA && !!incomingB;
  const isolationOk = !leakOther;
  const notifyOk = notifyCount > 0;

  if (gotIncoming && gotUpdate && gotMessage && multiOk && isolationOk) {
    report.classification = 'B. QA HARNESS / TEST ENVIRONMENT ISSUE';
    report.reason =
      'With continuous SSE pump (no abandoned reader.read), frames are received <5s for incoming/update/message; multi-session both get event; wrong user does not. Prior null receive is explained by harness Promise.race timeout dropping chunks.';
  } else if (!gotIncoming && !gotUpdate && !gotMessage && createRes.status < 400 && notifyOk) {
    report.classification = 'A. PRODUCT SSE DELIVERY BUG';
    report.reason =
      'REST+DB+pg_notify observed but continuous-pump SSE sessions still received no business frames.';
  } else if (!gotIncoming && !gotUpdate && !gotMessage && !notifyOk) {
    report.classification = 'A. PRODUCT SSE DELIVERY BUG';
    report.reason = 'No pg_notify observed by independent LISTEN and no SSE frames.';
  } else {
    report.classification = 'C. INCONCLUSIVE — MORE EVIDENCE REQUIRED';
    report.reason = {
      gotIncoming,
      gotUpdate,
      gotMessage,
      multiOk,
      isolationOk,
      notifyOk,
      createHttp: createRes.status,
    };
  }

  console.log(JSON.stringify(report, null, 2));

  async function cleanup() {
    vendorA.abort();
    vendorB.abort();
    orgAbort.abort();
    otherAbort.abort();
    try {
      await listenPg.query('UNLISTEN crm_realtime');
    } catch {
      /* ignore */
    }
    await listenPg.end();
    await pg.end();
  }

  await cleanup();
  process.exit(gotIncoming && gotUpdate ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(2);
});
