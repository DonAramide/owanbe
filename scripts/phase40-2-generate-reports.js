#!/usr/bin/env node
/** Regenerate Phase 40.2 markdown reports from latest JSON result. */
const fs = require('fs');
const path = require('path');

const resultsDir = path.join(__dirname, '../docs/phase40/results');
const reportDir = path.join(__dirname, '../docs/phase40');

const files = fs.readdirSync(resultsDir).filter((f) => f.startsWith('phase40-2-') && f.endsWith('.json'));
if (!files.length) {
  console.error('No phase40-2-*.json results found');
  process.exit(1);
}
files.sort();
const latest = [...files].reverse().find((f) => {
  try {
    const j = JSON.parse(fs.readFileSync(path.join(resultsDir, f), 'utf8'));
    return j.migrations?.result === 'PASS' || j.customer != null;
  } catch {
    return false;
  }
}) ?? files[files.length - 1];
const results = JSON.parse(fs.readFileSync(path.join(resultsDir, latest), 'utf8'));

function stepTable(steps) {
  if (!steps) return '_No data_\n';
  return Object.entries(steps)
    .map(([id, s]) => `| ${id} | ${s.pass ? 'PASS' : 'FAIL'} | ${s.status ?? ''} | ${s.note ?? s.error ?? s.requestId ?? ''} |`)
    .join('\n');
}

const finished = results.summary?.finishedAt ?? new Date().toISOString();
const outFile = path.join(resultsDir, latest);

const migReport = `# Phase 40.2 — Migration Validation Report

**Generated:** ${finished}  
**Result:** ${results.migrations?.result ?? 'UNKNOWN'}  
**Source:** \`${latest}\`

## History (034–038)

| ID | Filename | Applied |
|----|----------|---------|
${(results.migrations?.history ?? []).map((h) => `| ${h.id} | ${h.filename} | ${h.applied_at} |`).join('\n')}

## Table validation

| Migration | OK |
|-----------|-----|
${(results.migrations?.validation ?? []).map((v) => `| ${v.id} | ${v.ok ? 'Yes' : 'No'} |`).join('\n')}
`;

const payReport = `# Phase 40.2 — Payment Verification Report

**Generated:** ${finished}  
**Quaser result:** ${results.summary?.quaser ?? 'UNKNOWN'}

| Scenario | Pass | Detail |
|----------|------|--------|
${Object.entries(results.quaser ?? {}).map(([k, v]) => `| ${k} | ${v.pass ? 'PASS' : 'FAIL'} | ${JSON.stringify(v).slice(0, 160)} |`).join('\n')}
`;

const betaReport = `# Phase 40.2 — Beta Script Execution Log

**Generated:** ${finished}  
**Source:** \`${latest}\`

## Customer (C1–C14) — ${results.C_journey?.pass ? 'PASS' : 'PARTIAL'} (${results.C_journey?.passCount ?? '?'}/14)

| Step | Pass | Notes |
|------|------|-------|
${stepTable(results.customer)}

## Vendor (V1–V7) — ${results.V_journey?.pass ? 'PASS' : 'PARTIAL'}

| Step | Pass | Notes |
|------|------|-------|
${stepTable(results.vendor)}

## Admin (A1–A7) — ${results.A_journey?.pass ? 'PASS' : 'PARTIAL'}

| Step | Pass | Notes |
|------|------|-------|
${stepTable(results.admin)}
`;

fs.writeFileSync(path.join(reportDir, 'MIGRATION_VALIDATION_REPORT.md'), migReport);
fs.writeFileSync(path.join(reportDir, 'PAYMENT_VERIFICATION_REPORT.md'), payReport);
fs.writeFileSync(path.join(reportDir, 'BETA_EXECUTION_LOG.md'), betaReport);
console.log(JSON.stringify({ latest, reports: ['MIGRATION_VALIDATION_REPORT.md', 'PAYMENT_VERIFICATION_REPORT.md', 'BETA_EXECUTION_LOG.md'] }, null, 2));
