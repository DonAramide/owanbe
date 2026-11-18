import { createHmac } from 'crypto';
import {
  actionForQuasarEvent,
  apiKeyHint,
  assertQuasarPathAllowed,
  assertTenantApiKey,
  isQuasarSecret,
  majorAmountFromMinor,
  minorUnitsFromQuasarAmount,
  normalizeQuasarBaseUrl,
  quasarKeyEnvironment,
  redactQuasarSecrets,
  unwrapQuasarData,
} from '../src/modules/quasar/quasar.policy';
import { verifyQuaserWebhookSignature } from '../src/modules/payments/quaser-signature.util';
import { IntegrationsModeService } from '../src/integrations/integrations-mode.service';
import configuration from '../src/config/configuration';
import { envValidationSchema } from '../src/config/env.schema';

describe('quasar sandbox policy', () => {
  it('accepts test and fails closed on live', () => {
    expect(quasarKeyEnvironment('test', false)).toBe('test');
    expect(quasarKeyEnvironment(undefined, false)).toBe('test');
    expect(() => quasarKeyEnvironment('test', true)).toThrow(/live is disabled/);
    expect(() => quasarKeyEnvironment('live', false)).toThrow(/live is disabled/);
    expect(() => quasarKeyEnvironment('production', false)).toThrow(/live is disabled/);
  });

  it('does not infer a payment mock from a missing credential', () => {
    const config = (values: Record<string, unknown>) =>
      new IntegrationsModeService({ get: (key: string) => values[key] } as never);
    expect(
      config({
        INTEGRATIONS_MODE: 'development',
        PAYMENT_MOCK_MODE: false,
        QUASER_ROUTER_BASE_URL: '',
      }).allowPaymentStubs(),
    ).toBe(false);
    expect(
      config({
        INTEGRATIONS_MODE: 'development',
        PAYMENT_MOCK_MODE: true,
        QUASER_ROUTER_BASE_URL: '',
      }).allowPaymentStubs(),
    ).toBe(true);
    expect(
      config({
        INTEGRATIONS_MODE: 'production',
        PAYMENT_MOCK_MODE: true,
        QUASER_ROUTER_BASE_URL: '',
      }).allowPaymentStubs(),
    ).toBe(false);
  });

  it('refuses live configuration at boot', () => {
    const previousEnvironment = process.env.QUASAR_ENVIRONMENT;
    const previousLive = process.env.QUASAR_LIVE_ENABLED;
      const base = {
      DATABASE_URL: 'postgres://postgres:postgres@localhost:5436/owanbe',
      SUPABASE_JWT_SECRET: 'supabase-jwt-secret-test',
      EMAIL_SECRETS_ENCRYPTION_KEY: 'quasar-ledger-proof-encryption-key',
    };
    try {
      process.env.QUASAR_ENVIRONMENT = 'live';
      process.env.QUASAR_LIVE_ENABLED = 'false';
      expect(() => configuration()).toThrow(/live is disabled/);
      expect(envValidationSchema.validate({ ...base, QUASAR_ENVIRONMENT: 'live' }).error).toBeTruthy();
      expect(envValidationSchema.validate({ ...base, QUASAR_LIVE_ENABLED: true }).error).toBeTruthy();
      const accepted = envValidationSchema.validate(base);
      expect(accepted.error?.message ?? '').toBe('');
      expect(accepted.value.QUASAR_ENVIRONMENT).toBe('test');
      expect(accepted.value.PAYMENT_MOCK_MODE).toBe(false);
    } finally {
      if (previousEnvironment === undefined) delete process.env.QUASAR_ENVIRONMENT;
      else process.env.QUASAR_ENVIRONMENT = previousEnvironment;
      if (previousLive === undefined) delete process.env.QUASAR_LIVE_ENABLED;
      else process.env.QUASAR_LIVE_ENABLED = previousLive;
    }
  });

  it('rejects live keys', () => {
    expect(() => assertTenantApiKey('sk_live_secret')).toThrow(/sk_test_/);
    expect(() => assertTenantApiKey('sk_test_sandbox')).not.toThrow();
  });

  it('redacts service, client, and tenant secrets', () => {
    const redacted = redactQuasarSecrets({
      secretKey: 'sk_test_abc',
      clientSecret: 'qpc_secret_value',
      nested: { service: 'qps_sec_value', note: 'safe' },
      webhookSigningSecret: 'sandbox-signing-secret',
      accountNumber: '0123456789',
    });
    expect(redacted).toEqual({
      nested: { service: '[redacted]', note: 'safe' },
      accountNumber: '0123456789',
    });
    expect(JSON.stringify(redacted)).not.toContain('webhookSigningSecret');
    expect(JSON.stringify(redacted)).not.toContain('secretKey');
    expect(isQuasarSecret('qps_123')).toBe(true);
    expect(isQuasarSecret('qpc_123')).toBe(true);
    expect(JSON.stringify(redacted)).not.toContain('sk_test_abc');
    expect(JSON.stringify(redacted)).not.toContain('qpc_secret_value');
  });

  it('does not call admin login', () => {
    expect(() => assertQuasarPathAllowed('/admin/auth/login')).toThrow(/admin login/);
    expect(() => assertQuasarPathAllowed('/transfers')).not.toThrow();
  });

  it('normalizes the local sandbox base URL', () => {
    expect(normalizeQuasarBaseUrl('http://localhost:4000')).toBe('http://localhost:4000/api/v1');
    expect(normalizeQuasarBaseUrl('http://localhost:4000/api/v1/')).toBe('http://localhost:4000/api/v1');
  });

  it('converts minor units without treating the fee as a deduction from the bank amount', () => {
    expect(majorAmountFromMinor('5000000')).toBe('50000.00');
    expect(minorUnitsFromQuasarAmount({ amount: '50000.00' })).toBe('5000000');
    expect(minorUnitsFromQuasarAmount({ amount: '50000.0000' })).toBe('5000000');
  });

  it('marks a ticket paid only for virtual_account.funded and a payout paid only for transfer.success', () => {
    expect(actionForQuasarEvent('virtual_account.funded')).toBe('capture_ticket');
    expect(actionForQuasarEvent('transfer.success')).toBe('complete_payout');
    expect(actionForQuasarEvent('transfer.failed')).toBe('fail_payout');
    expect(actionForQuasarEvent('transfer.created')).toBe('ignore');
    expect(actionForQuasarEvent('')).toBe('ignore');
  });

  it('unwraps responseCode 00 payloads and keeps the one-time secret readable for the vault', () => {
    const data = unwrapQuasarData({
      responseCode: '00',
      data: { data: { data: { id: '6f1b5c3a-1c2d-4e5f-8a9b-0c1d2e3f4a5b', slug: 'owanbe-organizer' } } },
    });
    expect(data.id).toBe('6f1b5c3a-1c2d-4e5f-8a9b-0c1d2e3f4a5b');
    const key = unwrapQuasarData({ responseCode: '00', data: { secretKey: 'sk_test_once' } });
    expect(key.secretKey).toBe('sk_test_once');
    expect(() => unwrapQuasarData({ responseCode: '01', message: 'nope' })).toThrow(/nope/);
  });

  it('verifies x-quasar-signature as hex HMAC-SHA256 of the raw body', () => {
    const secret = 'signing-secret';
    const body = Buffer.from(JSON.stringify({ event: 'virtual_account.funded', data: {}, timestamp: 't' }));
    const signature = createHmac('sha256', secret).update(body).digest('hex');
    expect(verifyQuaserWebhookSignature(secret, body, signature)).toBe(true);
    expect(verifyQuaserWebhookSignature(secret, body, 'deadbeef')).toBe(false);
  });

  it('shows only a hint of a test key', () => {
    expect(apiKeyHint('sk_test_abcdefghij')).toBe('sk_test_…ghij');
    expect(apiKeyHint('sk_test_abcdefghij')).not.toBe('sk_test_abcdefghij');
  });
});
