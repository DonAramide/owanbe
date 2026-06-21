#!/usr/bin/env node
/**
 * Phase 5.1 full verification gate — evidence-only report.
 */
const { Client } = require('../services/api/node_modules/pg');

const API_BASE = (process.env.API_BASE || 'http://localhost:8080/v1').replace(/\/$/, '');
const HEALTH_BASE = (process.env.HEALTH_BASE || 'http://localhost:8080').replace(/\/$/, '');
const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';
const TENANT_ID = process.env.TENANT_ID || '11111111-1111-4111-8111-111111111111';
const DEV_USER_ID = process.env.DEV_USER_ID || '22222222-2222-4222-8222-222222222222';
const DEV_USER_EMAIL = process.env.DEV_USER_EMAIL || 'attendee@owanbe.dev';
const EVENT_REF = 'evt_lagos_owanbe_2026';
const JWT_SECRET = process.env.SUPABASE_JWT_SECRET || 'dev-jwt-secret-16chars';
const jwt = require('../services/api/node_modules/jsonwebtoken');

function signJwt() {
  return jwt.sign(
    { sub: DEV_USER_ID, email: DEV_USER_EMAIL, app_metadata: { tenant_id: TENANT_ID, roles: ['client'] } },
    JWT_SECRET,
    { algorithm: 'HS256', expiresIn: '1h' },
  );
}

const report = { sections: {}, checks: {}, evidence: {} };

function check(name, ok, detail) {
  report.checks[name] = ok ? 'PASS' : 'FAIL';
  if (detail !== undefined) report.evidence[name] = detail;
}

async function api(method, path, body, idem) {
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-Tenant-Id': TENANT_ID,
      Authorization: `Bearer ${signJwt()}`,
      ...(idem ? { 'Idempotency-Key': idem } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = { raw: text }; }
  if (!res.ok) throw new Error(`${method} ${path} → ${res.status}: ${text}`);
  return json;
}

async function section1(pg) {
  const s = {};
  try {
    const h = await fetch(`${HEALTH_BASE}/health`);
    s.apiHealth = { status: h.status, body: await h.json() };
    check('API Running', h.ok, s.apiHealth);
  } catch (e) {
    s.apiHealth = { error: e.message };
    check('API Running', false, s.apiHealth);
  }

  try {
    await pg.query('SELECT 1');
    s.dbConnected = true;
    check('Database Connected', true, { connection: 'ok' });
  } catch (e) {
    s.dbConnected = false;
    check('Database Connected', false, { error: e.message });
    report.sections.section1 = s;
    return;
  }

  const migrations = [
    'commerce_kind', 'ticket_orders', 'ticket_order_lines', 'ticket_payments',
    'ticket_entitlements', 'organizers', 'event_ticket_tiers', 'tenant_finance_settings',
  ];
  const mig = {};
  for (const t of migrations) {
    const r = await pg.query(
      `SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name=$1) AS ok`,
      [t],
    );
    mig[t] = r.rows[0].ok;
  }
  s.migrationArtifacts = mig;
  check('Migrations Applied', Object.values(mig).every(Boolean), mig);

  const finance = await pg.query(
    `SELECT ticket_platform_fee_bps, vendor_platform_fee_bps, escrow_release_delay_hours
     FROM tenant_finance_settings WHERE tenant_id = $1`,
    [TENANT_ID],
  );
  s.tenantFinanceSettings = finance.rows[0] || null;
  check('Tenant Finance Settings Seeded', finance.rows.length > 0 && finance.rows[0].ticket_platform_fee_bps === 500, s.tenantFinanceSettings);

  const org = await pg.query(`SELECT id, display_name, slug, status FROM organizers WHERE tenant_id = $1`, [TENANT_ID]);
  s.organizer = org.rows[0] || null;
  check('Organizer Entity Exists', !!org.rows[0], s.organizer);

  const evt = await pg.query(
    `SELECT id, title, external_ref, slug, status FROM events WHERE tenant_id = $1 AND external_ref = $2`,
    [TENANT_ID, EVENT_REF],
  );
  s.event = evt.rows[0] || null;
  check('Event Seed Exists', !!evt.rows[0], s.event);

  const tiers = await pg.query(
    `SELECT external_tier_id, name, price_minor, remaining FROM event_ticket_tiers
     WHERE tenant_id = $1 AND event_id = $2 ORDER BY external_tier_id`,
    [TENANT_ID, evt.rows[0]?.id],
  );
  s.tiers = tiers.rows;
  const tierIds = tiers.rows.map((r) => r.external_tier_id);
  check('Tier Seed Exists', tierIds.includes('tier_ga') && tierIds.includes('tier_vip') && tierIds.includes('tier_vvip'), s.tiers);

  report.sections.section1 = s;
  return evt.rows[0]?.id;
}

