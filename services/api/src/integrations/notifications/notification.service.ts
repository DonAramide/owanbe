import { Injectable, Inject, Logger } from '@nestjs/common';
import type { Pool } from 'pg';
import { ConfigService } from '@nestjs/config';
import { PG_POOL } from '../../database/database.tokens';
import type { EnvVars } from '../../config/env.schema';
import { MetricsService } from '../observability/metrics.service';

export type NotificationChannel = 'email' | 'sms' | 'push';

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
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly metrics: MetricsService,
  ) {}

  async send(input: SendNotificationInput): Promise<{ ok: boolean; deliveryId?: string; reason?: string }> {
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO notification_deliveries (tenant_id, channel, template, recipient, status, provider, metadata)
       VALUES ($1::uuid, $2, $3, $4, 'pending', $5, $6::jsonb)
       RETURNING id::text`,
      [
        input.tenantId ?? null,
        input.channel,
        input.template,
        input.recipient,
        this.resolveProvider(input.channel),
        JSON.stringify(input.metadata ?? {}),
      ],
    );
    const deliveryId = rows[0]?.id;

    try {
      const result = await this.dispatch(input);
      await this.pool.query(
        `UPDATE notification_deliveries
         SET status = $2, external_id = $3, sent_at = now(), error_message = NULL
         WHERE id = $4`,
        [deliveryId, result.ok ? 'sent' : 'failed', result.externalId ?? null, deliveryId],
      );
      if (result.ok) this.metrics.inc('notifications_sent_total', { channel: input.channel });
      else this.metrics.inc('notifications_failed_total', { channel: input.channel });
      return { ok: result.ok, deliveryId, reason: result.reason };
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'send_failed';
      await this.pool.query(
        `UPDATE notification_deliveries SET status = 'failed', error_message = $2 WHERE id = $1`,
        [deliveryId, msg],
      );
      this.metrics.inc('notifications_failed_total', { channel: input.channel });
      return { ok: false, deliveryId, reason: msg };
    }
  }

  private resolveProvider(channel: NotificationChannel): string {
    if (channel === 'email') {
      if (this.config.get('RESEND_API_KEY', { infer: true }).trim()) return 'resend';
      if (this.config.get('NOTIFICATION_WEBHOOK_URL', { infer: true }).trim()) return 'webhook';
      return 'log';
    }
    if (channel === 'sms') {
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
    return { ok: true, externalId: 'log-push' };
  }

  private async sendEmail(input: SendNotificationInput): Promise<{ ok: boolean; externalId?: string; reason?: string }> {
    const resendKey = this.config.get('RESEND_API_KEY', { infer: true }).trim();
    const from = this.config.get('NOTIFICATION_FROM_EMAIL', { infer: true }).trim() || 'Owanbe <noreply@owanbe.app>';

    if (resendKey) {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from,
          to: [input.recipient],
          subject: input.subject ?? input.template,
          html: input.body,
        }),
      });
      const raw = (await res.json().catch(() => ({}))) as { id?: string; message?: string };
      if (!res.ok) return { ok: false, reason: raw.message ?? `Resend HTTP ${res.status}` };
      return { ok: true, externalId: raw.id };
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

    this.logger.log({ to: input.recipient, template: input.template }, 'Email (log-only — configure RESEND_API_KEY)');
    return { ok: true, externalId: 'log-email' };
  }

  private async sendSms(input: SendNotificationInput): Promise<{ ok: boolean; externalId?: string; reason?: string }> {
    const sid = this.config.get('TWILIO_ACCOUNT_SID', { infer: true }).trim();
    const token = this.config.get('TWILIO_AUTH_TOKEN', { infer: true }).trim();
    const from = this.config.get('TWILIO_FROM_NUMBER', { infer: true }).trim();

    if (sid && token && from) {
      const auth = Buffer.from(`${sid}:${token}`).toString('base64');
      const body = new URLSearchParams({ To: input.recipient, From: from, Body: input.body });
      const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
        method: 'POST',
        headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body.toString(),
      });
      const raw = (await res.json().catch(() => ({}))) as { sid?: string; message?: string };
      if (!res.ok) return { ok: false, reason: raw.message ?? `Twilio HTTP ${res.status}` };
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

    this.logger.log({ to: input.recipient, template: input.template }, 'SMS (log-only — configure Twilio)');
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
