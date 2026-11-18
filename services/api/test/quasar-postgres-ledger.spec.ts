import { createHmac, randomUUID } from 'crypto';
import { Pool } from 'pg';
import { UnauthorizedException } from '@nestjs/common';
import { QuasarSecretsCrypto } from '../src/modules/quasar/quasar-secrets.crypto';
import { QuasarVaultService } from '../src/modules/quasar/quasar-vault.service';
import { QuasarAuditService } from '../src/modules/quasar/quasar-audit.service';
import { QuasarWebhookService } from '../src/modules/quasar/quasar-webhook.service';
import { TicketCaptureService } from '../src/modules/commerce/ticket-capture.service';
import { OrganizerPayoutService } from '../src/modules/commerce/organizer-payout.service';
import { LedgerService } from '../src/modules/payments/ledger.service';
import { FinanceStateService } from '../src/modules/payments/finance-state.service';
import { payoutStateFromCreateResponse } from '../src/modules/quasar/quasar-state';

/**
 * Proves Quasar webhooks update tickets and payouts through the existing
 * Postgres functions. Refuses any database that is not the local Owanbe
 * development instance on port 5436.
 */
const DATABASE_URL = devDatabaseUrl();
const SIGNING_SECRET = 'ledger-signing-secret';
const TENANT_API_KEY = 'sk_test_ledgerproofkey';
const FORBIDDEN = /sk_live_|sk_test_|qps_sec_|qps_|qpc_|webhookSigningSecret/;

function devDatabaseUrl(): string {
  const url = process.env.OWANBE_DEV_DATABASE_URL ?? 'postgres://postgres:postgres@localhost:5436/owanbe';
  const parsed = new URL(url);
  if (parsed.hostname !== 'localhost' && parsed.hostname !== '127.0.0.1') {
    throw new Error('Refusing a non-local database for the Quasar ledger proof');
  }
  if (parsed.port !== '5436' || !parsed.pathname.endsWith('/owanbe')) {
    throw new Error('Refusing a database other than the local Owanbe development database');
  }
  return url;
}

function sign(body: Buffer): string {
  return createHmac('sha256', SIGNING_SECRET).update(body).digest('hex');
}

