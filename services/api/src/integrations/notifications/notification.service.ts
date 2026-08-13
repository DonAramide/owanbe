import { Injectable, Inject, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import type { Pool } from 'pg';
import { ConfigService } from '@nestjs/config';
import { PG_POOL } from '../../database/database.tokens';
import type { EnvVars } from '../../config/env.schema';
import { MetricsService } from '../observability/metrics.service';
import { EmailService } from '../email-infrastructure/email.service';
import { MessagingProvidersService } from '../hub/messaging-providers.service';
import { IntegrationsModeService } from '../integrations-mode.service';

export type NotificationChannel = 'email' | 'sms' | 'push';

/** Phase 25 lifecycle statuses (legacy pending/skipped retained). */
export type NotificationDeliveryStatus =
  | 'queued'
  | 'pending'
  | 'sent'
  | 'delivered'
  | 'failed'
  | 'retrying'
  | 'dead_letter'
  | 'skipped';

export interface SendNotificationInput {
  tenantId?: string;
  channel: NotificationChannel;
  template: string;
  recipient: string;
  subject?: string;
  body: string;
  metadata?: Record<string, unknown>;
}

@Injectable()
export class NotificationService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(NotificationService.name);
  private timer: NodeJS.Timeout | null = null;

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly metrics: MetricsService,
    private readonly emailService: EmailService,
    private readonly messaging: MessagingProvidersService,
    private readonly mode: IntegrationsModeService,
  ) {}

  onModuleInit() {
    this.timer = setInterval(() => {
      void this.processRetries(20).catch((err) => {
        this.logger.warn(`Notification retry sweep failed: ${(err as Error).message}`);
      });
    }, 45_000);
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async send(input: SendNotificationInput): Promise<{ ok: boolean; deliveryId?: string; reason?: string }> {
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO notification_deliveries
         (tenant_id, channel, template, recipient, status, provider, metadata, attempts, max_attempts, next_attempt_at)
       VALUES ($1::uuid, $2, $3, $4, 'queued', $5, $6::jsonb, 0, 5, now())
       RETURNING id::text`,
      [
        input.tenantId ?? null,
        input.channel,
        input.template,
        input.recipient,
        await this.resolveProviderLabel(input.channel),
        JSON.stringify({ ...input.metadata, subject: input.subject, body: input.body }),
      ],
    );
    const deliveryId = rows[0]?.id;
    return this.attemptDelivery(deliveryId!, input);
  }

  async processRetries(batch = 20): Promise<{ processed: number }> {
    const { rows } = await this.pool.query<{
      id: string;
      channel: NotificationChannel;
      template: string;
      recipient: string;
      tenant_id: string | null;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id::text, channel, template, recipient, tenant_id::text, metadata
       FROM notification_deliveries
       WHERE status IN ('retrying', 'queued', 'pending')
         AND (next_attempt_at IS NULL OR next_attempt_at <= now())
         AND attempts < max_attempts
       ORDER BY COALESCE(next_attempt_at, created_at) ASC
       LIMIT $1`,
      [batch],
    );

    let processed = 0;
    for (const row of rows) {
      const meta = row.metadata ?? {};
      await this.attemptDelivery(row.id, {
        tenantId: row.tenant_id ?? undefined,
        channel: row.channel,
        template: row.template,
        recipient: row.recipient,
        subject: typeof meta.subject === 'string' ? meta.subject : row.template,
        body: typeof meta.body === 'string' ? meta.body : '',
        metadata: meta,
      });
      processed += 1;
    }
    return { processed };
  }

  async deliveryObservability(limit = 50) {
    const { rows: byStatus } = await this.pool.query<{ status: string; n: string }>(
      `SELECT status, COUNT(*)::text AS n FROM notification_deliveries GROUP BY status`,
    );
    const { rows: recent } = await this.pool.query(
      `SELECT id::text, channel, template, recipient, status, provider, attempts, error_message, last_error, sent_at, created_at
       FROM notification_deliveries
       ORDER BY created_at DESC
       LIMIT $1`,
      [limit],
    );
    return {
      byStatus: Object.fromEntries(byStatus.map((r) => [r.status, parseInt(r.n, 10)])),
      recent,
    };
  }

  private async attemptDelivery(
    deliveryId: string,
    input: SendNotificationInput,
  ): Promise<{ ok: boolean; deliveryId?: string; reason?: string }> {
    await this.pool.query(
      `UPDATE notification_deliveries
       SET status = 'queued', attempts = COALESCE(attempts, 0) + 1
       WHERE id = $1`,
      [deliveryId],
    );

    try {
      const result = await this.dispatch(input);
      if (result.ok) {
        const status: NotificationDeliveryStatus =
          result.externalId?.startsWith('log-') ? 'sent' : 'delivered';
        await this.pool.query(
          `UPDATE notification_deliveries
           SET status = $2, external_id = $3, sent_at = now(), error_message = NULL, last_error = NULL
           WHERE id = $1`,
          [deliveryId, status, result.externalId ?? null],
        );
        this.metrics.inc('notifications_sent_total', { channel: input.channel });
        return { ok: true, deliveryId, reason: result.reason };
      }

      return this.markFailure(deliveryId, input.channel, result.reason ?? 'dispatch_failed');
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'send_failed';
      return this.markFailure(deliveryId, input.channel, msg);
    }
  }

  private async markFailure(
    deliveryId: string,
    channel: NotificationChannel,
    reason: string,
  ): Promise<{ ok: boolean; deliveryId: string; reason: string }> {
    const { rows } = await this.pool.query<{ attempts: number; max_attempts: number }>(
      `SELECT COALESCE(attempts, 1) AS attempts, COALESCE(max_attempts, 5) AS max_attempts
       FROM notification_deliveries WHERE id = $1`,
      [deliveryId],
    );
    const attempts = rows[0]?.attempts ?? 1;
    const maxAttempts = rows[0]?.max_attempts ?? 5;

    if (attempts >= maxAttempts) {
      await this.pool.query(
        `UPDATE notification_deliveries
         SET status = 'dead_letter', error_message = $2, last_error = $2
         WHERE id = $1`,
        [deliveryId, reason],
      );
      this.metrics.inc('notifications_dead_letter_total', { channel });
    } else {
      const backoffSec = Math.min(3600, Math.pow(2, attempts) * 20);
      await this.pool.query(
        `UPDATE notification_deliveries
         SET status = 'retrying', error_message = $2, last_error = $2,
             next_attempt_at = now() + make_interval(secs => $3::int)
         WHERE id = $1`,
        [deliveryId, reason, backoffSec],
      );
      this.metrics.inc('notifications_retrying_total', { channel });
    }
    this.metrics.inc('notifications_failed_total', { channel });
    return { ok: false, deliveryId, reason };
  }

  private async resolveProviderLabel(channel: NotificationChannel): Promise<string> {
    if (channel === 'email') {
      const active = await this.emailService.resolveActiveProvider();
      if (active) return `enterprise:${active.provider_type}`;
      if (this.config.get('NOTIFICATION_WEBHOOK_URL', { infer: true }).trim()) return 'webhook';
      return 'log';
    }
    if (channel === 'sms') {
      const db = await this.messaging.resolveActive('sms');
      if (db) return `messaging:${db.providerType}`;
      if (this.config.get('TWILIO_ACCOUNT_SID', { infer: true }).trim()) return 'twilio';
      if (this.config.get('NOTIFICATION_WEBHOOK_URL', { infer: true }).trim()) return 'webhook';
      return 'log';
    }
    return 'log';
  }

  private async dispatch(input: SendNotificationInput): Promise<{ ok: boolean; externalId?: string; reason?: string }> {
    if (input.channel === 'email') {
      return this.sendEmail(input);
    }
    if (input.channel === 'sms') {
      return this.sendSms(input);
    }
    this.logger.log({ template: input.template, recipient: input.recipient }, 'Push notification (log-only)');
    if (this.mode.isProduction()) {
      return { ok: false, reason: 'Push provider not configured (production)' };
    }
    return { ok: true, externalId: 'log-push' };
  }

  private async sendEmail(input: SendNotificationInput): Promise<{ ok: boolean; externalId?: string; reason?: string }> {
    if (await this.emailService.hasConfiguredProvider()) {
      const result = await this.emailService.send({
        to: input.recipient,
        subject: input.subject ?? input.template,
        html: input.body,
        template: input.template,
        tenantId: input.tenantId,
        metadata: input.metadata,
      });
      return { ok: result.ok, externalId: result.externalId, reason: result.reason };
    }

    const webhook = this.config.get('NOTIFICATION_WEBHOOK_URL', { infer: true }).trim();
    if (webhook) {
      const res = await fetch(webhook, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...input, channel: 'email' }),
      });
      if (!res.ok) return { ok: false, reason: `Webhook HTTP ${res.status}` };
      return { ok: true, externalId: 'webhook-email' };
    }

    return {
      ok: false,
      reason:
        'No SMTP provider configured. Configure Super Admin → Enterprise Email (default enabled provider) before sending mail.',
    };
  }

  private async sendSms(input: SendNotificationInput): Promise<{ ok: boolean; externalId?: string; reason?: string }> {
    const db = await this.messaging.resolveActive('sms', input.tenantId);
    const sid =
      (db?.secrets.accountSid ?? '').trim() ||
      this.config.get('TWILIO_ACCOUNT_SID', { infer: true }).trim();
    const token =
      (db?.secrets.authToken ?? '').trim() ||
      this.config.get('TWILIO_AUTH_TOKEN', { infer: true }).trim();
    const from =
      (db?.fromAddress ?? '').trim() ||
      this.config.get('TWILIO_FROM_NUMBER', { infer: true }).trim();

    if (sid && token && from) {
      const auth = Buffer.from(`${sid}:${token}`).toString('base64');
      const body = new URLSearchParams({ To: input.recipient, From: from, Body: input.body });
      const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
        method: 'POST',
        headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body.toString(),
      });
      const raw = (await res.json().catch(() => ({}))) as { sid?: string; message?: string };
      if (!res.ok) {
        if (db) {
          await this.pool
            .query(
              `UPDATE messaging_providers SET last_error = $2, updated_at = now() WHERE id = $1::uuid`,
              [db.id, raw.message ?? `Twilio HTTP ${res.status}`],
            )
            .catch(() => undefined);
        }
        return { ok: false, reason: raw.message ?? `Twilio HTTP ${res.status}` };
      }
      return { ok: true, externalId: raw.sid };
    }

    const webhook = this.config.get('NOTIFICATION_WEBHOOK_URL', { infer: true }).trim();
    if (webhook) {
      const res = await fetch(webhook, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...input, channel: 'sms' }),
      });
      if (!res.ok) return { ok: false, reason: `Webhook HTTP ${res.status}` };
      return { ok: true, externalId: 'webhook-sms' };
    }

    this.logger.log({ to: input.recipient, template: input.template }, 'SMS (unconfigured)');
    if (this.mode.isProduction()) {
      return { ok: false, reason: 'SMS provider not configured (production)' };
    }
    // Development-only log path — visible as sent/log, not silent success for prod
    return { ok: true, externalId: 'log-sms' };
  }

  async sendTicketConfirmation(params: {
    tenantId: string;
    email: string;
    eventTitle: string;
    ticketCode: string;
    tierName: string;
  }): Promise<{ ok: boolean }> {
    const result = await this.send({
      tenantId: params.tenantId,
      channel: 'email',
      template: 'ticket_confirmation',
      recipient: params.email,
      subject: `Your ticket for ${params.eventTitle}`,
      body: `<p>Your ticket is confirmed.</p><p><strong>${params.eventTitle}</strong><br/>${params.tierName}<br/>Code: <code>${params.ticketCode}</code></p>`,
      metadata: { ticketCode: params.ticketCode },
    });
    return { ok: result.ok };
  }
}
