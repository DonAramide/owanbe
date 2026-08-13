#!/usr/bin/env node
/**
 * Phase 25 — Business Operations Integrated Live QA (scaffold).
 *
 * Does NOT invent domain data. Expects a running API + auth context via env:
 *   API_BASE, TENANT_ID, ACCESS_TOKEN, EVENT_ID (optional)
 *
 * Full execution belongs to Integrated Live QA Planning after Completion Review.
 */
const base = (process.env.API_BASE || 'http://127.0.0.1:3000').replace(/\/$/, '');
const token = process.env.ACCESS_TOKEN || '';
const tenant = process.env.TENANT_ID || '';

async function get(path) {
  const res = await fetch(`${base}${path}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      'X-Tenant-Id': tenant,
      Accept: 'application/json',
    },
  });
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { status: res.status, body };
}

async function main() {
  console.log('Phase 25 Business Ops Live QA scaffold');
  console.log(`API_BASE=${base}`);
  if (!token || !tenant) {
    console.log('SKIP: set ACCESS_TOKEN and TENANT_ID to execute checks.');
    console.log('Checklist: docs/PHASE25_BUSINESS_OPS_INTEGRATED_QA_CHECKLIST.md');
    process.exit(0);
  }

  const health = await get('/health');
  console.log('health', health.status, health.body?.status ?? health.body);

  const checks = [
    ['finance hub', '/organizers/me/finance/hub'],
    ['analytics portfolio', '/organizers/me/analytics/portfolio'],
    ['reports catalog', '/organizers/me/reports/catalog'],
    ['automations', '/organizers/me/automations'],
    ['automation observability', '/organizers/me/automations/observability'],
    ['integrations status', '/organizers/me/integrations/status'],
  ];

  for (const [label, path] of checks) {
    const r = await get(path);
    console.log(label, r.status, r.status === 403 ? r.body?.code || r.body : 'ok-or-body');
  }

  console.log('Done. Mark journey results in the checklist doc.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
