import { Inject, Injectable, Logger } from '@nestjs/common';
import { QuasarModeService } from './quasar-mode.service';
import {
  assertQuasarPathAllowed,
  assertTenantApiKey,
  redactQuasarSecrets,
  unwrapQuasarData,
  type QuasarKeyEnvironment,
} from './quasar.policy';

export interface QuasarHttpConfig {
  baseUrl(): string;
  clientId(): string;
  clientSecret(): string;
  keyEnvironment(): QuasarKeyEnvironment;
  timeoutMs?(): number;
}

export class QuasarHttpError extends Error {
  constructor(
    message: string,
    readonly status: number | undefined,
    readonly retryable: boolean,
  ) {
    super(message);
    this.name = 'QuasarHttpError';
  }
}

type QuasarAuth =
  | { type: 'client' }
  | { type: 'service' }
  | { type: 'tenant'; apiKey: string };

const RETRYABLE_STATUS = new Set([408, 429, 500, 502, 503, 504]);

/**
 * Sandbox Quasar HTTP client. Sends environment "test" only and refuses sk_live_* keys.
 * Retries timeouts and 5xx. Does not retry 400. Never logs credentials.
 */
@Injectable()
export class QuasarHttpClient {
  private readonly logger = new Logger(QuasarHttpClient.name);

  fetchImpl: typeof fetch = fetch;
  sleep: (ms: number) => Promise<void> = delay;

  constructor(@Inject(QuasarModeService) private readonly config: QuasarHttpConfig) {}

  async createTenant(input: { name: string; slug: string; idempotencyKey: string }) {
    return this.request({
      method: 'POST',
      path: '/integration/platform/tenants',
      auth: { type: 'client' },
      idempotencyKey: input.idempotencyKey,
      body: { name: input.name, slug: input.slug, vertical: 'owanbe' },
    });
  }

  async createTenantApiKey(input: { quasarTenantId: string; name: string; idempotencyKey: string }) {
    const environment = this.config.keyEnvironment();
    const data = await this.request({
      method: 'POST',
      path: `/integration/platform/tenants/${input.quasarTenantId}/api-keys`,
      auth: { type: 'client' },
      idempotencyKey: input.idempotencyKey,
      body: { name: input.name, environment: 'test' },
    });
    return { data, environment };
  }

  async registerWebhook(input: { apiKey: string; url: string; idempotencyKey: string }) {
    this.assertMoneyKey(input.apiKey);
    return this.request({
      method: 'POST',
      path: '/webhooks/endpoints',
      auth: { type: 'tenant', apiKey: input.apiKey },
      idempotencyKey: input.idempotencyKey,
      body: { url: input.url },
    });
  }

  async createVirtualAccount(input: {
    apiKey: string;
    payerId: string;
    idempotencyKey: string;
    body: Record<string, unknown>;
  }) {
    this.assertMoneyKey(input.apiKey);
    return this.request({
      method: 'POST',
      path: `/school/students/${input.payerId}/virtual-account`,
      auth: { type: 'tenant', apiKey: input.apiKey },
      idempotencyKey: input.idempotencyKey,
      body: input.body,
    });
  }

  async listPayerPayments(apiKey: string, payerId: string) {
    this.assertMoneyKey(apiKey);
    return this.request({
      method: 'GET',
      path: `/school/students/${encodeURIComponent(payerId)}/payments`,
      auth: { type: 'tenant', apiKey },
    });
  }

  async createTransfer(input: { apiKey: string; idempotencyKey: string; body: Record<string, unknown> }) {
    this.assertMoneyKey(input.apiKey);
    return this.request({
      method: 'POST',
      path: '/transfers',
      auth: { type: 'tenant', apiKey: input.apiKey },
      idempotencyKey: input.idempotencyKey,
      body: input.body,
    });
  }

  async getTransfer(apiKey: string, reference: string) {
    this.assertMoneyKey(apiKey);
    return this.request({
      method: 'GET',
      path: `/transfers/${encodeURIComponent(reference)}`,
      auth: { type: 'tenant', apiKey },
    });
  }