async function main() {
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();

  const eventUuid = await section1(pg);
  const idem = `gate_${Date.now()}`;
  let orderId, paymentId, organizerId;

  // Section 2
  try {
    const orderRes = await api('POST', `/events/${EVENT_REF}/ticket-orders`, {
      attendeeId: DEV_USER_ID,
      currency: 'NGN',
      items: [{ tierId: 'tier_ga', quantity: 1 }],
    }, idem);

    orderId = orderRes.order?.id;
    const dbOrder = await pg.query(`SELECT * FROM ticket_orders WHERE id = $1`, [orderId]);
    const dbLines = await pg.query(`SELECT * FROM ticket_order_lines WHERE ticket_order_id = $1`, [orderId]);

    report.sections.section2 = {
      apiResponse: orderRes.order,
      dbOrder: dbOrder.rows[0],
      dbLines: dbLines.rows,
    };
    check('Ticket Order Created', !!dbOrder.rows[0] && dbOrder.rows[0].status === 'pending_payment', {
      order_id: orderId,
      attendee_id: dbOrder.rows[0]?.buyer_user_id,
      event_id: dbOrder.rows[0]?.event_id,
      quantity: dbLines.rows.reduce((s, l) => s + l.quantity, 0),
      subtotal_minor: dbOrder.rows[0]?.subtotal_minor,
      platform_fee_minor: dbOrder.rows[0]?.platform_fee_minor,
      total_minor: dbOrder.rows[0]?.total_minor,
      status: dbOrder.rows[0]?.status,
    });
  } catch (e) {
    report.sections.section2 = { error: e.message };
    check('Ticket Order Created', false, e.message);
    await pg.end();
    printReport();
    return;
  }

  // Section 3 — capture payment status before
  const payBefore = await pg.query(
    `SELECT id, status FROM ticket_payments WHERE ticket_order_id = $1`,
    [orderId],
  );

  try {
    const payRes = await api('POST', `/ticket-orders/${orderId}/payments`, {}, `${idem}_pay`);
    paymentId = payRes.payment?.id;

    const dbPay = await pg.query(`SELECT * FROM ticket_payments WHERE id = $1`, [paymentId]);
    report.sections.section3 = {
      apiResponse: payRes.payment,
      dbPayment: dbPay.rows[0],
    };
    check('Payment Initiated', !!dbPay.rows[0], {
      payment_id: paymentId,
      psp_reference: dbPay.rows[0]?.quaser_reference,
      amount_minor: dbPay.rows[0]?.metadata?.expected_total_minor || payRes.payment?.amountExpectedMinor,
      currency: dbPay.rows[0]?.currency,
      payment_status: dbPay.rows[0]?.status,
    });

    // Section 4
    const dbPayAfter = await pg.query(`SELECT * FROM ticket_payments WHERE id = $1`, [paymentId]);
    report.sections.section4 = {
      capturePath: payRes.capture?.ok !== false ? 'dev_auto_capture' : 'webhook',
      statusBefore: payBefore.rows[0]?.status || 'none',
      statusAfter: dbPayAfter.rows[0]?.status,
      capturedAt: dbPayAfter.rows[0]?.captured_at,
      captureMeta: payRes.capture,
    };
    check('Capture Received', dbPayAfter.rows[0]?.status === 'captured', report.sections.section4);
  } catch (e) {
    report.sections.section3 = { error: e.message };
    check('Payment Initiated', false, e.message);
    check('Capture Received', false, e.message);
    await pg.end();
    printReport();
    return;
  }

  // Section 5 — Ledger
  const txn = await pg.query(
    `SELECT lt.* FROM ledger_transactions lt
     WHERE lt.tenant_id = $1 AND lt.idempotency_key = $2`,
    [TENANT_ID, `ticket_capture:${paymentId}`],
  );
  const txnId = txn.rows[0]?.id;
  const lines = txnId
    ? await pg.query(
        `SELECT ll.direction, ll.amount_minor, ll.currency, ll.memo, la.kind, la.code, lt.commerce_kind, lt.ticket_order_id
         FROM ledger_lines ll
         INNER JOIN ledger_accounts la ON la.id = ll.account_id
         INNER JOIN ledger_transactions lt ON lt.id = ll.transaction_id
         WHERE ll.transaction_id = $1
         ORDER BY ll.id`,
        [txnId],
      )
    : { rows: [] };

  report.sections.section5 = {
    transactionId: txnId,
    reason: txn.rows[0]?.reason,
    commerce_kind: txn.rows[0]?.commerce_kind,
    ticket_order_id: txn.rows[0]?.ticket_order_id,
    lines: lines.rows,
  };
  const hasPspDr = lines.rows.some((l) => l.kind === 'psp_clearing' && l.direction === 'debit');
  const hasEscrowCr = lines.rows.some((l) => l.kind === 'escrow_pool' && l.direction === 'credit');
  const hasFeeCr = lines.rows.some((l) => l.kind === 'platform_fees' && l.direction === 'credit');
  const hasOrgCr = lines.rows.some((l) => l.kind === 'organizer_payable' && l.direction === 'credit');
  check('Ledger Posted', !!txnId && hasPspDr && hasEscrowCr && hasFeeCr && hasOrgCr, report.sections.section5);

  // Section 6 — Platform fee
  const ord = await pg.query(`SELECT subtotal_minor, platform_fee_minor, total_minor FROM ticket_orders WHERE id = $1`, [orderId]);
  const subtotal = BigInt(ord.rows[0].subtotal_minor);
  const fee = BigInt(ord.rows[0].platform_fee_minor);
  const total = BigInt(ord.rows[0].total_minor);
  const computedFee = (subtotal * 500n) / 10000n;
  const organizerShare = subtotal;
  report.sections.section6 = {
    ticket_platform_fee_bps: 500,
    gross: total.toString(),
    subtotal: subtotal.toString(),
    fee_amount: fee.toString(),
    computed_fee: computedFee.toString(),
    organizer_share: organizerShare.toString(),
    formula: 'platform_fee = subtotal * 500 / 10000',
    match: fee === computedFee,
  };
  check('Platform Fee Calculated', fee === computedFee && total === subtotal + fee, report.sections.section6);

  // Section 7 — Organizer payable
  organizerId = (await pg.query(`SELECT organizer_id FROM ticket_orders WHERE id = $1`, [orderId])).rows[0].organizer_id;
  const orgAccount = await pg.query(
    `SELECT id, code FROM ledger_accounts WHERE tenant_id = $1 AND kind = 'organizer_payable' AND organizer_id = $2`,
    [TENANT_ID, organizerId],
  );
  const orgCode = orgAccount.rows[0]?.code;
  const creditThisTxn = lines.rows
    .filter((l) => l.kind === 'organizer_payable' && l.direction === 'credit')
    .reduce((s, l) => s + BigInt(l.amount_minor), 0n);
  const balanceAfter = orgAccount.rows[0]
    ? (await pg.query(
        `SELECT COALESCE(SUM(CASE WHEN direction='credit' THEN amount_minor ELSE -amount_minor END),0)::text AS bal
         FROM ledger_lines WHERE account_id = $1`,
        [orgAccount.rows[0].id],
      )).rows[0].bal
    : '0';
  const balanceBefore = (BigInt(balanceAfter) - creditThisTxn).toString();
  report.sections.section7 = {
    account: orgCode,
    balance_before: balanceBefore,
    balance_after: balanceAfter,
    credit_this_capture: creditThisTxn.toString(),
    expected_credit: organizerShare.toString(),
  };
  check('Organizer Payable Updated', creditThisTxn === organizerShare, report.sections.section7);

  // Section 8 — Entitlements
  const ents = await pg.query(
    `SELECT id, ticket_code, status, holder_user_id, metadata FROM ticket_entitlements WHERE ticket_order_id = $1`,
    [orderId],
  );
  report.sections.section8 = ents.rows.map((e) => ({
    entitlement_id: e.id,
    ticket_code: e.ticket_code,
    qr_code: e.metadata?.qr_payload,
    status: e.status,
    attendee_id: e.holder_user_id,
  }));
  const entOk = ents.rows.length >= 1 && ents.rows.every((e) => e.status === 'active' && e.metadata?.qr_payload);
  check('Ticket Issued', entOk, report.sections.section8);
  check('QR Generated', entOk && !!ents.rows[0]?.metadata?.qr_payload, ents.rows[0]?.metadata?.qr_payload);

  // Section 9 — Attendee API
  try {
    const apiEnts = await api('GET', '/me/ticket-entitlements');
    const match = apiEnts.items?.find((i) => i.ticketCode === ents.rows[0]?.ticket_code);
    report.sections.section9 = {
      apiEntitlements: apiEnts.items,
      matchedTicket: match,
      mobileNote: 'Attendee dashboard uses GET /me/ticket-entitlements via attendeeTicketsSyncProvider',
    };
    check('Attendee Dashboard Updated', !!match && match.eventTitle, {
      entitlement_returned: !!match,
      ticket_code: match?.ticketCode,
      event_name: match?.eventTitle,
    });
  } catch (e) {
    report.sections.section9 = { error: e.message };
    check('Attendee Dashboard Updated', false, e.message);
  }

  // Section 10 — Consistency
  const escrowDebits = lines.rows.filter((l) => l.kind === 'escrow_pool' && l.direction === 'debit');
  const escrowCredits = lines.rows.filter((l) => l.kind === 'escrow_pool' && l.direction === 'credit');
  const escrowDr = escrowDebits.reduce((s, l) => s + BigInt(l.amount_minor), 0n);
  const escrowCr = escrowCredits.reduce((s, l) => s + BigInt(l.amount_minor), 0n);
  const feeCr = lines.rows.filter((l) => l.kind === 'platform_fees').reduce((s, l) => s + BigInt(l.amount_minor), 0n);
  const diff = total - (fee + organizerShare);
  report.sections.section10 = {
    ticket_order_total: total.toString(),
    platform_fee: fee.toString(),
    organizer_payable: organizerShare.toString(),
    escrow_gross_in: escrowCr.toString(),
    escrow_out_fee_plus_org: escrowDr.toString(),
    ledger_fee_credit: feeCr.toString(),
    difference: diff.toString(),
  };
  check('Consistency Check', diff === 0n && escrowCr === total && escrowDr === fee + organizerShare, report.sections.section10);

  await pg.end();
  printReport();
}

