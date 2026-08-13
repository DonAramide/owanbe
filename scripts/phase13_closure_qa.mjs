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

const start = new Date(Date.now() + 86400000 * 40);
const end = new Date(Date.now() + 86400000 * 42);
const out = { checks: {} };

// Create public event with a hidden tier + future sales window tier
out.event = await req('POST', '/events', {
  title: 'Phase13 QA Commerce ' + Date.now(),
  city: 'Lagos',
  startsAt: start.toISOString(),
  endsAt: end.toISOString(),
  eventAccessMode: 'PUBLIC_TICKETED',
  listingVisibility: 'public',
  description: 'Phase 13 commerce QA event',
});
const eventId = out.event.body?.id;

out.hiddenTier = await req('POST', `/events/${eventId}/tiers`, {
  id: 'tier_hidden_p13',
  name: 'Hidden VIP',
  priceMinor: 100000,
  currency: 'NGN',
  capacity: 10,
  remaining: 10,
  visibility: 'hidden',
  salesStartAt: new Date(Date.now() - 86400000).toISOString(),
  salesEndAt: new Date(Date.now() + 86400000 * 10).toISOString(),
});

out.futureTier = await req('POST', `/events/${eventId}/tiers`, {
  id: 'tier_future_p13',
  name: 'Future GA',
  priceMinor: 50000,
  currency: 'NGN',
  capacity: 20,
  remaining: 20,
  visibility: 'publicListing',
  salesStartAt: new Date(Date.now() + 86400000 * 5).toISOString(),
  salesEndAt: new Date(Date.now() + 86400000 * 20).toISOString(),
});

out.openTier = await req('POST', `/events/${eventId}/tiers`, {
  id: 'tier_open_p13',
  name: 'Open GA',
  priceMinor: 25000,
  currency: 'NGN',
  capacity: 5,
  remaining: 5,
  visibility: 'publicListing',
  minQuantity: 2,
  maxQuantity: 3,
  maxPerUser: 3,
  salesStartAt: new Date(Date.now() - 86400000).toISOString(),
  salesEndAt: new Date(Date.now() + 86400000 * 10).toISOString(),
});

out.publish = await req('POST', `/events/${eventId}/publish`);

out.publicTiers = await req('GET', `/events/${eventId}/tiers`);
const publicIds = (out.publicTiers.body?.items ?? []).map((t) => t.id);
out.checks.hiddenFiltered = !publicIds.includes('tier_hidden_p13');
out.checks.futureFiltered = !publicIds.includes('tier_future_p13');
out.checks.openVisible = publicIds.includes('tier_open_p13');

// Buyer purchase attempts (same organizer token — commerce auth allows)
out.buyHidden = await req('POST', `/events/${eventId}/ticket-orders`, {
  currency: 'NGN',
  items: [{ tierId: 'tier_hidden_p13', quantity: 1 }],
});
out.checks.hiddenBlocked = out.buyHidden.status === 422;

out.buyFuture = await req('POST', `/events/${eventId}/ticket-orders`, {
  currency: 'NGN',
  items: [{ tierId: 'tier_future_p13', quantity: 1 }],
});
out.checks.futureBlocked = out.buyFuture.status === 422;

out.buyMinFail = await req('POST', `/events/${eventId}/ticket-orders`, {
  currency: 'NGN',
  items: [{ tierId: 'tier_open_p13', quantity: 1 }],
});
out.checks.minQtyBlocked = out.buyMinFail.status === 422;

out.buyOk = await req('POST', `/events/${eventId}/ticket-orders`, {
  currency: 'NGN',
  items: [{ tierId: 'tier_open_p13', quantity: 2 }],
});
out.checks.buyOk = out.buyOk.status === 201 || out.buyOk.body?.order?.status === 'pending_payment';

out.sales = await req('GET', `/events/${eventId}/tiers/sales`);
out.checks.salesEndpoint = out.sales.status === 200;

out.dup = await req('POST', `/tiers/${out.openTier.body?.id}/duplicate`);
out.checks.duplicate = out.dup.status === 201 || out.dup.body?.externalTierId;

out.archive = await req('POST', `/tiers/${out.hiddenTier.body?.id}/archive`);
out.checks.archive = out.archive.status === 201 || out.archive.body?.archived === true;

out.release = await req('POST', '/ticket-orders/release-abandoned');
out.checks.releaseEndpoint = out.release.status === 201 || out.release.status === 200;

out.dashboard = await req('GET', '/organizers/me/dashboard');
out.checks.dashboard = out.dashboard.status === 200;

console.log(JSON.stringify({ checks: out.checks, sample: {
  buyHidden: out.buyHidden.body,
  buyFuture: out.buyFuture.body,
  buyMinFail: out.buyMinFail.body,
  buyOkStatus: out.buyOk.status,
  publicCount: publicIds.length,
  salesCount: out.sales.body?.items?.length,
} }, null, 2));
