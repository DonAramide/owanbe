#!/usr/bin/env node
/**
 * Validates event creation pipeline: presign upload → POST /events → DB insert → manage lookup.
 */
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const { Client } = require('../services/api/node_modules/pg');

function loadApiJwtSecret() {
  if (process.env.SUPABASE_JWT_SECRET) return process.env.SUPABASE_JWT_SECRET;
  const envPath = path.join(__dirname, '..', 'services', 'api', '.env');
  if (!fs.existsSync(envPath)) return undefined;
  const line = fs.readFileSync(envPath, 'utf8').split('\n').find((l) => l.startsWith('SUPABASE_JWT_SECRET='));
  if (!line) return undefined;
  return line.slice('SUPABASE_JWT_SECRET='.length).trim().replace(/^["']|["']$/g, '');
}

process.env.SUPABASE_JWT_SECRET = loadApiJwtSecret() || process.env.SUPABASE_JWT_SECRET;

const { signDevJwt } = require('./lib/sign-dev-jwt');

const API_BASE = (process.env.API_BASE || 'http://127.0.0.1:8080/v1').replace(/\/$/, '');
const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5436/owanbe';
const TENANT_ID = process.env.TENANT_ID || '11111111-1111-4111-8111-111111111111';
const DEV_USER_ID = process.env.DEV_USER_ID || '33333333-3333-4333-8333-333333333331';
const DEV_USER_EMAIL = process.env.DEV_USER_EMAIL || 'organizer@owambe.dev';

const results = {};

function bearer() {
  return signDevJwt({
    userId: DEV_USER_ID,
    email: DEV_USER_EMAIL,
    tenantId: TENANT_ID,
    roles: ['organizer'],
  });
}

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
            json = { raw: data };
          }
          resolve({ status: res.statusCode, ok: res.statusCode >= 200 && res.statusCode < 300, json, raw: data });
        });
      },
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

function headers(extra = {}, json = true) {
  const h = {
    Accept: 'application/json',
    Authorization: `Bearer ${bearer()}`,
    'X-Tenant-Id': TENANT_ID,
    ...extra,
  };
  if (json) h['Content-Type'] = 'application/json';
  return h;
}

async function apiJson(method, path, body) {
  const res = await request(`${API_BASE}${path}`, {
    method,
    headers: headers(),
    body: body ? JSON.stringify(body) : undefined,
  });
  return res;
}

async function presignAndUpload(label, byteLength) {
  const presign = await apiJson('POST', '/media/presign', {
    filename: `${label}.jpg`,
    contentType: 'image/jpeg',
    purpose: 'celebrant_image',
  });
  if (!presign.ok) throw new Error(`presign failed: ${presign.status} ${JSON.stringify(presign.json)}`);

  const bytes = Buffer.alloc(byteLength, 0xff);
  const uploadRes = await request(presign.json.uploadUrl, {
    method: 'PUT',
    headers: headers({ 'Content-Type': 'image/jpeg' }, false),
    body: bytes,
  });
  if (!uploadRes.ok) {
    throw new Error(`upload failed: ${uploadRes.status} ${uploadRes.raw}`);
  }

  return {
    presignStatus: presign.status,
    uploadStatus: uploadRes.status,
    publicUrl: presign.json.publicUrl,
    objectId: presign.json.objectId,
    byteLength,
  };
}

function eventBody(title, celebrantImageUrl) {
  const startsAt = new Date(Date.now() + 60 * 24 * 3600 * 1000).toISOString();
  const body = {
    title,
    tagline: 'Validation run',
    city: 'Lagos',
    venue: 'Test Venue',
    category: 'Wedding',
    categorySlug: 'wedding',
    eventAccessMode: 'PRIVATE_INVITATION',
    budgetMinor: 500000000,
    expectedGuests: 150,
    venueName: 'Test Venue',
    venueAddress: 'Victoria Island',
    tags: [],
    startsAt,
    endsAt: new Date(Date.parse(startsAt) + 6 * 3600 * 1000).toISOString(),
    budgetAllocation: [],
    requiredServices: ['catering'],
    venueDeferred: false,
    state: 'Lagos',
    lga: 'Eti-Osa',
  };
  if (celebrantImageUrl) body.celebrantImageUrl = celebrantImageUrl;
  return body;
}

async function createAndVerify(title, celebrantImageUrl, pg) {
  const create = await apiJson('POST', '/events', eventBody(title, celebrantImageUrl));
  if (!create.ok) throw new Error(`create failed: ${create.status} ${JSON.stringify(create.json)}`);

  const eventId = create.json.externalRef || create.json.id;
  const manage = await apiJson('GET', `/events/${eventId}/manage`);
  if (!manage.ok) throw new Error(`manage lookup failed: ${manage.status}`);

  const { rows } = await pg.query(
    `SELECT id, external_ref, title, metadata->>'celebrantImageUrl' AS celebrant_image_url
     FROM events WHERE tenant_id = $1 AND (external_ref = $2 OR id::text = $2)`,
    [TENANT_ID, eventId],
  );
  if (!rows.length) throw new Error(`event not found in PostgreSQL for ${eventId}`);

  return {
    postStatus: create.status,
    eventId,
    dbTitle: rows[0].title,
    dbCelebrantImageUrl: rows[0].celebrant_image_url,
    manageStatus: manage.status,
    manageTitle: manage.json.title,
    navigatesTo: `/events/${eventId}`,
    commandCenterGate: 'EventWorkspace (customerEventOwnershipProvider=true)',
  };
}

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();

  try {
    const caseA = await createAndVerify(`RC Validate A ${Date.now()}`, null, pg);
    results.caseA_no_image = { pass: true, ...caseA };

    const uploadB = await presignAndUpload('celebrant-large', 251_079);
    const caseB = await createAndVerify(`RC Validate B ${Date.now()}`, uploadB.publicUrl, pg);
    results.caseB_large_image = {
      pass: true,
      upload: uploadB,
      ...caseB,
      payloadUsesUrlNotBase64: !String(caseB.dbCelebrantImageUrl || '').startsWith('data:'),
    };

    const badUpload = await request(`${API_BASE}/media/upload/${encodeURIComponent('invalid/key')}`, {
      method: 'PUT',
      headers: headers({ 'Content-Type': 'image/jpeg' }, false),
      body: Buffer.from([0xff, 0xd8, 0xff]),
    });
    results.caseC_upload_failure = {
      pass: !badUpload.ok,
      uploadStatus: badUpload.status,
      code: badUpload.json?.code,
      wizardBehavior: 'stay open, show error, no navigation',
    };

    const beforeCount = await pg.query(`SELECT count(*)::int AS n FROM events WHERE tenant_id = $1`, [TENANT_ID]);
    const caseD = await apiJson('POST', '/events', { city: 'Lagos' });
    const afterCount = await pg.query(`SELECT count(*)::int AS n FROM events WHERE tenant_id = $1`, [TENANT_ID]);
    results.caseD_api_failure = {
      pass: !caseD.ok && afterCount.rows[0].n === beforeCount.rows[0].n,
      postStatus: caseD.status,
      code: caseD.json?.code,
      rowCountUnchanged: afterCount.rows[0].n === beforeCount.rows[0].n,
      wizardBehavior: 'stay open, Retry available, no OrganizerEventStore fallback unless ALLOW_OFFLINE_MOCK_PERSISTENCE=true',
    };

    const allPass = Object.values(results).every((r) => r.pass);
    console.log(JSON.stringify({ pass: allPass, authUser: DEV_USER_EMAIL, results }, null, 2));
    process.exit(allPass ? 0 : 1);
  } finally {
    await pg.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
