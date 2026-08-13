import jwt from '../services/api/node_modules/jsonwebtoken/index.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = fs.readFileSync(path.join(root, 'services/api/.env'), 'utf8');
let secret = (env.match(/^SUPABASE_JWT_SECRET=(.*)$/m) || [])[1];
secret = secret.trim().replace(/^['"]|['"]$/g, '');

const TENANT = '11111111-1111-4111-8111-111111111111';
const USER = 'eb061885-7854-41db-b390-3a2b62eaeef5';

const token = jwt.sign(
  {
    sub: USER,
    email: 'akwajadaniel875@gmail.com',
    role: 'authenticated',
    aud: 'authenticated',
    app_metadata: { tenant_id: TENANT, roles: ['organizer'] },
  },
  secret,
  { algorithm: 'HS256', expiresIn: '1h' },
);

const headers = {
  Authorization: 'Bearer ' + token,
  'X-Tenant-Id': TENANT,
  Accept: 'application/json',
  'Content-Type': 'application/json',
};

const base = 'http://127.0.0.1:8080/v1';

async function req(method, p, body) {
  const res = await fetch(base + p, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let bodyJson;
  try {
    bodyJson = JSON.parse(text);
  } catch {
    bodyJson = text;
  }
  return { status: res.status, body: bodyJson };
}

const start = new Date(Date.now() + 86400000 * 45);
const end = new Date(Date.now() + 86400000 * 47);
const out = {};

out.me = await req('GET', '/organizers/me');
out.dashboard = await req('GET', '/organizers/me/dashboard');

out.publicNoTiers = await req('POST', '/events', {
  title: 'Phase12 QA Public NoTiers ' + Date.now(),
  city: 'Lagos',
  startsAt: start.toISOString(),
  endsAt: end.toISOString(),
  eventAccessMode: 'PUBLIC_TICKETED',
  description: 'Phase12 QA description long enough for readiness',
  requiredServices: ['catering'],
});
const pubId = out.publicNoTiers.body?.id;
if (pubId) {
  out.publishNoTiers = await req('POST', `/events/${pubId}/publish`);
  const patchEnd = new Date(Date.now() + 86400000 * 50);
  out.patch = await req('PATCH', `/events/${pubId}`, {
    title: 'Phase12 QA Patched ' + Date.now(),
    endsAt: patchEnd.toISOString(),
    language: 'en',
    themeColor: '#112233',
    listingVisibility: 'public',
  });
  out.manageAfterPatch = await req('GET', `/events/${pubId}/manage`);
}

out.private = await req('POST', '/events', {
  title: 'Phase12 QA Private ' + Date.now(),
  city: 'Lagos',
  startsAt: start.toISOString(),
  endsAt: end.toISOString(),
  eventAccessMode: 'PRIVATE_INVITATION',
  description: 'Private phase12 QA event description',
  requiredServices: ['catering'],
});
const privId = out.private.body?.id;
if (privId) {
  out.publishPrivate = await req('POST', `/events/${privId}/publish`);
}

out.publicWithTiers = await req('POST', '/events', {
  title: 'Phase12 QA Public Tiers ' + Date.now(),
  city: 'Lagos',
  startsAt: start.toISOString(),
  endsAt: end.toISOString(),
  eventAccessMode: 'PUBLIC_TICKETED',
  description: 'Public with tiers phase12',
  requiredServices: ['catering'],
  ticketTiers: [
    {
      name: 'General',
      priceMinor: 500000,
      currency: 'NGN',
      capacity: 100,
      remaining: 100,
    },
  ],
});
const tierEventId = out.publicWithTiers.body?.id;
if (tierEventId) {
  out.publishWithTiers = await req('POST', `/events/${tierEventId}/publish`);
  out.manageWithTiers = await req('GET', `/events/${tierEventId}/manage`);
}

out.eventsDraft = await req('GET', '/organizers/me/events?status=draft');

console.log(JSON.stringify(out, null, 2));
