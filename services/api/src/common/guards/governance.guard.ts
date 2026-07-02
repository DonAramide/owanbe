import { Injectable, CanActivate, ExecutionContext, ForbiddenException, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

@Injectable()
export class GovernanceGuard implements CanActivate {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const vendorId = request.headers['x-vendor-id'] || request.query.vendorId;

    if (!vendorId) {
      return true; // No vendor context, bypass
    }

    const { rows } = await this.pool.query(
      `SELECT state::text, risk_score::text FROM negotiation_sessions WHERE vendor_id = $1 LIMIT 1`,
      [vendorId],
    );

    if (rows.length > 0) {
      const state = rows[0].state;
      if (state === 'suspended' || state === 'blocked') {
        throw new ForbiddenException({
          code: 'VENDOR_GOVERNANCE_RESTRICTION',
          message: 'This vendor account is currently restricted or suspended by platform administrators.',
        });
      }
    }

    return true;
  }
}
