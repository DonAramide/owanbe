import {
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { EmailSecretsCrypto } from './email-secrets.crypto';
import { deliverViaProvider, verifyProviderConnection } from './email.transport';
import { API_KEY_PROVIDERS, SMTP_STYLE_PROVIDERS } from './email.types';
import type {
  EmailProviderPublicView,
  EmailProviderRow,
  SendEmailCommand,
  SendEmailResult,
} from './email.types';

export interface EmailReadinessReport {
  ready: boolean;
  encryptionKeyConfigured: boolean;
  providerCount: number;
  enabledProviderCount: number;
  hasDefaultProvider: boolean;
  defaultProviderId: string | null;
  defaultProviderName: string | null;
  secretsDecryptOk: boolean | null;
  providerValid: boolean | null;
  blockers: string[];
}

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly crypto: EmailSecretsCrypto,
  ) {}

  /**
   * Single entry point for all Owanbe business emails.
   * Resolves the active default provider dynamically — callers never choose Zoho/SES/etc.
   */
  async send(command: SendEmailCommand): Promise<SendEmailResult> {
    const readiness = await this.getReadiness(command.tenantId);
    if (!readiness.ready) {
      const reason = readiness.blockers.join('; ') || 'email_infrastructure_not_ready';
      this.logger.warn({ reason, to: command.to }, 'Email send blocked — infrastructure not ready');
      return { ok: false, reason };
    }

    const provider = await this.resolveActiveProvider(command.tenantId);
    if (!provider) {
      return { ok: false, reason: 'No enabled email provider configured' };
    }

    let creds: { password?: string; apiKey?: string };
    try {
      creds = this.resolveCreds(provider);
    } catch (e) {
      const reason = e instanceof Error ? e.message : 'secret_decrypt_failed';
      await this.markHealth(provider.id, false, reason);
      return { ok: false, reason, providerId: provider.id, providerName: provider.name };
    }

    let last: SendEmailResult = { ok: false, reason: 'not_attempted' };
    const attempts = Math.max(1, provider.retry_attempts + 1);

    for (let i = 0; i < attempts; i++) {
      last = await deliverViaProvider(provider, creds, command);
      if (last.ok) {
        await this.markHealth(provider.id, true);
        return last;
      }
      if (i < attempts - 1 && provider.retry_delay_ms > 0) {
        await sleep(provider.retry_delay_ms);
      }
    }

    await this.markHealth(provider.id, false, last.reason);
    return last;
  }

  async testConnection(providerId: string): Promise<{ ok: boolean; reason?: string }> {
    const provider = await this.requireProviderForOps(providerId);
    let creds: { password?: string; apiKey?: string };
    try {
      creds = this.resolveCreds(provider);
    } catch (e) {
      const reason = e instanceof Error ? e.message : 'secret_decrypt_failed';
      await this.markHealth(provider.id, false, reason);
      return { ok: false, reason };
    }
    const result = await verifyProviderConnection(provider, creds);
    await this.markHealth(provider.id, result.ok, result.reason);
    return result;
  }

  async sendTestEmail(providerId: string, to: string): Promise<SendEmailResult> {
    const provider = await this.requireProviderForOps(providerId);
    let creds: { password?: string; apiKey?: string };
    try {
      creds = this.resolveCreds(provider);
    } catch (e) {
      const reason = e instanceof Error ? e.message : 'secret_decrypt_failed';
      await this.markHealth(provider.id, false, reason);
      return { ok: false, reason, providerId: provider.id, providerName: provider.name };
    }
    const result = await deliverViaProvider(provider, creds, {
      to,
      subject: 'Owanbe Enterprise Email — Test',
      html: `<p>This is a test message from <strong>Owanbe Enterprise Email Infrastructure</strong>.</p>
             <p>Provider: ${provider.name} (${provider.provider_type})</p>
             <p>If you received this, SMTP/API delivery is working.</p>`,
      template: 'enterprise_email_test',
    });
    await this.markHealth(provider.id, result.ok, result.reason);
    return result;
  }

  async getReadiness(tenantId?: string): Promise<EmailReadinessReport> {
    const blockers: string[] = [];
    let encryptionKeyConfigured = false;
    try {
      this.crypto.assertKeyPresent();
      encryptionKeyConfigured = true;
    } catch {
      encryptionKeyConfigured = false;
      blockers.push('EMAIL_SECRETS_ENCRYPTION_KEY is missing or invalid');
    }

    const { rows: counts } = await this.pool.query<{ total: string; enabled: string; defaults: string }>(
      `SELECT
         COUNT(*)::text AS total,
         COUNT(*) FILTER (WHERE enabled)::text AS enabled,
         COUNT(*) FILTER (WHERE enabled AND is_default AND tenant_id IS NULL)::text AS defaults
       FROM email_providers
       WHERE tenant_id IS NULL`,
    );
    const providerCount = Number(counts[0]?.total ?? 0);
    const enabledProviderCount = Number(counts[0]?.enabled ?? 0);
    const hasDefaultProvider = Number(counts[0]?.defaults ?? 0) > 0;

    if (providerCount === 0) {
      blockers.push('No SMTP provider configured');
    } else if (enabledProviderCount === 0) {
      blockers.push('No enabled email provider');
    } else if (!hasDefaultProvider) {
      blockers.push('No default email provider selected');
    }

    const active = await this.resolveActiveProvider(tenantId);
    let secretsDecryptOk: boolean | null = null;
    let providerValid: boolean | null = null;

    if (active) {
      try {
        this.resolveCreds(active);
        secretsDecryptOk = true;
      } catch (e) {
        secretsDecryptOk = false;
        blockers.push(
          e instanceof Error
            ? `Provider secret decrypt failed: ${e.message}`
            : 'Provider secret decrypt failed',
        );
      }
      const validation = this.validateProviderShape(active);
      providerValid = validation.ok;
      if (!validation.ok && validation.reason) {
        blockers.push(validation.reason);
      }
    } else if (enabledProviderCount > 0) {
      providerValid = false;
      blockers.push('Enabled provider could not be resolved');
    }

    return {
      ready: blockers.length === 0,
      encryptionKeyConfigured,
      providerCount,
      enabledProviderCount,
      hasDefaultProvider,
      defaultProviderId: active?.is_default ? active.id : active?.id ?? null,
      defaultProviderName: active?.name ?? null,
      secretsDecryptOk,
      providerValid,
      blockers,
    };
  }

  toPublicView(row: EmailProviderRow): EmailProviderPublicView {
    return {
      id: row.id,
      tenantId: row.tenant_id,
      name: row.name,
      providerType: row.provider_type,
      smtpHost: row.smtp_host,
      smtpPort: row.smtp_port,
      encryptionMode: row.encryption_mode,
      username: row.username,
      hasPassword: Boolean(row.password_ciphertext),
      hasApiKey: Boolean(row.api_key_ciphertext),
      senderName: row.sender_name,
      senderEmail: row.sender_email,
      replyTo: row.reply_to,
      connectionTimeoutMs: row.connection_timeout_ms,
      retryAttempts: row.retry_attempts,
      retryDelayMs: row.retry_delay_ms,
      dailySendingLimit: row.daily_sending_limit,
      enabled: row.enabled,
      isDefault: row.is_default,
      priority: row.priority,
      healthStatus: row.health_status,
      lastSuccessAt: row.last_success_at?.toISOString() ?? null,
      lastFailureAt: row.last_failure_at?.toISOString() ?? null,
      lastErrorMessage: row.last_error_message,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
    };
  }

  async resolveActiveProvider(tenantId?: string): Promise<EmailProviderRow | null> {
    if (tenantId) {
      const tenantDefault = await this.pool.query<EmailProviderRow>(
        `SELECT * FROM email_providers
         WHERE enabled = true AND tenant_id = $1
         ORDER BY is_default DESC, priority ASC, updated_at DESC
         LIMIT 1`,
        [tenantId],
      );
      if (tenantDefault.rows[0]) return tenantDefault.rows[0];
    }

    const platform = await this.pool.query<EmailProviderRow>(
      `SELECT * FROM email_providers
       WHERE enabled = true AND tenant_id IS NULL
       ORDER BY is_default DESC, priority ASC, updated_at DESC
       LIMIT 1`,
    );
    return platform.rows[0] ?? null;
  }

  async getRow(id: string): Promise<EmailProviderRow | null> {
    const { rows } = await this.pool.query<EmailProviderRow>(
      `SELECT * FROM email_providers WHERE id = $1`,
      [id],
    );
    return rows[0] ?? null;
  }

  async hasConfiguredProvider(): Promise<boolean> {
    const { rows } = await this.pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM email_providers WHERE enabled = true`,
    );
    return Number(rows[0]?.n ?? 0) > 0;
  }

  private async requireProviderForOps(providerId: string): Promise<EmailProviderRow> {
    this.crypto.assertKeyPresent();
    const provider = await this.getRow(providerId);
    if (!provider) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'Provider not found' });
    }
    if (!provider.enabled) {
      throw new UnprocessableEntityException({
        code: 'PROVIDER_DISABLED',
        message: 'Provider is disabled. Enable it before testing or sending.',
      });
    }
    const shape = this.validateProviderShape(provider);
    if (!shape.ok) {
      throw new UnprocessableEntityException({
        code: 'PROVIDER_INVALID',
        message: shape.reason ?? 'Provider failed validation',
      });
    }
    return provider;
  }

  private validateProviderShape(provider: EmailProviderRow): { ok: boolean; reason?: string } {
    if (!provider.sender_email?.trim()) {
      return { ok: false, reason: 'Provider missing sender_email' };
    }
    if (SMTP_STYLE_PROVIDERS.includes(provider.provider_type) || provider.provider_type === 'custom_smtp') {
      if (!provider.smtp_host?.trim()) {
        return { ok: false, reason: 'SMTP provider missing smtp_host' };
      }
      if (!provider.username?.trim()) {
        return { ok: false, reason: 'SMTP provider missing username' };
      }
      if (!provider.password_ciphertext) {
        return { ok: false, reason: 'SMTP provider missing encrypted password' };
      }
      return { ok: true };
    }
    if (API_KEY_PROVIDERS.includes(provider.provider_type)) {
      if (!provider.api_key_ciphertext) {
        return { ok: false, reason: 'API provider missing encrypted api key' };
      }
      return { ok: true };
    }
    return { ok: false, reason: `Unsupported provider type: ${provider.provider_type}` };
  }

  private resolveCreds(provider: EmailProviderRow) {
    return {
      password: provider.password_ciphertext
        ? this.crypto.decrypt(provider.password_ciphertext)
        : undefined,
      apiKey: provider.api_key_ciphertext
        ? this.crypto.decrypt(provider.api_key_ciphertext)
        : undefined,
    };
  }

  private async markHealth(providerId: string, ok: boolean, reason?: string): Promise<void> {
    if (ok) {
      await this.pool.query(
        `UPDATE email_providers
         SET health_status = 'healthy', last_success_at = now(), last_error_message = NULL, updated_at = now()
         WHERE id = $1`,
        [providerId],
      );
    } else {
      await this.pool.query(
        `UPDATE email_providers
         SET health_status = 'unhealthy', last_failure_at = now(), last_error_message = $2, updated_at = now()
         WHERE id = $1`,
        [providerId, reason ?? 'unknown'],
      );
    }
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
