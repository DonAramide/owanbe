#!/usr/bin/env node
/**
 * RC Phase 5 — Production certification API validation.
 * Run: node scripts/validate-rc-phase5-certification.js
 */
const https = require('https');
const http = require('http');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://iozdkiwcwblydsomxhxa.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvemRraXdjd2JseWRzb214aHhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2OTYyNTksImV4cCI6MjA5MjI3MjI1OX0.8RfE-GF68fDAHK23OPFRmlhcVM9mz2yF9MxC2kYjSTk';
const API_BASE = (process.env.OWANBE_API_BASE || 'http://127.0.0.1:8080/v1').replace(/\/$/, '');
/** NestJS mounts GET /health outside the global /v1 prefix (see services/api/src/main.ts). */
const HEALTH_BASE = (
  process.env.HEALTH_BASE ||
  API_BASE.replace(/\/v1$/i, '') ||
  'http://127.0.0.1:8080'
).replace(/\/$/, '');const TENANT = process.env.OWANBE_TENANT_ID || '11111111-1111-4111-8111-111111111111';
const EMAIL = process.env.OWANBE_TEST_EMAIL || 'attendee@owanbe.dev';
const PASSWORD = process.env.OWANBE_TEST_PASSWORD || '123456';

function request(url, { method = 'GET', headers = {}, body } = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const lib = u.protocol === 'https:' ? https : http;
    const req = lib.request(
      {
        hostname: u.hostname,
        port: u.port || (u.protocol === 'https:' ? 443 : 80),
        path: u.pathname + u.search,
        method,
        headers,
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          let json = null;
          try {
            json = data ? JSON.parse(data) : null;
          } catch {
            json = data;
          }
          resolve({ status: res.statusCode, json, raw: data });
        });
      },
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function signIn() {
  const res = await request(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_ANON,
      Authorization: `Bearer ${SUPABASE_ANON}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ email: EMAIL, password: PASSWORD }),
  });
  if (res.status !== 200) throw new Error(`Sign-in failed: ${res.status} ${res.raw}`);
  return res.json.access_token;
}

async function api(token, method, path, payload, { expectStatus } = {}) {
  const headers = {
    Authorization: `Bearer ${token}`,
    'X-Tenant-Id': TENANT,
    'Content-Type': 'application/json',
  };
  const res = await request(`${API_BASE}${path}`, {
    method,
    headers,
    body: payload ? JSON.stringify(payload) : undefined,
  });
  if (expectStatus != null) {
    if (res.status !== expectStatus) {
      throw new Error(`${method} ${path} expected ${expectStatus} got ${res.status} ${res.raw}`);
    }
    return res.json;
  }
  if (res.status < 200 || res.status >= 300) {
    throw new Error(`${method} ${path} → ${res.status} ${res.raw}`);
  }
  return res.json;
}

async function main() {
  const checks = [];
  const pass = (name) => checks.push({ name, ok: true });
  const fail = (name, err) => checks.push({ name, ok: false, err: String(err) });

  try {
    const health = await request(`${HEALTH_BASE}/health`);
    if (health.status === 200 && (health.json?.status === 'ok' || health.json?.status === 'degraded')) {
      pass('API health');
    } else {
      fail('API health', `${health.status} ${health.raw}`);
    }
  } catch (e) {
    fail('API health', e);
  }
  try {
    const token = await signIn();
    pass('Universal Supabase sign-in');

    await api(token, 'POST', '/auth/ensure-user', { displayName: 'RC Phase 5' });
    pass('Universal ensure-user');

    const me = await api(token, 'GET', '/auth/me');
    if (me.identityVersion === '2.0') pass('Identity v2 payload');
    else fail('Identity v2 payload', `version=${me.identityVersion}`);
    if (Array.isArray(me.workspaces)) pass('Workspaces array');
    else fail('Workspaces array', JSON.stringify(me));

    await api(token, 'POST', '/me/roles/activate', { workspace: 'organizer' });
    pass('Organizer workspace activation');

    await api(token, 'POST', '/me/active-workspace', { workspace: 'vendor' });
    const afterSwitch = await api(token, 'GET', '/auth/me');
    if (afterSwitch.lastActiveWorkspace === 'vendor') pass('Workspace persistence');
    else fail('Workspace persistence', afterSwitch.lastActiveWorkspace);

    await api(token, 'POST', '/auth/validate-portal', { portal: 'client' }, { expectStatus: 410 });
    pass('Legacy validate-portal retired (410)');

    await api(token, 'POST', '/auth/complete-signup', { portal: 'client' }, { expectStatus: 410 });
    pass('Legacy complete-signup retired (410)');

    await api(token, 'POST', '/auth/complete-onboarding', {
      displayName: 'RC Phase 5',
      workspace: 'client',
    });
    pass('Universal complete-onboarding (v2 path)');
  } catch (e) {
    fail('certification journey', e);
  }

  console.log('\nRC Phase 5 Production Certification Validation\n');
  console.log(`API base:    ${API_BASE}`);
  console.log(`Health base: ${HEALTH_BASE}/health\n`);  for (const c of checks) {
    console.log(`${c.ok ? '✓' : '✗'} ${c.name}${c.err ? ` — ${c.err}` : ''}`);
  }
  const failed = checks.filter((c) => !c.ok);
  console.log(`\n${checks.length - failed.length}/${checks.length} passed`);
  process.exit(failed.length ? 1 : 0);
}

main();
