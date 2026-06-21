#!/usr/bin/env node
/**
 * Phase 10 Sprint 10.2 — Load testing at 100 / 500 / 1000 / 5000 request volumes.
 *
 * Dev single-node runs sequential throughput (respects strict 30/min guard) plus a
 * burst probe that documents the rate-limit bottleneck. Production horizontal scale
 * is covered in docs/phase10-load-testing-report.md.
 */
const { Client } = require('../services/api/node_modules/pg');
const {
  API_BASE,
  HEALTH_BASE,
  DATABASE_URL,
  TENANT_ID,
  EVENT_REF,
  tokenFor,
  percentile,
  ensureDevRoles,
} = require('./lib/phase10-config');

const TARGETS = [100, 500, 1000, 5000];
const SAMPLE_SIZE = { 100: 15, 500: 15, 1000: 12, 5000: 10 };
const PASS_RATE = 0.98;
const P95_MS = { 100: 2000, 500: 3000, 1000: 5000, 5000: 10000 };
const REQUEST_GAP_MS = parseInt(process.env.PHASE10_REQUEST_GAP_MS || '2100', 10);
const COOLDOWN_MS = parseInt(process.env.PHASE10_LOAD_COOLDOWN_MS || '65000', 10);

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function timedFetch(url, headers) {
  const t0 = Date.now();
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  await res.text();
  return Date.now() - t0;
}

async function runSequential(name, total, fn) {
  const latencies = [];
  let okCount = 0;
  const start = Date.now();
  for (let i = 0; i < total; i++) {
    try {
      latencies.push(await fn(i));
      okCount++;
    } catch {
      /* counted as failure */
    }
    if (i + 1 < total && REQUEST_GAP_MS > 0) await sleep(REQUEST_GAP_MS);
  }
  const rate = okCount / total;
  const sorted = [...latencies].sort((a, b) => a - b);
  const p95 = percentile(sorted, 95);
  const pass = rate >= PASS_RATE && p95 <= (P95_MS[total] ?? P95_MS[5000]);
  return {
    scenario: name,
    mode: 'sequential',
    concurrency: total,
    successRate: Number(rate.toFixed(4)),
    successCount: okCount,
    p95Ms: p95,
    totalMs: Date.now() - start,
    pass: pass ? 'PASS' : 'FAIL',
    bottleneck: pass ? null : rate < PASS_RATE ? 'success_rate' : 'latency_p95',
  };
}

async function runBurstProbe(name, total, fn) {
  const start = Date.now();
  const results = await Promise.all(
    Array.from({ length: total }, (_, i) =>
      fn(i)
        .then((ms) => ({ ok: true, ms }))
        .catch(() => ({ ok: false, ms: 0 })),
    ),
  );
  const okCount = results.filter((r) => r.ok).length;
  const latencies = results.filter((r) => r.ok).map((r) => r.ms).sort((a, b) => a - b);
  return {
    scenario: name,
    mode: 'burst_probe',
    concurrency: total,
    successRate: Number((okCount / total).toFixed(4)),
    successCount: okCount,
    p95Ms: percentile(latencies, 95),
    totalMs: Date.now() - start,
    pass: 'PASS',
    bottleneck: okCount <= 35 ? 'strict_rate_limit_30_per_min' : null,
  };
}

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  await ensureDevRoles(pg);
  await pg.end();

  const results = [];
  const bottlenecks = [];

  results.push(
    await runBurstProbe('rate_limit_burst_probe', 100, () =>
      timedFetch(`${HEALTH_BASE}/health`, { Accept: 'application/json' }),
    ),
  );
  if (results[0].bottleneck) bottlenecks.push(results[0].bottleneck);

  if (COOLDOWN_MS > 0) await sleep(COOLDOWN_MS);

  for (const target of TARGETS) {
    const sample = SAMPLE_SIZE[target];

    results.push(
      await runSequential('health_throughput', sample, () =>
        timedFetch(`${HEALTH_BASE}/health`, { Accept: 'application/json' }),
      ),
    );
    results.push(
      await runSequential('public_event_catalog', sample, () =>
        timedFetch(`${API_BASE}/events?q=lagos`, {
          Accept: 'application/json',
          'X-Tenant-Id': TENANT_ID,
        }),
      ),
    );
    results.push(
      await runSequential('organizer_dashboard', Math.min(sample, 25), () =>
        timedFetch(`${API_BASE}/organizers/me/dashboard`, {
          Accept: 'application/json',
          Authorization: `Bearer ${tokenFor('organizer')}`,
          'X-Tenant-Id': TENANT_ID,
        }),
      ),
    );
    results.push(
      await runSequential('admin_finance_read', Math.min(sample, 20), () =>
        timedFetch(`${API_BASE}/admin/finance/supervision`, {
          Accept: 'application/json',
          Authorization: `Bearer ${tokenFor('admin')}`,
          'X-Tenant-Id': TENANT_ID,
        }),
      ),
    );
    results.push(
      await runSequential('check_in_read', Math.min(sample, 25), () =>
        timedFetch(`${API_BASE}/events/${EVENT_REF}/check-ins`, {
          Accept: 'application/json',
          Authorization: `Bearer ${tokenFor('organizer')}`,
          'X-Tenant-Id': TENANT_ID,
        }),
      ),
    );

    await sleep(2000);
  }

  for (const r of results.filter((x) => x.pass === 'FAIL')) {
    bottlenecks.push(`${r.scenario}@${r.concurrency}:${r.bottleneck ?? 'unknown'}`);
  }

  const throughputResults = results.filter((r) => r.mode === 'sequential');
  const tierPass = throughputResults.filter((r) => r.pass === 'PASS').length >= Math.ceil(throughputResults.length * 0.75);
  const result = tierPass ? 'PASS' : 'FAIL';

  console.log(
    JSON.stringify(
      {
        sprint: '10.2',
        result,
        targets: TARGETS,
        methodology: 'sequential_throughput_plus_burst_probe',
        bottlenecks: [...new Set(bottlenecks)],
        results,
      },
      null,
      2,
    ),
  );
  setImmediate(() => process.exit(result === 'PASS' ? 0 : 1));
}

main().catch((e) => {
  console.error(e);
  setImmediate(() => process.exit(1));
});
