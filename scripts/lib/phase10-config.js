#!/usr/bin/env node
/** Shared Phase 10 constants and API helpers. */
const { spawn } = require('child_process');
const path = require('path');
const { signDevJwt } = require('./sign-dev-jwt');

const API_BASE = (process.env.API_BASE || 'http://localhost:8080/v1').replace(/\/$/, '');
const HEALTH_BASE = (process.env.HEALTH_BASE || 'http://localhost:8080').replace(/\/$/, '');
const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const TENANT_ID = process.env.TENANT_ID || '11111111-1111-4111-8111-111111111111';
const EVENT_REF = process.env.EVENT_REF || 'evt_lagos_owanbe_2026';

const USERS = {
  attendee: {
    id: process.env.DEV_USER_ID || '22222222-2222-4222-8222-222222222222',
    email: process.env.DEV_USER_EMAIL || 'attendee@owanbe.dev',
    roles: ['client'],
  },
  organizer: {
    id: process.env.DEV_USER_ID || '22222222-2222-4222-8222-222222222222',
    email: process.env.DEV_USER_EMAIL || 'attendee@owanbe.dev',
    roles: ['organizer'],
  },
  vendor: {
    id: process.env.DEV_USER_ID || '22222222-2222-4222-8222-222222222222',
    email: process.env.DEV_USER_EMAIL || 'attendee@owanbe.dev',
    roles: ['vendor'],
  },
  admin: {
    id: process.env.ADMIN_USER_ID || '77777777-7777-4777-8777-777777777777',
    email: process.env.ADMIN_USER_EMAIL || 'admin@owanbe.dev',
    roles: ['admin_super'],
  },
  superAdmin: {
    id: process.env.SUPER_ADMIN_ID || '88888888-8888-4888-8888-888888888888',
    email: process.env.SUPER_ADMIN_EMAIL || 'superadmin@owanbe.dev',
    roles: ['super_admin'],
  },
};

const ORGANIZER_ID = process.env.ORGANIZER_ID || '33333333-3333-4333-8333-333333333333';

function tokenFor(roleKey) {
  const u = USERS[roleKey];
  return signDevJwt({ userId: u.id, email: u.email, tenantId: TENANT_ID, roles: u.roles });
}

async function api(method, path, { role = 'organizer', tenantId = TENANT_ID, body, headers = {} } = {}) {
  const h = {
    Accept: 'application/json',
    Authorization: `Bearer ${tokenFor(role)}`,
    ...headers,
  };
  if (tenantId) h['X-Tenant-Id'] = tenantId;
  if (body !== undefined) h['Content-Type'] = 'application/json';
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: h,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  return { ok: res.ok, status: res.status, json, text };
}

async function waitForApi(max = 30) {
  for (let i = 0; i < max; i++) {
    try {
      const r = await fetch(`${HEALTH_BASE}/health`);
      if (r.ok) return true;
    } catch {
      /* retry */
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  return false;
}

function percentile(sorted, p) {
  if (sorted.length === 0) return 0;
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

/** Seed DB roles required for Phase 10 certification (JWT must match user_roles). */
async function ensureDevRoles(pg) {
  const userId = USERS.attendee.id;
  for (const code of ['client', 'vendor', 'organizer']) {
    await pg.query(
      `INSERT INTO user_roles (user_id, role_id)
       SELECT $1, r.id FROM roles r WHERE r.code = $2
       ON CONFLICT DO NOTHING`,
      [userId, code],
    );
  }
}

/** Start mock Quaser when production payment mode expects localhost:9090. */
async function ensureMockQuaser() {
  const port = parseInt(process.env.MOCK_QUASER_PORT || '9090', 10);
  try {
    const r = await fetch(`http://localhost:${port}/health`, { signal: AbortSignal.timeout(1500) });
    if (r.ok) return null;
  } catch {
    /* start below */
  }
  return new Promise((resolve, reject) => {
    const child = spawn('node', [path.join(__dirname, '../mock-quaser-server.js')], {
      env: {
        ...process.env,
        MOCK_QUASER_PORT: String(port),
        QUASER_WEBHOOK_SECRET: process.env.QUASER_WEBHOOK_SECRET || 'phase9-test-webhook-secret',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let out = '';
    child.stdout.on('data', (d) => {
      out += d.toString();
      if (out.includes('mockQuaserPort')) resolve(child);
    });
    child.on('error', reject);
    setTimeout(() => reject(new Error('Mock Quaser startup timeout')), 8000);
  });
}

/** Poll ticket_payments until Quaser webhook capture completes. */
async function waitForPaymentCaptured(pg, orderId, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const { rows } = await pg.query(
      `SELECT status::text, id FROM ticket_payments
       WHERE ticket_order_id = $1 ORDER BY created_at DESC LIMIT 1`,
      [orderId],
    );
    if (rows[0]?.status === 'captured') return rows[0];
    await new Promise((r) => setTimeout(r, 300));
  }
  return null;
}

module.exports = {
  API_BASE,
  HEALTH_BASE,
  DATABASE_URL,
  TENANT_ID,
  EVENT_REF,
  USERS,
  ORGANIZER_ID,
  tokenFor,
  api,
  waitForApi,
  percentile,
  ensureDevRoles,
  ensureMockQuaser,
  waitForPaymentCaptured,
};
