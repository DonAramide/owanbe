#!/usr/bin/env node
/**
 * Phase 5.3 Finance Consolidation — verification gate.
 * Requires API + DB. Uses dev commerce auth headers.
 */
const { Client } = require('../services/api/node_modules/pg');

const API_BASE = (process.env.API_BASE || 'http://localhost:8080/v1').replace(/\/$/, '');
const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const TENANT_ID = process.env.TENANT_ID || '11111111-1111-4111-8111-111111111111';
const DEV_USER_ID = process.env.DEV_USER_ID || '22222222-2222-4222-8222-222222222222';
const DEV_USER_EMAIL = process.env.DEV_USER_EMAIL || 'attendee@owanbe.dev';
const ORGANIZER_ID = process.env.ORGANIZER_ID || '33333333-3333-4333-8333-333333333333';
const EVENT_REF = 'evt_lagos_owanbe_2026';

const report = { checks: {}, evidence: {} };

function check(name, ok, detail) {
  report.checks[name] = ok ? 'PASS' : 'FAIL';
  if (detail !== undefined) report.evidence[name] = detail;
}

async function api(method, path, body, extraHeaders = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-Tenant-Id': TENANT_ID,
      'X-Dev-User-Id': DEV_USER_ID,
      'X-Dev-User-Email': DEV_USER_EMAIL,
      ...extraHeaders,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  return { ok: res.ok, status: res.status, json, text };
}

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();

  // Schema artifacts
  const tables = ['organizer_payouts', 'ticket_refund_cases', 'treasury_settlements'];
  const schema = {};
  for (const t of tables) {
    const r = await pg.query(
      `SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name=$1) AS ok`,
      [t],
    );
    schema[t] = r.rows[0].ok;
  }
  check('Phase 5.3 tables exist', Object.values(schema).every(Boolean), schema);

  const escrow = await pg.query(
    `SELECT escrow_release_delay_hours FROM tenant_finance_settings WHERE tenant_id = $1`,
    [TENANT_ID],
  );
  check('Dev escrow delay is 0 (payout testable)', escrow.rows[0]?.escrow_release_delay_hours === 0, escrow.rows[0]);

  const evt = await pg.query(
    `SELECT id FROM events WHERE tenant_id = $1 AND external_ref = $2`,
    [TENANT_ID, EVENT_REF],
  );
  const eventId = evt.rows[0]?.id;
  check('Dev event exists', !!eventId, { eventId, externalRef: EVENT_REF });

  // 5.3A — Finance summary + payout endpoint surface
  if (eventId) {
    const summary = await api('GET', `/events/${EVENT_REF}/finance/summary`);
    check('Organizer finance summary', summary.ok, summary.json);
    if (summary.ok) {
      check(
        'Summary includes payout fields',
        'availableForPayoutMinor' in summary.json && 'payoutEligible' in summary.json,
        {
          availableForPayoutMinor: summary.json.availableForPayoutMinor,
          payoutEligible: summary.json.payoutEligible,
        },
      );
    }

    const payoutProbe = await api(
      'POST',
      `/organizers/${ORGANIZER_ID}/payouts?amountMinor=1`,
    );
    // INSUFFICIENT or NOT_FOUND is fine — endpoint must exist and authorize
    check(
      'Organizer payout endpoint reachable',
      payoutProbe.status === 200 || payoutProbe.status === 404 || payoutProbe.status === 422,
      { status: payoutProbe.status, body: payoutProbe.json },
    );
  }

  // 5.3B — Ticket refund queue endpoint (admin routes need JWT; probe route registration via 404 vs 401)
  const refundQueue = await api('GET', '/admin/finance/ticket-refunds');
  check(
    'Ticket refund queue endpoint registered',
    refundQueue.status === 401 || refundQueue.status === 403 || refundQueue.status === 200,
    { status: refundQueue.status },
  );

  // 5.3E — Export endpoints
  for (const kind of ['transactions', 'payouts', 'refunds', 'settlements', 'organizer-payouts']) {
    const exp = await api('GET', `/admin/finance/exports/${kind}?format=csv&limit=5`);
    check(
      `Export endpoint: ${kind}`,
      exp.status === 401 || exp.status === 403 || exp.status === 200,
      { status: exp.status },
    );
  }

  // 5.3F — Reconciliation includes ticket commerce checks in service (code artifact)
  const reconSrc = require('fs').readFileSync(
    require('path').join(__dirname, '../services/api/src/modules/payments/reconciliation.service.ts'),
    'utf8',
  );
  check(
    'Ticket reconciliation checks in service',
    reconSrc.includes('payment_capture_ticket') && reconSrc.includes('treasury_settlement_dual_write_mismatch'),
    { markers: ['payment_capture_ticket', 'treasury_settlement_dual_write_mismatch'] },
  );

  // Ledger methods
  const ledgerSrc = require('fs').readFileSync(
    require('path').join(__dirname, '../services/api/src/modules/payments/ledger.service.ts'),
    'utf8',
  );
  check(
    'Organizer payout + ticket refund ledger methods',
    ledgerSrc.includes('applyOrganizerPayoutReleaseLedger') && ledgerSrc.includes('applyTicketRefundLedger'),
    null,
  );

  const passed = Object.values(report.checks).every((v) => v === 'PASS');
  report.overall = passed ? 'PASS' : 'FAIL';
  report.timestamp = new Date().toISOString();

  console.log(JSON.stringify(report, null, 2));
  await pg.end();
  process.exit(passed ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
