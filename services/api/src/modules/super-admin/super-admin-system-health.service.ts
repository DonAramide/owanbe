import { Injectable, Inject } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { EnvVars } from '../../config/env.schema';

export type SystemStatus = 'operational' | 'degraded' | 'critical';

@Injectable()
export class SuperAdminSystemHealthService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
  ) {}

  async getHealth() {
    const [db, recon, webhook] = await Promise.all([
      this.checkDatabase(),
      this.checkReconciliation(),
      this.checkWebhooks(),
    ]);
    const api: SystemStatus = 'operational';
    const queue: SystemStatus = 'operational';
    const components = { api, database: db, queue, webhooks: webhook, reconciliation: recon };
    const overall = this.overallStatus(Object.values(components));
    return { overall, components, checkedAt: new Date().toISOString() };
  }

  private async checkDatabase(): Promise<SystemStatus> {
    try {
      await this.pool.query('SELECT 1');
      return 'operational';
    } catch {
      return 'critical';
    }
  }

  private async checkReconciliation(): Promise<SystemStatus> {
    const { rows } = await this.pool.query<{ open_count: string; critical_count: string }>(
      `SELECT
         COUNT(*) FILTER (WHERE resolution_status::text = 'open')::text AS open_count,
         COUNT(*) FILTER (WHERE resolution_status::text = 'open' AND severity::text = 'critical')::text AS critical_count
       FROM reconciliation_reports`,
    );
    const critical = Number(rows[0]?.critical_count ?? 0);
    const open = Number(rows[0]?.open_count ?? 0);
    if (critical > 0) return 'critical';
    if (open > 5) return 'degraded';
    return 'operational';
  }

  private checkWebhooks(): SystemStatus {
    const secret = this.config.get('QUASER_WEBHOOK_SECRET', { infer: true });
    const base = this.config.get('QUASER_ROUTER_BASE_URL', { infer: true });
    if (!secret && !base) return 'degraded';
    return 'operational';
  }

  private overallStatus(statuses: SystemStatus[]): SystemStatus {
    if (statuses.includes('critical')) return 'critical';
    if (statuses.includes('degraded')) return 'degraded';
    return 'operational';
  }
}
