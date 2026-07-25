#!/usr/bin/env node
/**
 * RC Phase 3 — Workspace Platform API validation.
 * Run: node scripts/validate-rc-phase3-workspace.js
 */
const https = require('https');
const http = require('http');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://iozdkiwcwblydsomxhxa.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvemRraXdjd2JseWRzb214aHhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2OTYyNTksImV4cCI6MjA5MjI3MjI1OX0.8RfE-GF68fDAHK23OPFRmlhcVM9mz2yF9MxC2kYjSTk';
const API_BASE = process.env.OWANBE_API_BASE || 'http://127.0.0.1:8080/v1';
const TENANT = process.env.OWANBE_TENANT_ID || '11111111-1111-4111-8111-111111111111';
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

async function api(token, method, path, payload) {
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
    const health = await request('http://127.0.0.1:8080/health');
    if (health.json?.status === 'ok') pass('API health');
    else fail('API health', health.raw);
  } catch (e) {
    fail('API health', e);
  }

  try {
    const token = await signIn();
    pass('Supabase sign-in');

    await api(token, 'POST', '/auth/ensure-user', { displayName: 'Phase 3 Test' });
    pass('ensure-user');

    let me = await api(token, 'GET', '/auth/me');
    pass('auth/me');

    await api(token, 'POST', '/me/roles/activate', { workspace: 'organizer' });
    pass('activate organizer');

    await api(token, 'POST', '/me/active-workspace', { workspace: 'vendor' });
    pass('switch to vendor');

    me = await api(token, 'GET', '/auth/me');
    if (me.lastActiveWorkspace === 'vendor') pass('persist lastActiveWorkspace');
    else fail('persist lastActiveWorkspace', `got ${me.lastActiveWorkspace}`);

    await api(token, 'POST', '/me/active-workspace', { workspace: 'client' });
    me = await api(token, 'GET', '/auth/me');
    if (me.lastActiveWorkspace === 'client') pass('restore client workspace');
    else fail('restore client workspace', `got ${me.lastActiveWorkspace}`);

    if (Array.isArray(me.workspaces) && me.workspaces.length >= 1) pass('workspaces payload');
    else fail('workspaces payload', JSON.stringify(me.workspaces));
  } catch (e) {
    fail('workspace journey', e);
  }

  console.log('\nRC Phase 3 Workspace Platform Validation\n');
  for (const c of checks) {
    console.log(`${c.ok ? '✓' : '✗'} ${c.name}${c.err ? ` — ${c.err}` : ''}`);
  }
  const failed = checks.filter((c) => !c.ok);
  console.log(`\n${checks.length - failed.length}/${checks.length} passed`);
  process.exit(failed.length ? 1 : 0);
}

main();
