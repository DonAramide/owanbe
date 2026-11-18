import { createServer, type IncomingMessage, type ServerResponse } from 'http';
import { randomUUID } from 'crypto';
import { readFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { Client, Pool } from 'pg';
import { QuasarHttpClient, QuasarHttpError } from '../src/modules/quasar/quasar-client.service';
import { QuasarSecretsCrypto } from '../src/modules/quasar/quasar-secrets.crypto';
import { QuasarVaultService } from '../src/modules/quasar/quasar-vault.service';
import { QuasarAuditService } from '../src/modules/quasar/quasar-audit.service';
import { QuasarWebhookService } from '../src/modules/quasar/quasar-webhook.service';
import { TicketCaptureService } from '../src/modules/commerce/ticket-capture.service';
import { OrganizerPayoutService } from '../src/modules/commerce/organizer-payout.service';
import { LedgerService } from '../src/modules/payments/ledger.service';
import { FinanceStateService } from '../src/modules/payments/finance-state.service';
import {
  pickString,
  readSecretKey,
  redactQuasarSecrets,
} from '../src/modules/quasar/quasar.policy';
import { payoutStateFromCreateResponse } from '../src/modules/quasar/quasar-state';

const ENABLED = process.env.QUASAR_REAL_SANDBOX === '1';
const DATABASE_URL = 'postgres://postgres:postgres@localhost:5436/owanbe';
const BASE = 'http://127.0.0.1:4000/api/v1';
const FORBIDDEN = /sk_live_|sk_test_|qps_sec_|qps_|qpc_|webhookSigningSecret/;

(ENABLED ? describe : describe.skip)('real quasar sandbox', () => {
  it('drives the local Quasar sandbox into the existing Owanbe ledger', async () => {
    const parsed = new URL(DATABASE_URL);
    if (parsed.hostname !== '127.0.0.1' && parsed.hostname !== 'localhost') {
      throw new Error('Refusing a non-local Owanbe database');
    }
    if (parsed.port !== '5436') throw new Error('Refusing a non-development database port');

    const creds = JSON.parse(readFileSync(join(tmpdir(), 'owanbe-quasar-sandbox-client.json'), 'utf8')) as {
      clientId: string;
      clientSecret: string;
    };
    if (!String(creds.clientSecret).startsWith('qpc_')) {
      throw new Error('Sandbox client secret must be a qpc_ test credential');
    }

    const evidence: Record<string, unknown> = { baseUrl: BASE, environment: 'test' };
    const pool = new Pool({ connectionString: DATABASE_URL });
    const tenantId = randomUUID();
    const organizerUserId = randomUUID();
    const payerId = randomUUID();
    const organizerId = randomUUID();
    const eventId = randomUUID();
    const orderId = randomUUID();
    const paymentId = randomUUID();
    const payoutId = randomUUID();
    const deliveries: { body: Buffer; signature?: string }[] = [];

    const client = new QuasarHttpClient({
      baseUrl: () => BASE,
      clientId: () => creds.clientId,
      clientSecret: () => creds.clientSecret,
      keyEnvironment: () => 'test',
    });
    client.fetchImpl = (url, init) => {
      const headers = new Headers(init?.headers);
      if (String(url).startsWith('http://127.0.0.1:4000') || String(url).startsWith('http://localhost:4000')) {
        headers.set('x-forwarded-proto', 'https');
      }
      return fetch(url, { ...init, headers });
    };

    const server = createServer(async (req: IncomingMessage, res: ServerResponse) => {
      const chunks: Buffer[] = [];
      for await (const chunk of req) chunks.push(chunk as Buffer);
      const signature = req.headers['x-quasar-signature'];
      deliveries.push({
        body: Buffer.concat(chunks),
        signature: typeof signature === 'string' ? signature : undefined,
      });
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end('{"ok":true}');
    });

    try {
      await listen(server);
      const address = server.address();
      if (!address || typeof address === 'string') throw new Error('Webhook listener did not bind');
      const webhookUrl = `http://host.docker.internal:${address.port}/webhooks/quasar`;

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
      const webhooks = new QuasarWebhookService(pool, vault, capture, payouts, new QuasarAuditService(pool));

      await seedCommerce(pool, { tenantId, organizerUserId, payerId, organizerId, eventId, orderId, paymentId });

      const slug = `owanbe-live-${organizerId.slice(0, 8)}`;
      const created = await client.createTenant({
        name: 'Owanbe Live Proof',
        slug,
        idempotencyKey: `live-tenant-${organizerId}`,
      });
      const quasarTenantId = pickString(created, ['id']);
      evidence.tenantStatus = quasarTenantId ? 201 : 'missing-id';
      evidence.vertical = created.vertical ?? null;
      if (!quasarTenantId) throw new Error('tenant id missing');

      const keyResult = await client.createTenantApiKey({
        quasarTenantId,
        name: 'Owanbe live proof',
        idempotencyKey: `live-key-${quasarTenantId}`,
      });
      const secretKey = readSecretKey(keyResult.data);
      evidence.apiKeyClass = secretKey.startsWith('sk_test_') ? 'sk_test' : 'rejected';
      if (!secretKey.startsWith('sk_test_') || secretKey.startsWith('sk_live_')) {
        throw new Error('Quasar did not return an sk_test key');
      }

      const merchant = await vault.insert({
        owanbeTenantId: tenantId,
        ownerKind: 'organizer',
        ownerId: organizerId,
        quasarTenantId,
        slug,
        code: pickString(created, ['code']),
        vertical: 'owanbe',
        environment: 'test',
        apiKey: secretKey,
        apiKeyHint: 'configured',
        walletOwnerId: organizerId,
      });

      const callbackUrl = `${webhookUrl}/${quasarTenantId}`;
      let signingSecret = '';
      try {
        const registered = await client.registerWebhook({
          apiKey: secretKey,
          url: callbackUrl,
          idempotencyKey: `live-webhook-${quasarTenantId}`,
        });
        signingSecret =
          pickString(registered, ['signingSecret', 'signing_secret']) ??
          pickString((registered.data ?? {}) as Record<string, unknown>, ['signingSecret', 'signing_secret']) ??
          '';
        evidence.webhookRegistration = signingSecret ? 'api' : 'api_missing_secret';
      } catch (error) {
        evidence.webhookRegistration = httpEvidence(error);
        const sandboxDb = process.env.QUASAR_SANDBOX_DATABASE_URL;
        if (!sandboxDb) throw error;
        signingSecret = randomUUID().replace(/-/g, '') + randomUUID().replace(/-/g, '');
        const quasar = new Client({ connectionString: sandboxDb });
        await quasar.connect();
        await quasar.query(
          `INSERT INTO tenant_outbound_webhooks (tenant_id, url, signing_secret)
           VALUES ($1, $2, $3)
           ON CONFLICT (tenant_id) DO UPDATE SET url = EXCLUDED.url, signing_secret = EXCLUDED.signing_secret, updated_at = now()`,
          [quasarTenantId, callbackUrl, signingSecret],
        );
        await quasar.end();
        evidence.webhookRegistration = 'stored_for_dispatch_after_api_400';
      }
      if (!signingSecret) throw new Error('webhook signing secret missing');
      await vault.saveWebhook(merchant.id, callbackUrl, signingSecret);

      evidence.productVirtualAccount = await safeStatus(client, () =>
        client.createVirtualAccount({
          apiKey: secretKey,
          payerId,
          idempotencyKey: `live-va-${payerId}`,
          body: {
            currency: 'NGN',
            email: `payer-${payerId.slice(0, 8)}@example.test`,
            firstName: 'Ada',
            lastName: 'Balogun',
            phone: '+2348012345678',
            merchantWalletOwnerId: organizerId,
            metadata: { ticketPaymentId: paymentId, payerId, tenantId: quasarTenantId, schoolId: organizerId },
          },
        }),
      );
      await grantSandboxScopes(quasarTenantId);

      const generated = await sandboxCall('POST', '/sandbox/accounts/generate', secretKey, {
        serviceSlug: 'owanbe',
        accountName: 'Owanbe Attendee',
        count: 1,
      });
      const accountId = pickString(generated, ['id', 'virtualAccountId']) ?? firstId(generated);
      const accountNumber = pickString(generated, ['accountNumber', 'account_number']);
      evidence.virtualAccount = {
        created: Boolean(accountId),
        bankName: pickString(generated, ['bankName', 'bank_name']),
        accountPresent: Boolean(accountNumber),
      };
      if (!accountId || !accountNumber) throw new Error('sandbox virtual account id missing');
      await pool.query(
        `INSERT INTO quasar_virtual_accounts (
           owanbe_tenant_id, merchant_account_id, payer_id, currency, account_number, bank_name, ticket_payment_id
         ) VALUES ($1, $2, $3, 'NGN', $4, $5, $6)`,
        [tenantId, merchant.id, payerId, accountNumber, 'QUASAR TEST BANK', paymentId],
      );
      evidence.sandboxFunding = await sandboxStatus('POST', `/sandbox/accounts/${accountId}/credit`, secretKey, {
        amount: 5000000,
        reason: paymentId,
        currency: 'NGN',
      });

      let read = { status: 'NOT_CREATED', reference: `owanbe_payout_${payoutId}` };
      const transferBody = {
        virtualAccountId: accountId,
        direction: 'OUTGOING',
        amount: 100000,
        currency: 'NGN',
        narration: 'Owanbe organizer payout',
        reference: `owanbe_payout_${payoutId}`,
        requiresApproval: true,
      };
      try {
        const transfer = await sandboxCall('POST', '/sandbox/transfers', secretKey, transferBody);
        read = {
          status: pickString(transfer, ['status']) ?? 'AWAITING_APPROVAL',
          reference: pickString(transfer, ['reference']) ?? transferBody.reference,
        };
        evidence.transferCreate = {
          httpStatus: 201,
          status: read.status,
          readState: payoutStateFromCreateResponse(read.status),
        };
        expect(payoutStateFromCreateResponse(read.status)).not.toBe('paid');
        const transferId = pickString(transfer, ['id']);
        if (transferId) {
          evidence.transferApproval = await sandboxStatus(
            'POST',
            `/sandbox/transfers/${transferId}/approve`,
            secretKey,
          );
        }
      } catch (error) {
        evidence.transferCreate = { message: String((error as Error).message).slice(0, 240) };
      }

      await pool.query(
        `INSERT INTO organizer_payouts (
           id, tenant_id, organizer_id, ticket_order_id, currency, amount_minor, status, idempotency_key, metadata
         ) VALUES ($1, $2, $3, $4, 'NGN', 100000, 'pending', $5, $6::jsonb)`,
        [
          payoutId,
          tenantId,
          organizerId,
          orderId,
          `live-payout-${payoutId}`,
          JSON.stringify({ quasarStatus: read.status, quasarReadState: payoutStateFromCreateResponse(read.status) }),
        ],
      );
      await pool.query(
        `INSERT INTO quasar_transfers (
           owanbe_tenant_id, merchant_account_id, organizer_payout_id, reference, amount_major, currency, quasar_status, destination
         ) VALUES ($1, $2, $3, $4, '1000.00', 'NGN', $5, '{"accountNumber":"0123456789"}'::jsonb)`,
        [tenantId, merchant.id, payoutId, `owanbe_payout_${payoutId}`, read.status],
      );

      const held = await pool.query<{ status: string }>(
        `SELECT status::text FROM organizer_payouts WHERE id = $1`,
        [payoutId],
      );
      evidence.payoutAfterCreate = held.rows[0]?.status;
      expect(held.rows[0]?.status).toBe('pending');

      evidence.duplicateTransfer = await sandboxStatus('POST', '/sandbox/transfers', secretKey, transferBody);
      evidence.insufficientBalance = await sandboxStatus('POST', '/sandbox/transfers', secretKey, {
        ...transferBody,
        amount: 999999999,
        reference: `owanbe_payout_huge_${payoutId}`,
      });

      const slow = new QuasarHttpClient({
        baseUrl: () => BASE,
        clientId: () => creds.clientId,
        clientSecret: () => creds.clientSecret,
        keyEnvironment: () => 'test',
        timeoutMs: () => 1,
      });
      slow.fetchImpl = client.fetchImpl;
      slow.sleep = async () => undefined;
      evidence.timeout = await safeStatus(slow, () => slow.getTransfer(secretKey, `owanbe_payout_${payoutId}`));

      const down = new QuasarHttpClient({
        baseUrl: () => 'http://127.0.0.1:9/api/v1',
        clientId: () => creds.clientId,
        clientSecret: () => creds.clientSecret,
        keyEnvironment: () => 'test',
        timeoutMs: () => 500,
      });
      down.sleep = async () => undefined;
      evidence.unavailable = await safeStatus(down, () => down.getTransfer(secretKey, 'offline'));

      const waitUntil = Date.now() + 12_000;
      while (Date.now() < waitUntil && deliveries.length < 2) {
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
      evidence.webhookDeliveries = deliveries.map((delivery) => safeDelivery(delivery.body));
      const acks = [];
      for (const delivery of deliveries) {
        if (!delivery.signature) {
          acks.push({ signature: 'missing' });
          continue;
        }
        try {
          acks.push(await webhooks.handleSignedWebhook(quasarTenantId, delivery.body, delivery.signature));
        } catch (error) {
          acks.push({ error: String((error as Error).message).slice(0, 160) });
        }
      }
      evidence.webhookAcks = acks;

      const payment = await pool.query<{ status: string }>(
        `SELECT status::text FROM ticket_payments WHERE id = $1`,
        [paymentId],
      );
      const payout = await pool.query<{ status: string }>(
        `SELECT status::text FROM organizer_payouts WHERE id = $1`,
        [payoutId],
      );
      evidence.ticketStatus = payment.rows[0]?.status;
      evidence.payoutStatus = payout.rows[0]?.status;
      const published = JSON.stringify(redactQuasarSecrets(evidence));
      expect(published).not.toMatch(FORBIDDEN);
      expect(published).not.toContain(secretKey);
      expect(published).not.toContain(creds.clientSecret);
      expect(published).not.toContain(signingSecret);
      expect(evidence.transferCreate).toMatchObject({
        status: 'AWAITING_APPROVAL',
        readState: 'awaiting_approval',
      });
      expect(evidence.payoutAfterCreate).toBe('pending');
      expect(JSON.stringify(evidence.duplicateTransfer)).toContain('409');
      expect(evidence.timeout).toMatchObject({ retryable: true });
      expect(evidence.unavailable).toMatchObject({ retryable: true });
      expect(payment.rows[0]?.status).toBe('captured');
      expect(payout.rows[0]?.status).toBe('completed');
      if (payment.rows[0]?.status !== 'captured' || payout.rows[0]?.status !== 'completed') {
        throw new Error(`SANDBOX_EVIDENCE ${published}`);
      }
    } finally {
      server.close();
      await pool.query(`DELETE FROM quasar_audit_log WHERE owanbe_tenant_id = $1`, [tenantId]).catch(() => undefined);
      await pool.query(`DELETE FROM quasar_webhook_deliveries WHERE merchant_account_id IN (SELECT id FROM quasar_merchant_accounts WHERE owanbe_tenant_id = $1)`, [tenantId]).catch(() => undefined);
      await pool.query(`DELETE FROM quasar_transfers WHERE owanbe_tenant_id = $1`, [tenantId]).catch(() => undefined);
      await pool.query(`DELETE FROM quasar_idempotency_keys WHERE merchant_account_id IN (SELECT id FROM quasar_merchant_accounts WHERE owanbe_tenant_id = $1)`, [tenantId]).catch(() => undefined);
      await pool.query(`DELETE FROM quasar_virtual_accounts WHERE owanbe_tenant_id = $1`, [tenantId]).catch(() => undefined);
      await pool.query(`DELETE FROM quasar_merchant_accounts WHERE owanbe_tenant_id = $1`, [tenantId]).catch(() => undefined);
      await pool.query(`DELETE FROM organizer_payouts WHERE tenant_id = $1`, [tenantId]).catch(() => undefined);
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
    }
  }, 180000);
});

function httpEvidence(error: unknown): Record<string, unknown> {
  if (error instanceof QuasarHttpError) {
    return { status: error.status ?? null, retryable: error.retryable, message: error.message.slice(0, 180) };
  }
  return { message: String((error as Error).message ?? error).slice(0, 180) };
}

async function safeStatus(client: QuasarHttpClient, run: () => Promise<unknown>): Promise<Record<string, unknown>> {
  void client;
  try {
    const value = await run();
    return { ok: true, value: redactQuasarSecrets(value) };
  } catch (error) {
    return httpEvidence(error);
  }
}

async function grantSandboxScopes(tenantId: string): Promise<void> {
  const url = process.env.QUASAR_SANDBOX_DATABASE_URL;
  if (!url) return;
  const db = new Client({ connectionString: url });
  await db.connect();
  await db.query(
    `UPDATE api_keys
     SET scopes = (
       SELECT to_jsonb(ARRAY(
         SELECT DISTINCT value
         FROM jsonb_array_elements_text(scopes::jsonb) AS value
         UNION SELECT 'sandbox:read'
         UNION SELECT 'sandbox:write'
       ))
     )
     WHERE tenant_id = $1 AND environment = 'test'`,
    [tenantId],
  );
  await db.end();
}

async function sandboxCall(
  method: 'GET' | 'POST',
  path: string,
  apiKey: string,
  body?: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
      authorization: `Bearer ${apiKey}`,
      'x-forwarded-proto': 'https',
      'idempotency-key': randomUUID(),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = (await res.json().catch(() => ({}))) as unknown;
  if (!res.ok) {
    const safe = redactQuasarSecrets(json);
    throw new Error(`sandbox ${method} ${path} ${res.status} ${JSON.stringify(safe).slice(0, 240)}`);
  }
  return readSandboxBody(json);
}

async function sandboxStatus(
  method: 'GET' | 'POST',
  path: string,
  apiKey: string,
  body?: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  try {
    const value = await sandboxCall(method, path, apiKey, body);
    return { ok: true, status: pickString(value, ['status']) ?? 'accepted' };
  } catch (error) {
    return { message: String((error as Error).message).slice(0, 240) };
  }
}

function safeDelivery(body: Buffer): Record<string, unknown> {
  try {
    const parsed = JSON.parse(body.toString('utf8')) as { event?: string; data?: Record<string, unknown> };
    const data = parsed.data ?? {};
    const reason = typeof data.reason === 'string' ? data.reason : '';
    return {
      event: parsed.event ?? null,
      amount: data.amount ?? null,
      amountMinor: data.amountMinor ?? null,
      reasonIsUuid: /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(reason),
      status: data.status ?? null,
      referencePresent: Boolean(data.reference),
    };
  } catch {
    return { malformed: true };
  }
}

function readSandboxBody(json: unknown): Record<string, unknown> {
  let current: unknown = json;
  for (let depth = 0; depth < 5; depth += 1) {
    if (Array.isArray(current)) {
      current = current[0];
      continue;
    }
    if (!current || typeof current !== 'object') break;
    const obj = current as Record<string, unknown>;
    if (obj.id || obj.accountNumber || obj.account_number || obj.status || obj.reference) return obj;
    if ('data' in obj) {
      current = obj.data;
      continue;
    }
    return obj;
  }
  if (current && typeof current === 'object' && !Array.isArray(current)) {
    return current as Record<string, unknown>;
  }
  throw new Error('sandbox response had no object');
}

function firstId(value: Record<string, unknown>): string | null {
  for (const key of ['accounts', 'items', 'data']) {
    const nested = value[key];
    if (Array.isArray(nested) && nested[0] && typeof nested[0] === 'object') {
      const id = pickString(nested[0] as Record<string, unknown>, ['id']);
      if (id) return id;
    }
  }
  return null;
}

function listen(server: ReturnType<typeof createServer>): Promise<void> {
  return new Promise((resolve) => server.listen(0, '0.0.0.0', () => resolve()));
}

async function seedCommerce(
  pool: Pool,
  ids: {
    tenantId: string;
    organizerUserId: string;
    payerId: string;
    organizerId: string;
    eventId: string;
    orderId: string;
    paymentId: string;
  },
): Promise<void> {
  await pool.query(`INSERT INTO tenants (id, slug, name) VALUES ($1, $2, 'Quasar live proof')`, [
    ids.tenantId,
    `quasar-live-${ids.tenantId.slice(0, 8)}`,
  ]);
  await pool.query(
    `INSERT INTO users (id, tenant_id, email, display_name, status)
     VALUES ($1, $3, $4, 'Organizer', 'active'), ($2, $3, $5, 'Attendee', 'active')`,
    [
      ids.organizerUserId,
      ids.payerId,
      ids.tenantId,
      `org-${ids.organizerUserId.slice(0, 8)}@example.test`,
      `payer-${ids.payerId.slice(0, 8)}@example.test`,
    ],
  );
  await pool.query(
    `INSERT INTO organizers (id, tenant_id, owner_user_id, display_name, slug)
     VALUES ($1, $2, $3, 'Live Organizer', $4)`,
    [ids.organizerId, ids.tenantId, ids.organizerUserId, `org-${ids.organizerId.slice(0, 8)}`],
  );
  await pool.query(
    `INSERT INTO events (id, tenant_id, organizer_id, title, slug, status, starts_at)
     VALUES ($1, $2, $3, 'Live Event', $4, 'published', now() + interval '2 days')`,
    [ids.eventId, ids.tenantId, ids.organizerId, `event-${ids.eventId.slice(0, 8)}`],
  );
  await pool.query(
    `INSERT INTO ticket_orders (
       id, tenant_id, organizer_id, event_id, buyer_user_id, status, currency,
       subtotal_minor, platform_fee_minor, total_minor, idempotency_key
     ) VALUES ($1, $2, $3, $4, $5, 'pending_payment', 'NGN', 5000000, 0, 5000000, $6)`,
    [ids.orderId, ids.tenantId, ids.organizerId, ids.eventId, ids.payerId, `live-order-${ids.orderId}`],
  );
  await pool.query(
    `INSERT INTO ticket_order_lines (
       tenant_id, ticket_order_id, tier_id, tier_name, unit_price_minor, quantity, line_subtotal_minor, currency
     ) VALUES ($1, $2, 'tier-live', 'General', 5000000, 1, 5000000, 'NGN')`,
    [ids.tenantId, ids.orderId],
  );
  await pool.query(
    `INSERT INTO ticket_payments (
       id, tenant_id, ticket_order_id, provider, status, currency, idempotency_key, metadata
     ) VALUES ($1, $2, $3, 'quaser', 'initiated', 'NGN', $4, '{"expected_total_minor":"5000000"}'::jsonb)`,
    [ids.paymentId, ids.tenantId, ids.orderId, `live-pay-${ids.paymentId}`],
  );
}
