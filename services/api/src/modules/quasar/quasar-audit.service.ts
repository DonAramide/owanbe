import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { redactQuasarSecrets } from './quasar.policy';

export function buildAuditDetail(detail: unknown): Record<string, unknown> {
  const redacted = redactQuasarSecrets(detail ?? {});
  if (!redacted || typeof redacted !== 'object' || Array.isArray(redacted)) return {};
  return redacted as Record<string, unknown>;
}

@Injectable()
export class QuasarAuditService {
  private readonly logger = new Logger(QuasarAuditService.name);

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async record(input: {
    owanbeTenantId?: string | null;
    action: string;
    outcome: string;
    reference?: string | null;
    detail?: unknown;
  }): Promise<void> {
    const detail = buildAuditDetail(input.detail);
    try {
      await this.pool.query(
        `INSERT INTO quasar_audit_log (owanbe_tenant_id, action, outcome, reference, detail)
         VALUES ($1, $2, $3, $4, $5::jsonb)`,
        [input.owanbeTenantId ?? null, input.action, input.outcome, input.reference ?? null, JSON.stringify(detail)],
      );
    } catch (error) {
      this.logger.warn({ action: input.action, outcome: input.outcome }, 'Quasar audit insert failed');
      void error;
    }
  }
}
