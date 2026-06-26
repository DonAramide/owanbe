import {
  BadRequestException,
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { JwtUser } from '../../common/types/jwt-user';
import { BookingAccessService, type BookingRow } from '../../ownership/booking-access.service';
import { VendorAccessService } from '../../ownership/vendor-access.service';
import { mapBookingToApi } from './booking.mapper';

export type VendorBookingAction = 'accept' | 'fulfill' | 'cancel';

@Injectable()
export class BookingsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: BookingAccessService,
    private readonly vendorAccess: VendorAccessService,
  ) {}

  async listForUser(tenantId: string, user: JwtUser, status?: string) {
    const rows = await this.access.listBookingsForPrincipal(tenantId, user, status);
    const enriched = await this.enrichRows(tenantId, rows);
    return { items: enriched.map(mapBookingToApi), nextCursor: null as string | null };
  }

  async getForUser(tenantId: string, bookingId: string, user: JwtUser) {
    const row = await this.access.getBooking(tenantId, bookingId, user);
    const [enriched] = await this.enrichRows(tenantId, [row]);
    return mapBookingToApi(enriched!);
  }

  private async enrichRows(tenantId: string, rows: BookingRow[]) {
    if (rows.length === 0) return [];
    const ids = rows.map((r) => r.id);
    const { rows: meta } = await this.pool.query<{
      id: string;
      package_name: string;
      client_name: string;
    }>(
      `SELECT b.id, vp.name AS package_name,
              COALESCE(NULLIF(TRIM(u.email), ''), 'Customer') AS client_name
       FROM bookings b
       INNER JOIN vendor_packages vp ON vp.id = b.package_id
       INNER JOIN users u ON u.id = b.client_user_id
       WHERE b.tenant_id = $1 AND b.id = ANY($2::uuid[])`,
      [tenantId, ids],
    );
    const metaMap = new Map(meta.map((m) => [m.id, m]));
    return rows.map((r) => {
      const m = metaMap.get(r.id);
      const snap = (r.pricing_snapshot ?? {}) as Record<string, unknown>;
      return {
        ...r,
        package_name: m?.package_name ?? 'Package',
        client_name: m?.client_name ?? 'Customer',
        event_id: (snap.eventId ?? snap.event_id ?? '') as string,
        event_title: (snap.eventTitle ?? snap.event_title ?? r.location_text ?? 'Event') as string,
      };
    });
  }

  async updateVendorStatus(
    tenantId: string,
    userId: string,
    bookingId: string,
    action: VendorBookingAction,
  ) {
    await this.vendorAccess.resolveVendorIdForUser(tenantId, userId);
    const { rows } = await this.pool.query<{ id: string; vendor_id: string; status: string }>(
      `SELECT b.id, b.vendor_id, b.status::text AS status
       FROM bookings b
       WHERE b.id = $1 AND b.tenant_id = $2`,
      [bookingId, tenantId],
    );
    const booking = rows[0];
    if (!booking) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'Booking not found' });
    }
    await this.vendorAccess.assertVendorOwnerOrStaff(tenantId, booking.vendor_id, userId);

    const next = this.resolveTransition(booking.status, action);
    const { rows: updated } = await this.pool.query<BookingRow>(
      `UPDATE bookings SET status = $3::booking_status, updated_at = now(), version = version + 1
       WHERE id = $1 AND tenant_id = $2
       RETURNING *`,
      [bookingId, tenantId, next],
    );
    const row = updated[0];
    if (!row) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'Booking not found' });
    }
    const [enriched] = await this.enrichRows(tenantId, [row]);
    return mapBookingToApi(enriched!);
  }

  private resolveTransition(current: string, action: VendorBookingAction): string {
    if (action === 'accept') {
      if (current === 'pending_payment' || current === 'confirmed') return 'in_progress';
      throw new UnprocessableEntityException({
        code: 'INVALID_TRANSITION',
        message: `Cannot accept booking in status ${current}`,
      });
    }
    if (action === 'fulfill') {
      if (current === 'in_progress' || current === 'confirmed') return 'completed';
      throw new UnprocessableEntityException({
        code: 'INVALID_TRANSITION',
        message: `Cannot fulfill booking in status ${current}`,
      });
    }
    if (action === 'cancel') {
      if (['pending_payment', 'confirmed', 'in_progress'].includes(current)) return 'cancelled';
      throw new UnprocessableEntityException({
        code: 'INVALID_TRANSITION',
        message: `Cannot cancel booking in status ${current}`,
      });
    }
    throw new BadRequestException({ code: 'INVALID_ACTION', message: 'Unknown action' });
  }
}
