import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../database/database.tokens';

@Injectable()
export class VendorAccessService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /**
   * Vendor owner or `vendor_users` member.
   * Blocks `suspended` and `rejected` vendors from mutating flows (onboarding writes, etc.).
   */
  async assertVendorOwnerOrStaff(
    tenantId: string,
    vendorId: string,
    userId: string,
    opts?: { allowSuspendedRead?: boolean },
  ): Promise<void> {
    const allowSuspendedRead = opts?.allowSuspendedRead ?? false;
    const statusClause = allowSuspendedRead
      ? 'TRUE'
      : `v.status::text NOT IN ('suspended', 'rejected')`;

    const { rowCount } = await this.pool.query(
      `SELECT 1 FROM vendors v
       WHERE v.id = $1 AND v.tenant_id = $2
         AND (${statusClause})
         AND (v.owner_user_id = $3 OR EXISTS (
           SELECT 1 FROM vendor_users vu
           WHERE vu.vendor_id = v.id AND vu.user_id = $3
         ))`,
      [vendorId, tenantId, userId],
    );
    if (!rowCount) {
      throw new NotFoundException({
        code: 'NOT_FOUND',
        message: 'Vendor not found',
      });
    }
  }
}
