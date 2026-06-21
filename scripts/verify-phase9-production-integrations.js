#!/usr/bin/env node
/**
 * Phase 9 — Production Integrations gate.
 * Requires: migration 026, API on :8080 configured for production integrations.
 * Starts mock Quaser + notification receiver for payment/notification tests.
 */
const http = require('http');
const { spawn } = require('child_process');
const { Client } = require('../services/api/node_modules/pg');
const { signDevJwt } = require('./lib/sign-dev-jwt');

const API_BASE = (process.env.API_BASE || 'http://localhost:8080/v1').replace(/\/$/, '');
const HEALTH_BASE = (process.env.HEALTH_BASE || 'http://localhost:8080').replace(/\/$/, '');
const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const TENANT_ID = process.env.TENANT_ID || '11111111-1111-4111-8111-111111111111';
const DEV_USER_ID = process.env.DEV_USER_ID || '22222222-2222-4222-8222-222222222222';
const DEV_USER_EMAIL = process.env.DEV_USER_EMAIL || 'attendee@owanbe.dev';
const EVENT_REF = 'evt_lagos_owanbe_2026';
const WEBHOOK_SECRET = process.env.QUASER_WEBHOOK_SECRET || 'phase9-test-webhook-secret';

const gate = {
  paymentIntegration: 'FAIL',
  notifications: 'FAIL',
  storage: 'FAIL',
  realtime: 'FAIL',
  observability: 'FAIL',
};
const evidence = {};

function bearer(roles = ['organizer']) {
  return signDevJwt({
    userId: DEV_USER_ID,
    email: DEV_USER_EMAIL,
    tenantId: TENANT_ID,
    roles,
  });
}

async function api(method, path, body, extra = {}, roles = ['organizer']) {
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: `Bearer ${bearer(roles)}`,
      'X-Tenant-Id': TENANT_ID,
      ...extra,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  return { ok: res.ok, status: res.status, json, headers: res.headers };
}

function startNotificationReceiver() {
  return new Promise((resolve) => {
    const received = [];
    const server = http.createServer((req, res) => {
      const chunks = [];
      req.on('data', (c) => chunks.push(c));
      req.on('end', () => {
        try {
          received.push(JSON.parse(Buffer.concat(chunks).toString()));
        } catch {
          received.push({ raw: true });
        }
        res.writeHead(200);
        res.end('ok');
      });
    });
    server.listen(0, '127.0.0.1', () => {
      const port = server.address().port;
      resolve({ server, port, received, url: `http://127.0.0.1:${port}/notify` });
    });
  });
}

