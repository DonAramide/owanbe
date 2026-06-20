import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';

const FLAG_KEYS = [
  'ticket_commerce',
  'vendor_commerce',
  'live_operations',
  'finance',
  'reconciliation',
] as const;

@Injectable()
export class SuperAdminFeatureFlagsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
  ) {}

  async listForTenant(tenantId: string) {
    await this.assertTenant(tenantId);
    const { rows } = await this.pool.query<{ flag_key: string; enabled: boolean }>(
      `SELECT flag_key, enabled FROM tenant_feature_flags WHERE tenant_id = $1 ORDER BY flag_key`,
      [tenantId],
    );
    const map = new Map(rows.map((r) => [r.flag_key, r.enabled]));
    return {
      tenantId,
      flags: FLAG_KEYS.map((key) => ({
        key,
        enabled: map.get(key) ?? true,
      })),
    };
  }

  async setFlag(actorUserId: string, tenantId: string, flagKey: string, enabled: boolean) {
    await this.assertTenant(tenantId);
    if (!FLAG_KEYS.includes(flagKey as (typeof FLAG_KEYS)[number])) {
      throw new NotFoundException({ code: 'FLAG_NOT_FOUND', message: 'Unknown feature flag' });
    }
    await this.pool.query(
      `INSERT INTO tenant_feature_flags (tenant_id, flag_key, enabled, updated_by, updated_at)
       VALUES ($1, $2, $3, $4::uuid, now())
       ON CONFLICT (tenant_id, flag_key) DO UPDATE SET enabled = $3, updated_by = $4::uuid, updated_at = now()`,
      [tenantId, flagKey, enabled, actorUserId],
    );
    await this.audit.logAction({
      tenantId,
      actorUserId,
      action: 'feature_flag_updated',
      resourceType: 'tenant_feature_flag',
      resourceId: `${tenantId}:${flagKey}`,
      metadata: { flagKey, enabled },
    });
    return { ok: true, flagKey, enabled };
  }

  private async assertTenant(tenantId: string) {
    const { rows } = await this.pool.query(`SELECT id FROM tenants WHERE id = $1`, [tenantId]);
    if (!rows[0]) throw new NotFoundException({ code: 'TENANT_NOT_FOUND', message: 'Tenant not found' });
  }
}
