import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { ConfigService } from '@nestjs/config';
import { PG_POOL } from '../../database/database.tokens';
import type { EnvVars } from '../../config/env.schema';
import { EmailService } from '../email-infrastructure/email.service';
import { IntegrationsModeService } from '../integrations-mode.service';

export type RegistryItem = {
  key: string;
  label: string;
  category: string;
  status: string;
  enabled: boolean;
  providerType: string | null;
  healthDetail: string | null;
  circuitBreaker: string;
  metrics: Record<string, unknown>;
  live: boolean;
  secretsConfigured: boolean;
};

/**
 * Phase 24 — Integration registry + live health (source of truth for Hub).
 */
@Injectable()
export class IntegrationRegistryService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly email: EmailService,
    private readonly mode: IntegrationsModeService,
  ) {}

  async listRegistry(): Promise<{ items: RegistryItem[]; mode: string }> {
    const { rows } = await this.pool.query<{
      integration_key: string;
      label: string;
      category: string;
      status: string;
      enabled: boolean;
      provider_type: string | null;
      health_detail: string | null;
      circuit_breaker: string;
      metrics: Record<string, unknown>;
      secrets_ciphertext: string | null;
    }>(
      `SELECT integration_key, label, category, status, COALESCE(enabled, true) AS enabled,
              provider_type, health_detail, circuit_breaker, metrics, secrets_ciphertext
       FROM platform_registry
       ORDER BY category, label`,
    );

    const emailConfigured = await this.email.hasConfiguredProvider();
    const smsConfigured = await this.hasMessagingCredentials('sms');
    const waConfigured = await this.hasMessagingCredentials('whatsapp');
      const quaserConfigured = this.mode.isQuaserConfigured();
    const storageConfigured = !!(this.config.get('SUPABASE_URL', { infer: true }) ?? '').trim();

    const items: RegistryItem[] = rows.map((r) => {
      let status = r.status;
      let healthDetail = r.health_detail;
      let live = r.enabled && r.status !== 'offline';

      if (r.integration_key === 'enterprise_email') {
        live = emailConfigured;
        status = emailConfigured ? 'active' : 'degraded';
        healthDetail = emailConfigured ? 'Email providers enabled' : 'No default email provider';
      } else if (r.integration_key === 'twilio_sms') {
        live = smsConfigured || !!(this.config.get('TWILIO_ACCOUNT_SID', { infer: true }) ?? '').trim();
        status = live ? 'active' : 'degraded';
        healthDetail = live ? 'SMS credentials available' : 'Configure messaging provider or TWILIO_* env';
      } else if (r.integration_key === 'whatsapp_business') {
        live = waConfigured;
        status = live ? 'active' : 'degraded';
        healthDetail = live ? 'WhatsApp credentials configured' : 'Foundation — credentials not set';
      } else if (r.integration_key === 'quaser') {
        live = quaserConfigured || this.mode.allowPaymentStubs();
        status = quaserConfigured ? 'active' : this.mode.allowPaymentStubs() ? 'degraded' : 'offline';
        healthDetail = quaserConfigured ? 'Quaser router configured' : 'QUASER_ROUTER_URL missing';
      } else if (r.integration_key === 'supabase_storage') {
        live = storageConfigured;
        status = storageConfigured ? 'active' : 'degraded';
        healthDetail = storageConfigured ? 'Storage configured' : 'Local fallback';
      } else if (r.integration_key === 'outbound_webhooks') {
        live = true;
        status = 'active';
      } else if (['stripe', 'paystack', 'salesforce'].includes(r.integration_key)) {
        live = false;
        status = 'offline';
        healthDetail = 'Unavailable — deferred (Phase 24)';
      }

      return {
        key: r.integration_key,
        label: r.label,
        category: r.category,
        status,
        enabled: r.enabled,
        providerType: r.provider_type,
        healthDetail,
        circuitBreaker: r.circuit_breaker,
        metrics: r.metrics ?? {},
        live,
        secretsConfigured: !!r.secrets_ciphertext || (r.integration_key === 'twilio_sms' && smsConfigured),
      };
    });

    return {
      items,
      mode: this.mode.isProduction() ? 'production' : 'development',
    };
  }

  async listRecentDeliveries(limit = 50) {
    const n = Math.min(100, Math.max(1, limit));
    const { rows: webhookRows } = await this.pool.query(
      `SELECT d.id, d.webhook_id, d.topic, d.status, d.attempts, d.last_status_code, d.last_error,
              d.created_at, d.completed_at, w.target_url, w.label
       FROM platform_webhook_deliveries d
       INNER JOIN platform_webhooks w ON w.id = d.webhook_id
       ORDER BY d.created_at DESC
       LIMIT $1`,
      [n],
    );
    const { rows: notifyRows } = await this.pool.query(
      `SELECT id::text, channel, template, recipient, status, provider, error_message, sent_at, created_at
       FROM notification_deliveries
       ORDER BY created_at DESC
       LIMIT $1`,
      [n],
    );
    return {
      webhooks: webhookRows.map((r) => ({
        id: r.id,
        webhookId: r.webhook_id,
        topic: r.topic,
        status: r.status,
        attempts: r.attempts,
        lastStatusCode: r.last_status_code,
        lastError: r.last_error,
        targetUrl: r.target_url,
        label: r.label,
        createdAt: r.created_at,
        completedAt: r.completed_at,
      })),
      notifications: notifyRows.map((r) => ({
        id: r.id,
        channel: r.channel,
        template: r.template,
        recipient: r.recipient,
        status: r.status,
        provider: r.provider,
        errorMessage: r.error_message,
        sentAt: r.sent_at,
        createdAt: r.created_at,
      })),
    };
  }

  private async hasMessagingCredentials(channel: 'sms' | 'whatsapp'): Promise<boolean> {
    const { rows } = await this.pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM messaging_providers
       WHERE channel = $1 AND enabled = true AND secrets_ciphertext IS NOT NULL`,
      [channel],
    );
    return parseInt(rows[0]?.n ?? '0', 10) > 0;
  }
}
