import { ForbiddenException, Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../database/database.tokens';
import type { JwtUser } from '../common/types/jwt-user';
import { hasAnyAdminRole } from '../common/roles/role-helpers';
import { AuditLogService } from '../audit/audit-log.service';

export interface BookingRow {
  id: string;
  tenant_id: string;
  client_user_id: string;
  vendor_id: string;
  package_id: string;
  status: string;
  currency: string;
  guest_count: number;
  event_starts_at: Date;
  event_ends_at: Date | null;
  location_text: string | null;
  client_notes: string | null;
  pricing_snapshot: unknown;
  subtotal_minor: string;
  platform_fee_minor: string;
  total_minor: string;
  version: number;
  created_at: Date;
  updated_at: Date;
}

@Injectable()
export class BookingAccessService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly audit: AuditLogService,
  ) {}

  private async userManagesVendor(tenantId: string, vendorId: string, userId: string) {
    const { rowCount } = await this.pool.query(
      `SELECT 1 FROM vendors v
       WHERE v.id = $1 AND v.tenant_id = $2
         AND v.status::text NOT IN ('suspended', 'rejected')
         AND (v.owner_user_id = $3 OR EXISTS (
           SELECT 1 FROM vendor_users vu WHERE vu.vendor_id = v.id AND vu.user_id = $3
         ))`,
      [vendorId, tenantId, userId],
    );
    return !!rowCount;
  }

  /**
   * Client-only: booking owner may initiate payment (stricter than read access).
   */
  async assertClientOwnsBooking(tenantId: string, bookingId: string, clientUserId: string): Promise<void> {
    const { rows } = await this.pool.query<{ client_user_id: string }>(
      `SELECT client_user_id FROM bookings WHERE id = $1 AND tenant_id = $2`,
      [bookingId, tenantId],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'Booking not found' });
    }
    if (row.client_user_id !== clientUserId) {
      throw new ForbiddenException({
        code: 'FORBIDDEN',
        message: 'Only the booking client may perform this action',
      });
    }
  }

  async assertCanReadBooking(tenantId: string, bookingId: string, user: JwtUser): Promise<void> {
    const { rows } = await this.pool.query<Pick<BookingRow, 'client_user_id' | 'vendor_id'>>(
      `SELECT client_user_id, vendor_id FROM bookings
       WHERE id = $1 AND tenant_id = $2`,
      [bookingId, tenantId],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'Booking not found' });
    }
    if (hasAnyAdminRole(user.roles)) {
      return;
    }
    if (row.client_user_id === user.userId) {
      return;
    }
    if (
      (user.roles.includes('vendor') || user.roles.includes('vendor_pending')) &&
      (await this.userManagesVendor(tenantId, row.vendor_id, user.userId))
    ) {
      return;
    }
    throw new NotFoundException({ code: 'NOT_FOUND', message: 'Booking not found' });
  }

  async listBookingsForPrincipal(
    tenantId: string,
    user: JwtUser,
    status?: string,
  ): Promise<BookingRow[]> {
    if (hasAnyAdminRole(user.roles)) {
      const { rows } = await this.pool.query<BookingRow>(
        `SELECT * FROM bookings
         WHERE tenant_id = $1
           AND ($2::text IS NULL OR status::text = $2)
         ORDER BY created_at DESC
         LIMIT 100`,
        [tenantId, status ?? null],
      );
      return rows;
    }
    if (user.roles.includes('client')) {
      const { rows } = await this.pool.query<BookingRow>(
        `SELECT * FROM bookings
         WHERE tenant_id = $1 AND client_user_id = $2
           AND ($3::text IS NULL OR status::text = $3)
         ORDER BY created_at DESC
         LIMIT 100`,
        [tenantId, user.userId, status ?? null],
      );
      return rows;
    }
    if (user.roles.includes('vendor') || user.roles.includes('vendor_pending')) {
      const { rows } = await this.pool.query<BookingRow>(
        `SELECT b.* FROM bookings b
         INNER JOIN vendors v ON v.id = b.vendor_id AND v.tenant_id = b.tenant_id
         WHERE b.tenant_id = $1
           AND v.status::text NOT IN ('suspended', 'rejected')
           AND (v.owner_user_id = $2 OR EXISTS (
             SELECT 1 FROM vendor_users vu WHERE vu.vendor_id = v.id AND vu.user_id = $2
           ))
           AND ($3::text IS NULL OR b.status::text = $3)
         ORDER BY b.created_at DESC
         LIMIT 100`,
        [tenantId, user.userId, status ?? null],
      );
      return rows;
    }
    throw new ForbiddenException({
      code: 'FORBIDDEN',
      message: 'No booking access for this principal',
    });
  }

  async getBooking(tenantId: string, bookingId: string, user: JwtUser): Promise<BookingRow> {
    await this.assertCanReadBooking(tenantId, bookingId, user);
    const { rows } = await this.pool.query<BookingRow>(
      `SELECT * FROM bookings WHERE id = $1 AND tenant_id = $2`,
      [bookingId, tenantId],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'Booking not found' });
    }
    if (hasAnyAdminRole(user.roles)) {
      await this.audit.logRead({
        tenantId,
        actorUserId: user.userId,
        action: 'VIEW_BOOKING',
        resourceType: 'booking',
        resourceId: bookingId,
      });
    }
    return row;
  }
}
