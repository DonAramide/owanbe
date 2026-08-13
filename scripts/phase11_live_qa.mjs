import jwt from '../services/api/node_modules/jsonwebtoken/index.js';
import fs from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = fs.readFileSync(path.join(root, 'services/api/.env'), 'utf8');
let secret = (env.match(/^SUPABASE_JWT_SECRET=(.*)$/m) || [])[1];
secret = secret.trim().replace(/^['"]|['"]$/g, '');

const TENANT = '11111111-1111-4111-8111-111111111111';
const USER = 'eb061885-7854-41db-b390-3a2b62eaeef5';
const EMAIL = 'akwajadaniel875@gmail.com';

const token = jwt.sign(
  {
    sub: USER,
    email: EMAIL,
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
};

async function get(p) {
  const res = await fetch('http://127.0.0.1:8080/v1/' + p, { headers });
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { status: res.status, body };
}

const results = {};
results.me = await get('organizers/me');
results.dashboard = await get('organizers/me/dashboard');
results.events = await get('organizers/me/events');
results.eventsQ = await get('organizers/me/events?q=Lagos');
results.eventsMiss = await get('organizers/me/events?q=zzzznope');
results.eventsDraft = await get('organizers/me/events?status=draft');
results.eventsSort = await get('organizers/me/events?sort=title_asc');
results.eventsLive = await get('organizers/me/events?status=live');
results.unauth = await fetch('http://127.0.0.1:8080/v1/organizers/me/dashboard', {
  headers: { 'X-Tenant-Id': TENANT, Accept: 'application/json' },
}).then(async (res) => ({ status: res.status, body: await res.text() }));

const firstId = results.events.body?.items?.[0]?.id;
results.manage = firstId ? await get(`events/${firstId}/manage`) : { status: 0, body: null };
results.createProbe = await fetch('http://127.0.0.1:8080/v1/events', {
  method: 'POST',
  headers: { ...headers, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    title: 'Phase11 QA Probe ' + Date.now(),
    city: 'Abuja',
    startsAt: new Date(Date.now() + 86400000 * 30).toISOString(),
  }),
}).then(async (res) => ({ status: res.status, body: await res.json().catch(() => null) }));

results.dashboardAfterCreate = await get('organizers/me/dashboard');
results.eventsAfterCreate = await get('organizers/me/events');

const dash = results.dashboard.body || {};
const requiredDashKeys = [
  'activeEvents',
  'upcomingEvents',
  'draftEvents',
  'liveEvents',
  'completedEvents',
  'ticketsSold',
  'revenueMinor',
  'vendorCount',
  'attendeeCount',
  'registrations',
  'checkIns',
];

const summary = {
  organizerMe: {
    status: results.me.status,
    id: results.me.body?.id,
    displayName: results.me.body?.displayName,
  },
  dashboard: {
    status: results.dashboard.status,
    keysPresent: requiredDashKeys.filter((k) => dash[k] !== undefined),
    keysMissing: requiredDashKeys.filter((k) => dash[k] === undefined),
    values: dash,
  },
  dashboardAfterCreate: results.dashboardAfterCreate.body,
  events: {
    status: results.events.status,
    count: results.events.body?.items?.length ?? null,
    statuses: (results.events.body?.items || []).map((e) => e.status),
    titles: (results.events.body?.items || []).slice(0, 8).map((e) => e.title),
  },
  eventsAfterCreateCount: results.eventsAfterCreate.body?.items?.length ?? null,
  searchLagos: {
    status: results.eventsQ.status,
    count: results.eventsQ.body?.items?.length ?? null,
    titles: (results.eventsQ.body?.items || []).map((e) => e.title),
  },
  searchMiss: {
    status: results.eventsMiss.status,
    count: results.eventsMiss.body?.items?.length ?? null,
  },
  draftFilter: {
    status: results.eventsDraft.status,
    count: results.eventsDraft.body?.items?.length ?? null,
    allDraft: (results.eventsDraft.body?.items || []).every((e) => e.status === 'draft'),
  },
  sortTitleAsc: {
    status: results.eventsSort.status,
    titles: (results.eventsSort.body?.items || []).map((e) => e.title),
  },
  liveFilter: {
    status: results.eventsLive.status,
    count: results.eventsLive.body?.items?.length ?? null,
  },
  manage: {
    status: results.manage.status,
    title: results.manage.body?.title,
    statusField: results.manage.body?.status,
  },
  createProbe: {
    status: results.createProbe.status,
    id: results.createProbe.body?.id || results.createProbe.body?.externalRef,
    title: results.createProbe.body?.title,
  },
  unauthDashboard: { status: results.unauth.status },
};

console.log(JSON.stringify(summary, null, 2));