describe('quasar postgres ledger', () => {
  const pool = new Pool({ connectionString: DATABASE_URL });
  const tenantId = randomUUID();
  const organizerUserId = randomUUID();
  const payerId = randomUUID();
  const organizerId = randomUUID();
  const eventId = randomUUID();
  const orderId = randomUUID();
  const paymentId = randomUUID();
  const delayedPaymentId = randomUUID();
  const delayedOrderId = randomUUID();
  const quasarTenantId = randomUUID();
  const payoutId = randomUUID();
  const failedPayoutId = randomUUID();
  const rejectedPayoutId = randomUUID();
  const heldPayoutId = randomUUID();
  let webhooks: QuasarWebhookService;
  let merchantId = '';

  beforeAll(async () => {
    const schema = await pool.query<{ merchants: string | null; audit: string | null; capture: string | null }>(
      `SELECT to_regclass('public.quasar_merchant_accounts')::text AS merchants,
              to_regclass('public.quasar_audit_log')::text AS audit,
              to_regprocedure('owanbe_apply_ticket_payment_capture(uuid,uuid,payment_provider,text,text,jsonb,uuid,uuid,uuid,uuid,bigint,bigint,bigint)')::text AS capture`,
    );
    if (!schema.rows[0]?.merchants || !schema.rows[0]?.audit || !schema.rows[0]?.capture) {
      throw new Error('Apply 074_quasar_sandbox.sql and 075_quasar_sandbox_audit.sql to the local development database first');
    }

    const crypto = new QuasarSecretsCrypto({
      get: (key: string) => (key === 'EMAIL_SECRETS_ENCRYPTION_KEY' ? 'quasar-ledger-proof-encryption-key' : ''),
    } as never);
    const vault = new QuasarVaultService(pool, crypto);
    const ledger = new LedgerService(pool);
    const finance = new FinanceStateService(pool, { write: async () => undefined } as never);
    const capture = new TicketCaptureService(pool, ledger, finance, {
      sendTicketConfirmation: async () => undefined,
    } as never, { inc: () => undefined } as never, { emit: () => undefined } as never);
    const payouts = new OrganizerPayoutService(
      pool,
      { get: () => '' } as never,
      {} as never,
      ledger,
      finance,
      {} as never,
      {} as never,
      {} as never,
      { isConfigured: () => true, keyEnvironment: () => 'test' } as never,
      {} as never,
    );
    webhooks = new QuasarWebhookService(pool, vault, capture, payouts, new QuasarAuditService(pool));

    await pool.query(
      `INSERT INTO tenants (id, slug, name) VALUES ($1, $2, 'Quasar ledger proof')`,
      [tenantId, `quasar-proof-${tenantId.slice(0, 8)}`],
    );
    await pool.query(
      `INSERT INTO users (id, tenant_id, email, display_name, status)
       VALUES ($1, $3, $4, 'Organizer', 'active'), ($2, $3, $5, 'Attendee', 'active')`,
      [organizerUserId, payerId, tenantId, `org-${organizerUserId.slice(0, 8)}@example.test`, `payer-${payerId.slice(0, 8)}@example.test`],
    );
    await pool.query(
      `INSERT INTO organizers (id, tenant_id, owner_user_id, display_name, slug)
       VALUES ($1, $2, $3, 'Proof Organizer', $4)`,
      [organizerId, tenantId, organizerUserId, `org-${organizerId.slice(0, 8)}`],
    );
    await pool.query(
      `INSERT INTO events (id, tenant_id, organizer_id, title, slug, status, starts_at)
       VALUES ($1, $2, $3, 'Proof Event', $4, 'published', now() + interval '2 days')`,
      [eventId, tenantId, organizerId, `event-${eventId.slice(0, 8)}`],
    );
    for (const [id, key] of [
      [orderId, 'order-main'],
      [delayedOrderId, 'order-delayed'],
    ] as const) {
      await pool.query(
        `INSERT INTO ticket_orders (
           id, tenant_id, organizer_id, event_id, buyer_user_id, status, currency,
           subtotal_minor, platform_fee_minor, total_minor, idempotency_key
         ) VALUES ($1, $2, $3, $4, $5, 'pending_payment', 'NGN', 5000000, 0, 5000000, $6)`,
        [id, tenantId, organizerId, eventId, payerId, `${key}-${id}`],
      );
      await pool.query(
        `INSERT INTO ticket_order_lines (
           tenant_id, ticket_order_id, tier_id, tier_name, unit_price_minor, quantity, line_subtotal_minor, currency
         ) VALUES ($1, $2, 'tier-proof', 'General', 5000000, 1, 5000000, 'NGN')`,
        [tenantId, id],
      );
    }
    await pool.query(
      `INSERT INTO ticket_payments (
         id, tenant_id, ticket_order_id, provider, status, currency, idempotency_key, metadata
       ) VALUES
         ($1, $3, $4, 'quaser', 'initiated', 'NGN', $6, $8::jsonb),
         ($2, $3, $5, 'quaser', 'initiated', 'NGN', $7, $8::jsonb)`,
      [
        paymentId,
        delayedPaymentId,
        tenantId,
        orderId,
        delayedOrderId,
        `pay-${paymentId}`,
        `pay-${delayedPaymentId}`,
        JSON.stringify({ expected_total_minor: '5000000' }),
      ],
    );

    const merchant = await vault.insert({
      owanbeTenantId: tenantId,
      ownerKind: 'organizer',
      ownerId: organizerId,
      quasarTenantId,
      slug: `owanbe-proof-${organizerId.slice(0, 8)}`,
      code: null,
      vertical: 'owanbe',
      environment: 'test',
      apiKey: TENANT_API_KEY,
      apiKeyHint: 'configured',
      walletOwnerId: organizerId,
    });
    merchantId = merchant.id;
    await vault.saveWebhook(merchant.id, 'http://127.0.0.1:8080/webhooks/quasar/' + quasarTenantId, SIGNING_SECRET);

    for (const [id, reference] of [
      [payoutId, 'proof-success'],
      [failedPayoutId, 'proof-failed'],
      [rejectedPayoutId, 'proof-rejected'],
      [heldPayoutId, 'proof-held'],
    ] as const) {
      await pool.query(
        `INSERT INTO organizer_payouts (
           id, tenant_id, organizer_id, ticket_order_id, currency, amount_minor, status, idempotency_key, metadata
         ) VALUES ($1, $2, $3, $4, 'NGN', 100000, 'pending', $5, '{"quasarStatus":"AWAITING_APPROVAL"}'::jsonb)`,
        [id, tenantId, organizerId, orderId, `payout-${id}`],
      );
      await pool.query(
        `INSERT INTO quasar_transfers (
           owanbe_tenant_id, merchant_account_id, organizer_payout_id, reference, amount_major, currency, quasar_status, destination
         ) VALUES ($1, $2, $3, $4, '1000.00', 'NGN', 'AWAITING_APPROVAL', '{"accountNumber":"0123456789"}'::jsonb)`,
        [tenantId, merchantId, id, reference],
      );
    }
  }, 30000);

  afterAll(async () => {
    await pool.query(`DELETE FROM quasar_audit_log WHERE owanbe_tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM quasar_webhook_deliveries WHERE merchant_account_id = $1`, [merchantId]).catch(() => undefined);
    await pool.query(`DELETE FROM quasar_transfers WHERE merchant_account_id = $1`, [merchantId]).catch(() => undefined);
    await pool.query(`DELETE FROM quasar_idempotency_keys WHERE merchant_account_id = $1`, [merchantId]).catch(() => undefined);
    await pool.query(`DELETE FROM quasar_merchant_accounts WHERE id = $1`, [merchantId]).catch(() => undefined);
    await pool.query(`DELETE FROM organizer_payouts WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM ticket_entitlements WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM ticket_payment_events WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM ticket_payments WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM ticket_order_lines WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM ledger_lines WHERE transaction_id IN (SELECT id FROM ledger_transactions WHERE tenant_id = $1)`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM ledger_transactions WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM ticket_orders WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM ledger_accounts WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM events WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM organizers WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM users WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
    await pool.query(`DELETE FROM tenants WHERE id = $1`, [tenantId]).catch(() => undefined);
    await pool.end();
  });

  function fundedBody(targetPaymentId: string, reference: string): Buffer {
    return Buffer.from(
      JSON.stringify({
        event: 'virtual_account.funded',
        data: {
          amount: '50000.00',
          currency: 'NGN',
          payerId,
          reference,
          secretKey: TENANT_API_KEY,
          clientSecret: 'qpc_should_not_store',
          webhookSigningSecret: SIGNING_SECRET,
          metadata: { ticketPaymentId: targetPaymentId },
        },
      }),
    );
  }

  it('rejects an invalid HMAC and a malformed body', async () => {
    const body = fundedBody(paymentId, 'funded-main');
    await expect(webhooks.handleSignedWebhook(quasarTenantId, body, 'deadbeef')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    const malformed = Buffer.from('{');
    await expect(webhooks.handleSignedWebhook(quasarTenantId, malformed, sign(malformed))).rejects.toMatchObject({
      response: { code: 'INVALID_JSON' },
    });
  });

  it('captures a ticket through owanbe_apply_ticket_payment_capture and stays idempotent', async () => {
    const body = fundedBody(paymentId, 'funded-main');
    const first = await webhooks.handleSignedWebhook(quasarTenantId, body, sign(body));
    const second = await webhooks.handleSignedWebhook(quasarTenantId, body, sign(body));
    const third = await webhooks.handleSignedWebhook(quasarTenantId, body, sign(body));

    expect(first).toMatchObject({ ok: true, reason: 'applied' });
    expect(second).toMatchObject({ ok: true, duplicate: true, reason: 'duplicate_delivery' });
    expect(third).toMatchObject({ ok: true, duplicate: true });

    const payment = await pool.query<{ status: string }>(
      `SELECT status::text FROM ticket_payments WHERE id = $1`,
      [paymentId],
    );
    const order = await pool.query<{ status: string }>(
      `SELECT status::text FROM ticket_orders WHERE id = $1`,
      [orderId],
    );
    const ledger = await pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM ledger_transactions
       WHERE tenant_id = $1 AND idempotency_key = $2`,
      [tenantId, `ticket_capture:${paymentId}`],
    );
    expect(payment.rows[0]?.status).toBe('captured');
    expect(order.rows[0]?.status).toBe('fulfilled');
    expect(ledger.rows[0]?.n).toBe('1');

    const replay = Buffer.from(
      JSON.stringify({
        event: 'virtual_account.funded',
        data: {
          amount: '50000.00',
          payerId,
          reference: 'funded-main-replay',
          metadata: { ticketPaymentId: paymentId },
        },
      }),
    );
    const replayed = await webhooks.handleSignedWebhook(quasarTenantId, replay, sign(replay));
    expect(replayed.ok).toBe(true);
    const ledgerAfter = await pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM ledger_transactions
       WHERE tenant_id = $1 AND idempotency_key = $2`,
      [tenantId, `ticket_capture:${paymentId}`],
    );
    expect(ledgerAfter.rows[0]?.n).toBe('1');
    expect(payment.rows[0]?.status).toBe('captured');
  });

  it('applies a delayed funded webhook once', async () => {
    await new Promise((resolve) => setTimeout(resolve, 250));
    const body = fundedBody(delayedPaymentId, 'funded-delayed');
    const late = await webhooks.handleSignedWebhook(quasarTenantId, body, sign(body));
    const again = await webhooks.handleSignedWebhook(quasarTenantId, body, sign(body));
    expect(late).toMatchObject({ ok: true, reason: 'applied' });
    expect(again.duplicate).toBe(true);
    const ledger = await pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM ledger_transactions WHERE idempotency_key = $1`,
      [`ticket_capture:${delayedPaymentId}`],
    );
    expect(ledger.rows[0]?.n).toBe('1');
  });

  it('keeps a payout unpaid until transfer.success writes the existing payout ledger', async () => {
    expect(payoutStateFromCreateResponse('SUCCESS')).toBe('awaiting_approval');
    const before = await pool.query<{ status: string; quasar_status: string }>(
      `SELECT p.status::text, t.quasar_status
       FROM organizer_payouts p
       JOIN quasar_transfers t ON t.organizer_payout_id = p.id
       WHERE p.id = $1`,
      [heldPayoutId],
    );
    expect(before.rows[0]).toEqual({ status: 'pending', quasar_status: 'AWAITING_APPROVAL' });

    const success = Buffer.from(
      JSON.stringify({ event: 'transfer.success', data: { reference: 'proof-success', status: 'SUCCESS' } }),
    );
    const ack = await webhooks.handleSignedWebhook(quasarTenantId, success, sign(success));
    expect(ack).toMatchObject({ ok: true, reason: 'completed' });
    const again = await webhooks.handleSignedWebhook(quasarTenantId, success, sign(success));
    expect(again.duplicate).toBe(true);

    const paid = await pool.query<{ status: string }>(
      `SELECT status::text FROM organizer_payouts WHERE id = $1`,
      [payoutId],
    );
    const ledger = await pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM ledger_transactions WHERE idempotency_key = $1`,
      [`organizer_payout_release:${payoutId}`],
    );
    const held = await pool.query<{ status: string }>(
      `SELECT status::text FROM organizer_payouts WHERE id = $1`,
      [heldPayoutId],
    );
    expect(paid.rows[0]?.status).toBe('completed');
    expect(ledger.rows[0]?.n).toBe('1');
    expect(held.rows[0]?.status).toBe('pending');
  });

  it('records FAILED, REJECTED, and duplicate payout references without marking them paid', async () => {
    const failed = Buffer.from(
      JSON.stringify({
        event: 'transfer.failed',
        data: { reference: 'proof-failed', status: 'FAILED', reason: 'insufficient_balance' },
      }),
    );
    const rejected = Buffer.from(
      JSON.stringify({
        event: 'transfer.failed',
        data: { reference: 'proof-rejected', status: 'REJECTED' },
      }),
    );
    await webhooks.handleSignedWebhook(quasarTenantId, failed, sign(failed));
    await webhooks.handleSignedWebhook(quasarTenantId, rejected, sign(rejected));

    const rows = await pool.query<{ id: string; status: string; failure_code: string | null }>(
      `SELECT id, status::text, failure_code FROM organizer_payouts WHERE id = ANY($1::uuid[])`,
      [[failedPayoutId, rejectedPayoutId]],
    );
    const byId = new Map(rows.rows.map((row) => [row.id, row]));
    expect(byId.get(failedPayoutId)?.status).toBe('failed');
    expect(byId.get(failedPayoutId)?.failure_code).toBe('QUASAR_TRANSFER_FAILED');
    expect(byId.get(rejectedPayoutId)?.status).toBe('failed');
    expect(byId.get(rejectedPayoutId)?.failure_code).toBe('QUASAR_TRANSFER_REJECTED');

    await expect(
      pool.query(
        `INSERT INTO quasar_transfers (
           owanbe_tenant_id, merchant_account_id, organizer_payout_id, reference, amount_major, currency, quasar_status, destination
         ) VALUES ($1, $2, $3, 'proof-success', '1000.00', 'NGN', 'PENDING', '{}'::jsonb)`,
        [tenantId, merchantId, heldPayoutId],
      ),
    ).rejects.toMatchObject({ code: '23505' });
  });

  it('rejects a live environment row and keeps secrets out of audit and webhook records', async () => {
    await expect(
      pool.query(
        `INSERT INTO quasar_merchant_accounts (
           owanbe_tenant_id, owner_kind, owner_id, quasar_tenant_id, slug, vertical, environment,
           api_key_ciphertext, api_key_hint, wallet_owner_id
         ) VALUES ($1, 'organizer', $2, $3, 'live-row', 'owanbe', 'live', 'ciphertext', 'configured', $2)`,
        [tenantId, organizerId, randomUUID()],
      ),
    ).rejects.toMatchObject({ code: '23514' });

    const stored = await pool.query<{ blob: string }>(
      `SELECT detail::text AS blob FROM quasar_audit_log WHERE owanbe_tenant_id = $1
       UNION ALL
       SELECT payload::text FROM quasar_webhook_deliveries WHERE merchant_account_id = $2
       UNION ALL
       SELECT api_key_hint FROM quasar_merchant_accounts WHERE id = $2
       UNION ALL
       SELECT COALESCE(metadata::text, '') FROM organizer_payouts WHERE tenant_id = $1`,
      [tenantId, merchantId],
    );
    const combined = stored.rows.map((row) => row.blob).join('\n');
    expect(combined).not.toMatch(FORBIDDEN);
    expect(combined).not.toContain(SIGNING_SECRET);
    expect(combined).not.toContain(TENANT_API_KEY);
  });
});