  private assertMoneyKey(apiKey: string) {
    assertTenantApiKey(apiKey);
  }

  private async request(input: {
    method: 'GET' | 'POST';
    path: string;
    auth: QuasarAuth;
    body?: unknown;
    idempotencyKey?: string;
  }): Promise<Record<string, unknown>> {
    let lastError: unknown;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        return await this.once(input);
      } catch (error) {
        lastError = error;
        const retryable = !(error instanceof QuasarHttpError) || error.retryable;
        if (!retryable || attempt === 3) throw error;
        this.logger.warn({ path: input.path, attempt, status: error instanceof QuasarHttpError ? error.status : undefined }, 'Retrying Quasar request');
        await this.sleep(200 * attempt);
      }
    }
    throw lastError;
  }

  private async once(input: {
    method: 'GET' | 'POST';
    path: string;
    auth: QuasarAuth;
    body?: unknown;
    idempotencyKey?: string;
  }): Promise<Record<string, unknown>> {
    assertQuasarPathAllowed(input.path);
    this.assertAuthMatchesPath(input.path, input.auth);
    const headers: Record<string, string> = { Accept: 'application/json' };
    if (input.body !== undefined) headers['Content-Type'] = 'application/json';
    if (input.idempotencyKey) headers['Idempotency-Key'] = input.idempotencyKey;
    this.applyAuth(headers, input.auth);

    const url = `${this.config.baseUrl()}${input.path}`;
    let res: Response;
    try {
      res = await this.fetchImpl(url, {
        method: input.method,
        headers,
        body: input.body !== undefined ? JSON.stringify(input.body) : undefined,
        signal: AbortSignal.timeout(this.config.timeoutMs?.() ?? 20_000),
      });
    } catch (error) {
      const name = (error as Error).name;
      const message = (error as Error).message ?? '';
      const timedOut = name === 'TimeoutError' || name === 'AbortError' || /abort/i.test(message);
      this.logger.warn({ path: input.path }, 'Quasar request failed before a response');
      throw new QuasarHttpError(timedOut ? 'Quasar request timed out' : 'Quasar request failed', undefined, true);
    }

    const raw = (await res.json().catch(() => ({}))) as unknown;
    if (!res.ok) {
      const safe = redactQuasarSecrets(raw);
      const record = safe && typeof safe === 'object' ? (safe as Record<string, unknown>) : {};
      const message =
        typeof record.responseMessage === 'string'
          ? record.responseMessage
          : typeof record.message === 'string'
            ? record.message
            : `HTTP ${res.status}`;
      this.logger.warn({ path: input.path, status: res.status }, 'Quasar request rejected');
      throw new QuasarHttpError(`Quasar ${input.path} failed: ${message}`, res.status, RETRYABLE_STATUS.has(res.status));
    }
    return unwrapQuasarData(raw);
  }

  private assertAuthMatchesPath(path: string, auth: QuasarAuth) {
    if (path.startsWith('/integration/service/')) {
      if (auth.type !== 'service') throw new QuasarHttpError('Service credentials are required for Quasar service routes', 401, false);
      return;
    }
    if (path.startsWith('/integration/platform/')) {
      if (auth.type !== 'client') throw new QuasarHttpError('Client credentials are required to create Quasar tenants', 401, false);
      return;
    }
    if (auth.type !== 'tenant') throw new QuasarHttpError('Tenant API keys are required for Quasar money routes', 401, false);
  }

  private applyAuth(headers: Record<string, string>, auth: QuasarAuth) {
    if (auth.type === 'client') {
      headers['X-Quasar-Client-Id'] = this.config.clientId();
      headers['X-Quasar-Client-Secret'] = this.config.clientSecret();
      return;
    }
    if (auth.type === 'service') {
      throw new QuasarHttpError('Service credentials are not used on money routes', 403, false);
    }
    headers.Authorization = `Bearer ${auth.apiKey}`;
  }
}

export { QuasarHttpClient as QuasarClientService };

function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}
