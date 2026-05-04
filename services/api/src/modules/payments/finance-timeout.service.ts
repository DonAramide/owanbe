import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';
import { AlertsService } from './alerts.service';
import { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { Inject } from '@nestjs/common';

@Injectable()
export class FinanceTimeoutService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(FinanceTimeoutService.name);
  private timer: NodeJS.Timeout | null = null;

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly alerts: AlertsService,
  ) {}

  onModuleInit() {
    const interval = this.config.get('FINANCE_TIMEOUT_SWEEP_MS', { infer: true });
    this.timer = setInterval(() => {
      this.runSweep().catch((e) => this.logger.error(e));
    }, interval);
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async runSweep() {
    const payMins = this.config.get('PAYMENT_TIMEOUT_MINUTES', { infer: true });
    const payoutMins = this.config.get('PAYOUT_TIMEOUT_MINUTES', { infer: true });

    const pay = await this.pool.query<{ id: string; tenant_id: string }>(
      `UPDATE payments
       SET status = 'failed',
           metadata = metadata || '{"timeout":"payment_stale"}'::jsonb,
           updated_at = now()
       WHERE status::text IN ('initiated','requires_action','authorized')
         AND under_review = FALSE
         AND created_at < now() - make_interval(mins => $1)
       RETURNING id, tenant_id`,
      [payMins],
    );

    const payout = await this.pool.query<{ id: string; tenant_id: string }>(
      `UPDATE payouts
       SET status = 'failed',
           under_review = TRUE,
           failure_code = COALESCE(failure_code, 'TIMEOUT'),
           failure_message = COALESCE(failure_message, 'Payout timed out'),
           updated_at = now()
       WHERE status::text = 'processing'
         AND under_review = FALSE
         AND updated_at < now() - make_interval(mins => $1)
       RETURNING id, tenant_id`,
      [payoutMins],
    );

    if (pay.rowCount) {
      await this.alerts.trigger(
        'payment_mismatch',
        { stalePayments: pay.rowCount },
        'WARNING',
        'timeout:payments',
      );
    }
    if (payout.rowCount) {
      await this.alerts.trigger(
        'payout_failure',
        { stalePayouts: payout.rowCount },
        'CRITICAL',
        'timeout:payouts',
      );
    }
    return { stalePayments: pay.rowCount ?? 0, stalePayouts: payout.rowCount ?? 0 };
  }
}
