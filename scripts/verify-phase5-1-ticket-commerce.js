#!/usr/bin/env node
/**
 * Phase 5.1 verification — ticket order → payment → capture → ledger → entitlements.
 * Requires: API running, migrations 016–021 applied, DATABASE_URL reachable from this process.
 *
 * Usage:
 *   node scripts/verify-phase5-1-ticket-commerce.js
 *
 * Env:
 *   API_BASE=http://localhost:8080/v1
 *   TENANT_ID=11111111-1111-4111-8111-111111111111
 *   DEV_USER_ID=22222222-2222-4222-8222-222222222222
 *   DEV_USER_EMAIL=attendee@owanbe.dev
 *   DATABASE_URL=postgres://...  (optional — skips ledger checks if unset)
 */
const API_BASE = (process.env.API_BASE || 'http://localhost:8080/v1').replace(/\/$/, '');
const TENANT_ID = process.env.TENANT_ID || '11111111-1111-4111-8111-111111111111';
const DEV_USER_ID = process.env.DEV_USER_ID || '22222222-2222-4222-8222-222222222222';
const DEV_USER_EMAIL = process.env.DEV_USER_EMAIL || 'attendee@owanbe.dev';
const EVENT_REF = 'evt_lagos_owanbe_2026';
const JWT_SECRET = process.env.SUPABASE_JWT_SECRET || 'dev-jwt-secret-16chars';
const jwt = require('../services/api/node_modules/jsonwebtoken');

function signJwt() {
  return jwt.sign(
    {
      sub: DEV_USER_ID,
      email: DEV_USER_EMAIL,
      app_metadata: { tenant_id: TENANT_ID, roles: ['client'] },
    },
    JWT_SECRET,
    { algorithm: 'HS256', expiresIn: '1h' },
  );
}

const checks = [];

function pass(name, detail) {
  checks.push({ name, ok: true, detail });
  console.log(`✅ ${name}${detail ? ` — ${detail}` : ''}`);
}

function fail(name, detail) {
  checks.push({ name, ok: false, detail });
  console.error(`❌ ${name}${detail ? ` — ${detail}` : ''}`);
}

async function api(method, path, body) {
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-Tenant-Id': TENANT_ID,
      Authorization: `Bearer ${signJwt()}`,
      ...(body ? { 'Idempotency-Key': body.idempotencyKey } : {}),
    },
    body: body ? JSON.stringify(body.payload) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    throw new Error(`${method} ${path} → ${res.status}: ${text}`);
  }
  return json;
}

async function main() {
  const idem = `verify_${Date.now()}`;
  let orderId;
  let paymentId;
  let platformFeeMinor;
  let organizerId;

  try {
    const orderRes = await api('POST', `/events/${EVENT_REF}/ticket-orders`, {
      idempotencyKey: idem,
      payload: {
        attendeeId: DEV_USER_ID,
        currency: 'NGN',
        items: [{ tierId: 'tier_ga', quantity: 1 }],
      },
    });
    orderId = orderRes.order?.id;
    platformFeeMinor = orderRes.order?.platformFeeMinor;
    if (orderId && orderRes.order?.status === 'pending_payment') {
      pass('Ticket Order Created', orderId);
    } else {
      fail('Ticket Order Created', JSON.stringify(orderRes));
    }
  } catch (e) {
    fail('Ticket Order Created', e.message);
    return summary();
  }

  try {
    const payRes = await api('POST', `/ticket-orders/${orderId}/payments`, {
      idempotencyKey: `${idem}_pay`,
      payload: {},
    });
    paymentId = payRes.payment?.id;
    if (paymentId && payRes.payment?.status === 'captured') {
      pass('Payment Initiated', paymentId);
      pass('Capture Received', payRes.capture?.ok !== false ? 'stub auto-capture' : payRes.capture?.reason);
    } else if (paymentId) {
      pass('Payment Initiated', `${paymentId} (${payRes.payment?.status})`);
      fail('Capture Received', `status=${payRes.payment?.status}`);
    } else {
      fail('Payment Initiated', JSON.stringify(payRes));
    }

    if (payRes.entitlements?.length > 0) {
      pass('Ticket Issued', `${payRes.entitlements.length} entitlement(s)`);
      pass('QR Generated', payRes.entitlements[0].qrPayload?.slice(0, 24) + '…');
    } else {
      fail('Ticket Issued', 'no entitlements in payment response');
    }
  } catch (e) {
    fail('Payment Initiated', e.message);
    return summary();
  }

  if (platformFeeMinor && BigInt(platformFeeMinor) > 0n) {
    pass('Platform Fee Calculated', `${platformFeeMinor} minor`);
  } else {
    fail('Platform Fee Calculated', platformFeeMinor);
  }

  const dbUrl = process.env.DATABASE_URL;
  if (!dbUrl) {
    fail('Ledger Posted', 'Set DATABASE_URL to verify ledger');
    fail('Organizer Payable Updated', 'Set DATABASE_URL');
  } else {
    const { Client } = require('../services/api/node_modules/pg');
    const pg = new Client({ connectionString: dbUrl });
    await pg.connect();
    try {
      const journal = await pg.query(
        `SELECT id FROM ledger_transactions
         WHERE tenant_id = $1 AND idempotency_key = $2 AND commerce_kind = 'TICKET'`,
        [TENANT_ID, `ticket_capture:${paymentId}`],
      );
      if (journal.rows.length > 0) {
        pass('Ledger Posted', journal.rows[0].id);
      } else {
        fail('Ledger Posted', 'no TICKET ledger transaction for payment');
      }

      const ord = await pg.query(`SELECT organizer_id FROM ticket_orders WHERE id = $1`, [orderId]);
      organizerId = ord.rows[0]?.organizer_id;

      const payable = await pg.query(
        `SELECT id FROM ledger_accounts
         WHERE tenant_id = $1 AND kind = 'organizer_payable' AND organizer_id = $2`,
        [TENANT_ID, organizerId],
      );
      if (payable.rows[0]) {
        const bal = await pg.query(
          `SELECT COALESCE(SUM(CASE WHEN ll.direction = 'credit' THEN ll.amount_minor ELSE -ll.amount_minor END), 0)::text AS bal
           FROM ledger_lines ll
           INNER JOIN ledger_transactions lt ON lt.id = ll.transaction_id
           WHERE ll.account_id = $1 AND lt.idempotency_key = $2`,
          [payable.rows[0].id, `ticket_capture:${paymentId}`],
        );
        if (BigInt(bal.rows[0]?.bal ?? '0') > 0n) {
          pass('Organizer Payable Updated', `${bal.rows[0].bal} minor credited`);
        } else {
          fail('Organizer Payable Updated', 'zero credit on capture journal');
        }
      } else {
        fail('Organizer Payable Updated', 'account missing');
      }
    } finally {
      await pg.end();
    }
  }

  try {
    const ents = await api('GET', '/me/ticket-entitlements');
    if (ents.items?.some((e) => e.ticketCode)) {
      pass('Attendee Dashboard Updated', `${ents.items.length} entitlement(s) via GET /me/ticket-entitlements`);
    } else {
      fail('Attendee Dashboard Updated', 'empty entitlements list');
    }
  } catch (e) {
    fail('Attendee Dashboard Updated', e.message);
  }

  return summary();
}

function summary() {
  const failed = checks.filter((c) => !c.ok);
  console.log('\n--- Phase 5.1 Gate ---');
  if (failed.length === 0) {
    console.log('ALL CHECKS PASSED — Phase 5.2 may proceed.');
    process.exit(0);
  }
  console.log(`${failed.length} check(s) failed — Phase 5.2 blocked.`);
  process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
