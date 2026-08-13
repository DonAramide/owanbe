import { Injectable, Inject } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { EnvVars } from '../../config/env.schema';
import { IntegrationsModeService } from '../integrations-mode.service';

@Injectable()
export class HealthDetailService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly integrations: IntegrationsModeService,
  ) {}

  async getDetailedHealth() {
    const checks: Record<string, { status: string; detail?: string; counts?: Record<string, number> }> = {};

    try {
      await this.pool.query('SELECT 1');
      checks.database = { status: 'ok' };
    } catch (e) {
      checks.database = { status: 'error', detail: e instanceof Error ? e.message : 'db_unreachable' };
    }

    const quaserUrl = this.config.get('QUASER_ROUTER_BASE_URL', { infer: true }).trim();
    const quaserSecret = this.config.get('QUASER_WEBHOOK_SECRET', { infer: true }).trim();
    checks.payments = {
      status: quaserUrl ? 'configured' : this.integrations.allowPaymentStubs() ? 'stub' : 'missing',
      detail: quaserUrl || 'QUASER_ROUTER_BASE_URL unset',
    };
    checks.quaserWebhookSecret = {
      status: quaserSecret
        ? 'configured'
        : this.integrations.isProduction()
          ? 'error'
          : 'missing',
      detail: quaserSecret ? 'set' : 'QUASER_WEBHOOK_SECRET empty',
    };

    let emailInfra = false;
    try {
      const { rows } = await this.pool.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM email_providers WHERE enabled = true`,
      );
      emailInfra = Number(rows[0]?.n ?? 0) > 0;
    } catch {
      emailInfra = false;
    }
    const webhook = this.config.get('NOTIFICATION_WEBHOOK_URL', { infer: true }).trim();
    checks.notifications = {
      status: emailInfra ? 'enterprise_email' : webhook ? 'webhook' : 'log_only',
      detail: emailInfra
        ? 'Enterprise Email Infrastructure provider(s) enabled'
        : webhook
          ? 'NOTIFICATION_WEBHOOK_URL fallback'
          : 'Configure Super Admin → Enterprise Email Infrastructure',
    };

    const storage =
      this.config.get('SUPABASE_URL', { infer: true }).trim() &&
      this.config.get('SUPABASE_SERVICE_ROLE_KEY', { infer: true }).trim();
    checks.storage = { status: storage ? 'configured' : 'local_fallback' };

    checks.integrationsMode = {
      status: this.integrations.isProduction() ? 'production' : 'development',
    };

    // Phase 25 — automation / webhook / notification job visibility
    checks.automationEngine = await this.countCheck(
      `SELECT status, COUNT(*)::text AS n FROM automation_runs GROUP BY status`,
      'automation_runs',
    );
    checks.automationJobs = await this.countCheck(
      `SELECT status, COUNT(*)::text AS n FROM automation_jobs GROUP BY status`,
      'automation_jobs',
    );
    checks.webhookDelivery = await this.countCheck(
      `SELECT status, COUNT(*)::text AS n FROM platform_webhook_deliveries GROUP BY status`,
      'platform_webhook_deliveries',
    );
    checks.notificationDelivery = await this.countCheck(
      `SELECT status, COUNT(*)::text AS n FROM notification_deliveries GROUP BY status`,
      'notification_deliveries',
    );

    try {
      const { rows } = await this.pool.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM messaging_providers WHERE enabled = true`,
      );
      checks.messagingProviders = {
        status: Number(rows[0]?.n ?? 0) > 0 ? 'configured' : 'none',
        detail: `${rows[0]?.n ?? 0} enabled`,
      };
    } catch {
      checks.messagingProviders = { status: 'unavailable', detail: 'messaging_providers missing' };
    }

    const overall = Object.values(checks).every((c) => c.status !== 'error') ? 'ok' : 'degraded';
    return { status: overall, checks, timestamp: new Date().toISOString() };
  }

  private async countCheck(sql: string, label: string) {
    try {
      const { rows } = await this.pool.query<{ status: string; n: string }>(sql);
      const counts = Object.fromEntries(rows.map((r) => [r.status, parseInt(r.n, 10)]));
      const dead = (counts.dead_letter ?? 0) + (counts.failed ?? 0);
      return {
        status: dead > 100 ? 'degraded' : 'ok',
        detail: label,
        counts,
      };
    } catch (e) {
      return {
        status: 'unavailable',
        detail: e instanceof Error ? e.message : label,
      };
    }
  }
}
