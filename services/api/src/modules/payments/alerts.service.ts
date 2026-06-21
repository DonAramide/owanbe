import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';
import { NotificationService } from '../../integrations/notifications/notification.service';

export type FinancialAlertType =
  | 'payment_mismatch'
  | 'payout_failure'
  | 'webhook_verification_failure'
  | 'chargeback_received'
  | 'reconciliation_mismatch';

export type AlertSeverity = 'INFO' | 'WARNING' | 'CRITICAL';

@Injectable()
export class AlertsService {
  private readonly logger = new Logger(AlertsService.name);
  private readonly dedupe = new Map<string, number>();

  constructor(
    private readonly config: ConfigService<EnvVars, true>,
    private readonly notifications: NotificationService,
  ) {}

  async trigger(
    type: FinancialAlertType,
    payload: Record<string, unknown>,
    severity: AlertSeverity = 'WARNING',
    dedupeKey?: string,
  ): Promise<void> {
    const now = Date.now();
    const dedupeWindow = this.config.get('ALERT_DEDUPE_WINDOW_MS', { infer: true });
    const key = `${type}:${dedupeKey ?? JSON.stringify(payload).slice(0, 240)}`;
    const prev = this.dedupe.get(key);
    if (prev != null && now - prev < dedupeWindow) {
      return;
    }
    this.dedupe.set(key, now);

    const msg = { type, severity, payload };
    if (severity === 'CRITICAL') this.logger.error(msg);
    else if (severity === 'WARNING') this.logger.warn(msg);
    else this.logger.log(msg);

    const url = this.config.get('ALERT_WEBHOOK_URL', { infer: true }).trim();
    if (url) {
      await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(msg),
      }).catch(() => undefined);
    }
    const email = this.config.get('ALERT_EMAIL_TO', { infer: true }).trim();
    if (email) {
      await this.notifications.send({
        channel: 'email',
        template: `alert_${type}`,
        recipient: email,
        subject: `[Owanbe ${severity}] ${type}`,
        body: `<pre>${JSON.stringify(msg, null, 2)}</pre>`,
        metadata: { alertType: type, severity },
      });
    }
  }
}