function printReport() {
  const checks = report.checks;
  const allPass = Object.values(checks).every((v) => v === 'PASS');
  console.log(JSON.stringify(report, null, 2));
  console.log('\n=== PHASE 5.1 VERIFICATION REPORT ===');
  console.log(`Ticket Order Created: ${checks['Ticket Order Created'] || 'FAIL'}`);
  console.log(`Payment Initiated: ${checks['Payment Initiated'] || 'FAIL'}`);
  console.log(`Capture Received: ${checks['Capture Received'] || 'FAIL'}`);
  console.log(`Ledger Posted: ${checks['Ledger Posted'] || 'FAIL'}`);
  console.log(`Platform Fee Calculated: ${checks['Platform Fee Calculated'] || 'FAIL'}`);
  console.log(`Organizer Payable Updated: ${checks['Organizer Payable Updated'] || 'FAIL'}`);
  console.log(`Ticket Issued: ${checks['Ticket Issued'] || 'FAIL'}`);
  console.log(`QR Generated: ${checks['QR Generated'] || 'FAIL'}`);
  console.log(`Attendee Dashboard Updated: ${checks['Attendee Dashboard Updated'] || 'FAIL'}`);
  console.log(`\nOverall Result: ${allPass ? 'PASS' : 'FAIL'}`);
  process.exit(allPass ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
