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
    const checks: Record<string, { status: string; detail?: string }> = {};

    try {
      await this.pool.query('SELECT 1');
      checks.database = { status: 'ok' };
    } catch (e) {
      checks.database = { status: 'error', detail: e instanceof Error ? e.message : 'db_unreachable' };
    }

    const quaserUrl = this.config.get('QUASER_ROUTER_BASE_URL', { infer: true }).trim();
    checks.payments = {
      status: quaserUrl ? 'configured' : this.integrations.allowPaymentStubs() ? 'stub' : 'missing',
      detail: quaserUrl || 'QUASER_ROUTER_BASE_URL unset',
    };

    const notif =
      this.config.get('RESEND_API_KEY', { infer: true }).trim() ||
      this.config.get('NOTIFICATION_WEBHOOK_URL', { infer: true }).trim();
    checks.notifications = { status: notif ? 'configured' : 'log_only' };

    const storage =
      this.config.get('SUPABASE_URL', { infer: true }).trim() &&
      this.config.get('SUPABASE_SERVICE_ROLE_KEY', { infer: true }).trim();
    checks.storage = { status: storage ? 'configured' : 'local_fallback' };

    checks.integrationsMode = {
      status: this.integrations.isProduction() ? 'production' : 'development',
    };

    const overall = Object.values(checks).every((c) => c.status !== 'error') ? 'ok' : 'degraded';
    return { status: overall, checks, timestamp: new Date().toISOString() };
  }
}
