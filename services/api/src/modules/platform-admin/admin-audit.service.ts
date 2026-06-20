import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

@Injectable()
export class AdminAuditService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async timeline(tenantId: string, category?: string, limit = 100) {
    const params: unknown[] = [tenantId, Math.min(limit, 200)];
    let categoryFilter = '';
    if (category && category !== 'all') {
      params.push(category);
      categoryFilter = ` AND (${this.categorySqlClause(`$${params.length}`)})`;
    }
    const { rows } = await this.pool.query<{
      id: string;
      action: string;
      resource_type: string;
      resource_id: string;
      actor_user_id: string | null;
      actor_email: string | null;
      metadata: Record<string, unknown>;
      created_at: Date;
    }>(
      `SELECT al.id::text, al.action, al.resource_type, al.resource_id,
              al.actor_user_id::text, u.email AS actor_email, al.metadata, al.created_at
       FROM audit_log al
       LEFT JOIN users u ON u.id = al.actor_user_id
       WHERE al.tenant_id = $1${categoryFilter}
       ORDER BY al.created_at DESC
       LIMIT $2`,
      params,
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        action: r.action,
        resourceType: r.resource_type,
        resourceId: r.resource_id,
        actorUserId: r.actor_user_id,
        actorEmail: r.actor_email,
        category: this.categorize(r.action),
        metadata: r.metadata,
        timestamp: r.created_at.toISOString(),
      })),
    };
  }

  private categorize(action: string): string {
    if (
      action.startsWith('admin_') ||
      action.includes('suspend') ||
      action.includes('approve') ||
      action.includes('reactivate') ||
      action.includes('force_close')
    ) {
      return 'admin';
    }
    if (action.includes('organizer') || action.includes('event')) return 'organizer';
    if (action.includes('vendor')) return 'vendor';
    if (
      action.includes('payout') ||
      action.includes('refund') ||
      action.includes('finance') ||
      action.includes('reconciliation') ||
      action.includes('payment')
    ) {
      return 'financial';
    }
    return 'other';
  }

  private categorySqlClause(categoryParam: string): string {
    return `CASE
      WHEN al.action LIKE 'admin_%' OR al.action LIKE '%suspend%' OR al.action LIKE '%approve%'
        OR al.action LIKE '%reactivate%' OR al.action LIKE '%force_close%' THEN 'admin'
      WHEN al.action LIKE '%organizer%' OR al.action LIKE '%event%' THEN 'organizer'
      WHEN al.action LIKE '%vendor%' THEN 'vendor'
      WHEN al.action LIKE '%payout%' OR al.action LIKE '%refund%' OR al.action LIKE '%finance%'
        OR al.action LIKE '%reconciliation%' OR al.action LIKE '%payment%' THEN 'financial'
      ELSE 'other'
    END = ${categoryParam}`;
  }
}
