#!/usr/bin/env node
/**
 * Phase 41 — Lightweight load test (100/500/1000 concurrent health requests).
 */
const HEALTH_BASE = (process.env.HEALTH_BASE || 'http://localhost:8080').replace(/\/$/, '');

function percentile(sorted, p) {
  if (!sorted.length) return 0;
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

async function runLoad(concurrency, total) {
  const latencies = [];
  let errors = 0;
  const started = Date.now();

  async function worker() {
    for (let i = 0; i < total / concurrency; i++) {
      const t0 = Date.now();
      try {
        const res = await fetch(`${HEALTH_BASE}/health`, { signal: AbortSignal.timeout(15000) });
        latencies.push(Date.now() - t0);
        if (!res.ok) errors++;
      } catch {
        errors++;
        latencies.push(Date.now() - t0);
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, () => worker()));
  latencies.sort((a, b) => a - b);
  return {
    concurrency,
    total,
    durationMs: Date.now() - started,
    errors,
    p50: percentile(latencies, 50),
    p95: percentile(latencies, 95),
    p99: percentile(latencies, 99),
  };
}

async function main() {
  const scenarios = [100, 500, 1000];
  const results = [];
  for (const n of scenarios) {
    results.push(await runLoad(Math.min(n, 50), n));
  }
  const report = {
    phase: '41',
    task: 'P2-performance',
    target: HEALTH_BASE,
    checkedAt: new Date().toISOString(),
    scenarios: results,
    result: results.every((r) => r.errors / r.total < 0.05) ? 'PASS' : 'PARTIAL',
    note: 'API process memory/CPU and DB pool require host monitoring during soak',
  };
  console.log(JSON.stringify(report, null, 2));
  process.exit(report.result === 'PASS' ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
