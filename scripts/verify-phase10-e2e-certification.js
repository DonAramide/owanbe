#!/usr/bin/env node
/**
 * Phase 10 Sprint 10.1 — End-to-end workflow certification.
 */
const { Client } = require('../services/api/node_modules/pg');
const {
  DATABASE_URL,
  TENANT_ID,
  EVENT_REF,
  ORGANIZER_ID,
  api,
  waitForApi,
  ensureDevRoles,
  ensureMockQuaser,
  waitForPaymentCaptured,
} = require('./lib/phase10-config');

const workflows = {
  attendee: 'FAIL',
  organizer: 'FAIL',
  vendor: 'FAIL',
  admin: 'FAIL',
  superAdmin: 'FAIL',
};
const steps = {};
const evidence = {};

async function main() {
  if (!(await waitForApi())) {
    console.error(JSON.stringify({ error: 'API unreachable' }, null, 2));
    process.exit(1);
  }

  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();

  try {
    await ensureMockQuaser();
    await ensureDevRoles(pg);

    // ── Attendee: Discover → Buy → Pay → Ticket → Check-in ──
    const discover = await api('GET', '/events', { role: 'attendee', tenantId: TENANT_ID });
    const eventDetail = await api('GET', `/events/${EVENT_REF}`, { role: 'attendee', tenantId: TENANT_ID });
    steps.attendee_discover = discover.ok && eventDetail.ok;

    const idem = `p10-e2e-${Date.now()}`;
    const order = await api(
      'POST',
      `/events/${EVENT_REF}/ticket-orders`,
      {
        role: 'attendee',
        body: { attendeeId: require('./lib/phase10-config').USERS.attendee.id, currency: 'NGN', items: [{ tierId: 'tier_ga', quantity: 1 }] },
        headers: { 'Idempotency-Key': idem },
      },
    );
    const orderId = order.json?.order?.id;
    steps.attendee_order = Boolean(order.ok && orderId);

    const pay = await api('POST', `/ticket-orders/${orderId}/payments`, {
      role: 'attendee',
      headers: { 'Idempotency-Key': `${idem}_pay` },
    });
    const captured = orderId ? await waitForPaymentCaptured(pg, orderId) : null;
    steps.attendee_pay = pay.ok && captured?.status === 'captured';

    const entRow = orderId
      ? await pg.query(
          `SELECT ticket_code FROM ticket_entitlements
           WHERE ticket_order_id = $1 ORDER BY issued_at DESC LIMIT 1`,
          [orderId],
        )
      : { rows: [] };
    const ticketCode = entRow.rows[0]?.ticket_code;
    steps.attendee_ticket = Boolean(ticketCode);
    const checkIn = await api('POST', `/events/${EVENT_REF}/check-ins`, {
      role: 'organizer',
      body: { ticketCode, source: 'phase10-cert' },
    });
    steps.attendee_checkin = checkIn.ok || checkIn.json?.duplicate === true;

    workflows.attendee =
      steps.attendee_discover && steps.attendee_order && steps.attendee_pay && steps.attendee_ticket && steps.attendee_checkin
        ? 'PASS'
        : 'FAIL';

    // ── Organizer: Create → Publish → Revenue → Payout request ──
    const create = await api('POST', '/events', {
      role: 'organizer',
      body: {
        title: `Phase10 Cert ${Date.now()}`,
        slug: `p10-cert-${Date.now()}`,
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        currency: 'NGN',
      },
    });
    const newEventId = create.json?.id ?? create.json?.externalRef;
    steps.organizer_create = create.ok;

    if (newEventId) {
      const publish = await api('POST', `/events/${newEventId}/publish`, { role: 'organizer' });
      steps.organizer_publish = publish.ok;
    }

    const revenue = await api('GET', `/events/${EVENT_REF}/finance/summary`, { role: 'organizer' });
    steps.organizer_revenue = revenue.ok && revenue.json?.ticketRevenueMinor !== undefined;

    const payout = await api('POST', `/organizers/${ORGANIZER_ID}/payouts?amountMinor=100000`, { role: 'organizer' });
    steps.organizer_payout = payout.ok || payout.status === 422;

    workflows.organizer =
      steps.organizer_create && steps.organizer_revenue && steps.organizer_payout ? 'PASS' : 'FAIL';

    // ── Vendor: Apply → Participate ──
    const vendorEvents = await api('GET', '/vendor/events', { role: 'vendor' });
    const vendorApply = await api('POST', `/vendor/events/${EVENT_REF}/apply`, { role: 'vendor' });
    steps.vendor_apply = vendorApply.ok || vendorApply.status === 409 || vendorApply.status === 422;
    const vendorFinance = await api('GET', '/vendor/finance/summary', { role: 'vendor' });
    steps.vendor_finance = vendorFinance.ok;
    workflows.vendor = vendorEvents.ok && steps.vendor_apply && steps.vendor_finance ? 'PASS' : 'FAIL';

    // ── Admin: Monitor → Reconcile → Audit ──
    const dash = await api('GET', '/admin/platform/dashboard', { role: 'admin' });
    const recon = await api('GET', '/admin/finance/supervision', { role: 'admin' });
    const audit = await api('GET', '/admin/audit/timeline', { role: 'admin' });
    steps.admin_monitor = dash.ok;
    steps.admin_reconcile = recon.ok;
    steps.admin_audit = audit.ok;
    workflows.admin = dash.ok && recon.ok && audit.ok ? 'PASS' : 'FAIL';

    // ── Super Admin ──
    const overview = await api('GET', '/super-admin/platform/overview', { role: 'superAdmin', tenantId: undefined });
    const tenants = await api('GET', '/super-admin/tenants', { role: 'superAdmin', tenantId: undefined });
    const flags = await api('GET', `/super-admin/feature-flags/${TENANT_ID}`, { role: 'superAdmin', tenantId: undefined });
    const analytics = await api('GET', '/super-admin/analytics/platform', { role: 'superAdmin', tenantId: undefined });
    steps.super_overview = overview.ok;
    steps.super_tenants = tenants.ok;
    steps.super_flags = flags.ok;
    steps.super_analytics = analytics.ok;
    workflows.superAdmin = overview.ok && tenants.ok && flags.ok && analytics.ok ? 'PASS' : 'FAIL';

    evidence.ticketCode = ticketCode;
    evidence.orderId = orderId;

    const passed = Object.values(workflows).filter((v) => v === 'PASS').length;
    const result = passed === 5 ? 'PASS' : 'FAIL';

    console.log(
      JSON.stringify(
        {
          sprint: '10.1',
          result,
          score: `${passed}/5`,
          workflows,
          steps,
          evidence,
        },
        null,
        2,
      ),
    );
    process.exit(result === 'PASS' ? 0 : 1);
  } finally {
    await pg.end().catch(() => undefined);
  }
}

main().catch((e) => {
  console.error(e);
  setImmediate(() => process.exit(1));
});
