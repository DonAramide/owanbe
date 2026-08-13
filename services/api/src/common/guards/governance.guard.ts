import { Injectable, CanActivate, ExecutionContext, ForbiddenException, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

/**
 * Phase 28 — Vendor governance guard.
 * Canonical standing is vendors.status (not negotiation_sessions theater).
 */
@Injectable()
export class GovernanceGuard implements CanActivate {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const vendorId = request.headers['x-vendor-id'] || request.query.vendorId;

    if (!vendorId) {
      return true;
    }

    const { rows } = await this.pool.query<{ status: string; business_name: string }>(
      `SELECT status::text AS status, business_name FROM vendors WHERE id = $1::uuid LIMIT 1`,
      [vendorId],
    );

    if (rows.length === 0) {
      return true;
    }

    const status = rows[0].status;
    if (status === 'suspended' || status === 'rejected') {
      throw new ForbiddenException({
        code: 'VENDOR_GOVERNANCE_RESTRICTION',
        message: `Vendor "${rows[0].business_name}" is ${status} by platform governance.`,
        status,
      });
    }

    return true;
  }
}