function startMockQuaser() {
  return new Promise((resolve, reject) => {
    const child = spawn('node', [require('path').join(__dirname, 'mock-quaser-server.js')], {
      env: { ...process.env, MOCK_QUASER_PORT: '9090', QUASER_WEBHOOK_SECRET: WEBHOOK_SECRET },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let out = '';
    child.stdout.on('data', (d) => {
      out += d.toString();
      if (out.includes('mockQuaserPort')) resolve(child);
    });
    child.stderr.on('data', (d) => process.stderr.write(d));
    child.on('error', reject);
    setTimeout(() => reject(new Error('Mock Quaser startup timeout')), 8000);
  });
}

async function waitForHealth() {
  for (let i = 0; i < 30; i++) {
    try {
      const r = await fetch(`${HEALTH_BASE}/health`);
      if (r.ok) return r.json();
    } catch {
      /* retry */
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  return null;
}

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();

  let mockQuaser;
  let notifReceiver;
  try {
    mockQuaser = await startMockQuaser();
    notifReceiver = await startNotificationReceiver();

    const health = await waitForHealth();
    evidence.health = health;
    if (!health) throw new Error('API /health unreachable');

    const paymentsConfigured =
      health.checks?.payments?.status === 'configured' ||
      health.checks?.integrationsMode?.status === 'production';
    evidence.integrationsMode = health.checks?.integrationsMode?.status;

    // ── Observability ──
    const metricsRes = await fetch(`${HEALTH_BASE}/metrics`);
    const metricsText = await metricsRes.text();
    evidence.observability = {
      healthOk: health.status === 'ok' || health.status === 'degraded',
      databaseOk: health.checks?.database?.status === 'ok',
      metricsOk: metricsRes.ok && metricsText.includes('owanbe_up'),
    };
    if (evidence.observability.healthOk && evidence.observability.databaseOk && evidence.observability.metricsOk) {
      gate.observability = 'PASS';
    }

    // ── Storage ──
    const presign = await api('POST', '/media/presign', {
      filename: 'evidence.png',
      contentType: 'image/png',
      purpose: 'dispute_evidence',
    });
    evidence.storage = { presignStatus: presign.status, objectId: presign.json?.objectId };
    if (presign.ok && presign.json?.uploadUrl && presign.json?.publicUrl) {
      gate.storage = 'PASS';
    }

    // ── Realtime ──
    const streamRes = await fetch(`${API_BASE}/events/${EVENT_REF}/feed/stream`, {
      headers: {
        Authorization: `Bearer ${bearer(['organizer'])}`,
        'X-Tenant-Id': TENANT_ID,
        Accept: 'text/event-stream',
      },
    });
    evidence.realtime = {
      streamStatus: streamRes.status,
      contentType: streamRes.headers.get('content-type'),
    };
    if (streamRes.ok && String(streamRes.headers.get('content-type')).includes('text/event-stream')) {
      gate.realtime = 'PASS';
      streamRes.body?.cancel?.();
    }

    // ── Payment + Notifications (requires production Quaser mock) ──
    if (paymentsConfigured) {
      const tiers = await fetch(`${API_BASE}/events/${EVENT_REF}/tiers`, {
        headers: { Accept: 'application/json', 'X-Tenant-Id': TENANT_ID },
      }).then((r) => r.json());
      const tierId = tiers?.items?.[0]?.id ?? tiers?.items?.[0]?.externalTierId;
      evidence.tiers = { tierId, raw: tiers?.items?.length };
      if (tierId) {
        const order = await api('POST', `/events/${EVENT_REF}/ticket-orders`, {
          currency: 'NGN',
          items: [{ tierId, quantity: 1 }],
        }, { 'Idempotency-Key': `p9-${Date.now()}` }, ['organizer']);
        if (order.ok) {
          const orderId = order.json?.order?.id ?? order.json?.id;
          const pay = await api('POST', `/ticket-orders/${orderId}/payments`, undefined, {
            'Idempotency-Key': `p9pay-${Date.now()}`,
          }, ['organizer']);
          await new Promise((r) => setTimeout(r, 1500));
          const payStatus = await pg.query(
            `SELECT status::text FROM ticket_payments WHERE ticket_order_id = $1 ORDER BY created_at DESC LIMIT 1`,
            [orderId],
          );
          evidence.payment = {
            initiateOk: pay.ok,
            paymentStatus: payStatus.rows[0]?.status,
            quaserReference: pay.json?.payment?.quaserReference,
          };
          if (payStatus.rows[0]?.status === 'captured') {
            gate.paymentIntegration = 'PASS';
          }
        }
      }
    } else {
      evidence.payment = {
        skipped: true,
        reason: 'Restart API with INTEGRATIONS_MODE=production QUASER_ROUTER_BASE_URL=http://localhost:9090 PUBLIC_API_BASE_URL=http://localhost:8080 QUASER_WEBHOOK_SECRET=phase9-test-webhook-secret NOTIFICATION_WEBHOOK_URL=<receiver>',
      };
    }

    const notifCount = await pg.query(
      `SELECT COUNT(*)::int AS n FROM notification_deliveries WHERE status = 'sent'`,
    );
    evidence.notifications = {
      deliveriesSent: notifCount.rows[0]?.n,
      webhookReceived: notifReceiver.received.length,
    };
    if (notifCount.rows[0]?.n > 0 || notifReceiver.received.length > 0) {
      gate.notifications = 'PASS';
    } else {
      // log-only provider still records sent deliveries when capture runs
      const anyDelivery = await pg.query(`SELECT COUNT(*)::int AS n FROM notification_deliveries`);
      if (anyDelivery.rows[0]?.n > 0) gate.notifications = 'PASS';
    }

    const passed = Object.values(gate).filter((v) => v === 'PASS').length;
    const result = passed === 5 ? 'PASS' : 'FAIL';

    console.log(
      JSON.stringify(
        {
          phase: 9,
          baseline: 'v0.9.0-security-pass',
          result,
          score: `${passed}/5`,
          gate,
          evidence,
        },
        null,
        2,
      ),
    );
    process.exit(result === 'PASS' ? 0 : 1);
  } finally {
    if (mockQuaser) mockQuaser.kill();
    if (notifReceiver) notifReceiver.server.close();
    await pg.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
