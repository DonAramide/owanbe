import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../database/database.tokens';

@Injectable()
export class AuditLogService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async logAction(params: {
    tenantId: string;
    actorUserId: string;
    action: string;
    resourceType: string;
    resourceId: string;
    metadata?: Record<string, unknown>;
  }): Promise<void> {
    await this.pool.query(
      `INSERT INTO audit_log (tenant_id, actor_user_id, action, resource_type, resource_id, metadata)
       VALUES ($1, $2::uuid, $3, $4, $5, $6::jsonb)`,
      [
        params.tenantId,
        params.actorUserId,
        params.action,
        params.resourceType,
        params.resourceId,
        JSON.stringify(params.metadata ?? {}),
      ],
    );
  }

  async logRead(params: {
    tenantId: string;
    actorUserId: string;
    action: string;
    resourceType: string;
    resourceId: string;
    metadata?: Record<string, unknown>;
  }): Promise<void> {
    await this.logAction(params);
  }
}
