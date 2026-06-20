import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';

import { PG_POOL } from '../../database/database.tokens';
import {
  FINANCE_POLICY_DEFAULTS,
  type TenantFinancePolicy,
} from './commerce.types';

interface TenantFinanceSettingsRow {
  tenant_id: string;
  ticket_platform_fee_bps: number;
  vendor_platform_fee_bps: number;
  escrow_release_delay_hours: number;
}

@Injectable()
export class TenantFinancePolicyService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getPolicy(tenantId: string): Promise<TenantFinancePolicy> {
    const { rows } = await this.pool.query<TenantFinanceSettingsRow>(
      `SELECT tenant_id, ticket_platform_fee_bps, vendor_platform_fee_bps, escrow_release_delay_hours
       FROM tenant_finance_settings
       WHERE tenant_id = $1`,
      [tenantId],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException(`tenant finance settings not found for ${tenantId}`);
    }
    return {
      tenantId: row.tenant_id,
      ticketPlatformFeeBps: row.ticket_platform_fee_bps ?? FINANCE_POLICY_DEFAULTS.ticketPlatformFeeBps,
      vendorPlatformFeeBps: row.vendor_platform_fee_bps ?? FINANCE_POLICY_DEFAULTS.vendorPlatformFeeBps,
      escrowReleaseDelayHours:
        row.escrow_release_delay_hours ?? FINANCE_POLICY_DEFAULTS.escrowReleaseDelayHours,
    };
  }

  /** Escrow release timestamp from event/order completion + tenant delay. */
  escrowReleaseNotBefore(completedAt: Date, delayHours: number): Date {
    return new Date(completedAt.getTime() + delayHours * 60 * 60 * 1000);
  }
}
