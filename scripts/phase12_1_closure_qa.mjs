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
const out = { checks: {} };

// H1 — create draft then discard
out.createDraft = await req('POST', '/events', {
  title: 'Phase12.1 Discard Probe ' + Date.now(),
  city: 'Lagos',
  startsAt: start.toISOString(),
  endsAt: end.toISOString(),
  eventAccessMode: 'PRIVATE_INVITATION',
  description: 'Discard probe description for phase 12.1',
});
const discardId = out.createDraft.body?.id;
out.discard = discardId ? await req('POST', `/events/${discardId}/discard`) : { status: 0 };
out.listAfterDiscard = await req('GET', '/organizers/me/events');
out.listDraftAfterDiscard = await req('GET', '/organizers/me/events?status=draft');
const stillVisible = (out.listAfterDiscard.body?.items ?? []).some((e) => e.id === discardId);
const stillInDraft = (out.listDraftAfterDiscard.body?.items ?? []).some((e) => e.id === discardId);
out.checks.H1_discardHidden = out.discard.status === 201 || out.discard.status === 200
  ? !stillVisible && !stillInDraft
  : false;
out.checks.H1_discardStatus = out.discard.status;

// H3 — PATCH ticket tiers
out.createPublic = await req('POST', '/events', {
  title: 'Phase12.1 Tier Patch ' + Date.now(),
  city: 'Lagos',
  startsAt: start.toISOString(),
  endsAt: end.toISOString(),
  eventAccessMode: 'PUBLIC_TICKETED',
  description: 'Tier patch probe description long enough',
  language: 'en',
  themeColor: '#112233',
  listingVisibility: 'public',
});
const tierEventId = out.createPublic.body?.id;
out.patchTiers = tierEventId
  ? await req('PATCH', `/events/${tierEventId}`, {
      title: out.createPublic.body.title,
      language: 'yo',
      themeColor: '#D4A853',
      listingVisibility: 'public',
      ticketTiers: [
        {
          id: 'tier_closure_ga',
          name: 'General Admission',
          priceMinor: 250000,
          currency: 'NGN',
          capacity: 80,
          remaining: 80,
          tierType: 'regular',
          visibility: 'publicListing',
        },
      ],
    })
  : { status: 0 };
const patchedTiers = out.patchTiers.body?.ticketTiers ?? [];
out.checks.H3_tiersOnPatch = patchedTiers.some((t) => t.name === 'General Admission');
out.checks.M3_metadataOnView =
  out.patchTiers.body?.language === 'yo' && out.patchTiers.body?.themeColor === '#D4A853';

out.publishAfterTiers = tierEventId
  ? await req('POST', `/events/${tierEventId}/publish`)
  : { status: 0 };
out.checks.publishAfterTierPatch = out.publishAfterTiers.status === 201 || out.publishAfterTiers.body?.status === 'published';

out.dashboard = await req('GET', '/organizers/me/dashboard');
out.checks.dashboardOk = out.dashboard.status === 200;

// Discard published must fail
out.discardPublished = tierEventId
  ? await req('POST', `/events/${tierEventId}/discard`)
  : { status: 0 };
out.checks.discardPublishedRejected = out.discardPublished.status === 422;

console.log(JSON.stringify(out, null, 2));
