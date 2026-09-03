import { Injectable, Inject, UnprocessableEntityException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import {
  classifyDateAvailability,
  clipRange,
  rangesOverlap,
  resolveEventWindow,
  type BookedRange,
  type DateAvailabilityStatus,
} from './vendor-availability.util';

export type PublicBookedRange = { startsAt: string; endsAt: string };
export type PublicUnavailableRange = {
  startsAt: string;
  endsAt: string;
  kind: 'blackout' | 'vacation' | 'closed';
};

@Injectable()
export class VendorAvailabilityService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async eventWindowForId(
    tenantId: string,
    eventId: string,
  ): Promise<{ start: Date; end: Date } | null> {
    const { rows } = await this.pool.query<{ starts_at: Date; ends_at: Date | null }>(
      `SELECT starts_at, ends_at FROM events WHERE tenant_id = $1 AND id = $2`,
      [tenantId, eventId],
    );
    const row = rows[0];
    if (!row) return null;
    return resolveEventWindow(row.starts_at, row.ends_at);
  }

  async classifyServiceWindow(opts: {
    tenantId: string;
    vendorId: string;
    vendorServiceId: string | null;
    serviceKey: string;
    window: { start: Date; end: Date };
    offerActive: boolean;
    excludeRequestId?: string | null;
  }): Promise<{
    availabilityStatus: DateAvailabilityStatus;
    bookedRanges: PublicBookedRange[];
    unavailableRanges: PublicUnavailableRange[];
  }> {
    const unavailable = await this.loadUnavailableRanges(opts.tenantId, opts.vendorId, opts.window);
    const overlayHitsWindow = unavailable.length > 0;

    const booked = opts.offerActive
      ? await this.loadBookedRanges({
          tenantId: opts.tenantId,
          vendorId: opts.vendorId,
          vendorServiceId: opts.vendorServiceId,
          serviceKey: opts.serviceKey,
          window: opts.window,
          excludeRequestId: opts.excludeRequestId ?? null,
        })
      : [];

    const bookedRanges = booked.map((b) => ({
      startsAt: b.start.toISOString(),
      endsAt: b.end.toISOString(),
    }));
    const unavailableRanges = unavailable.map((u) => ({
      startsAt: u.start.toISOString(),
      endsAt: u.end.toISOString(),
      kind: u.kind,
    }));

    if (!opts.offerActive || overlayHitsWindow) {
      return { availabilityStatus: 'UNAVAILABLE', bookedRanges, unavailableRanges };
    }

    return {
      availabilityStatus: classifyDateAvailability(opts.window, booked),
      bookedRanges,
      unavailableRanges,
    };
  }

  async assertServiceWindowBookable(opts: {
    tenantId: string;
    vendorId: string;
    vendorServiceId: string | null;
    serviceKey: string;
    window: { start: Date; end: Date };
    offerActive: boolean;
    excludeRequestId?: string | null;
  }): Promise<void> {
    const result = await this.classifyServiceWindow(opts);
    if (result.availabilityStatus === 'UNAVAILABLE') {
      throw new UnprocessableEntityException({
        code: 'SERVICE_UNAVAILABLE',
        message: 'This service is not available for the selected dates',
      });
    }
    if (result.availabilityStatus === 'BOOKED' || result.availabilityStatus === 'CONFLICTING') {
      throw new UnprocessableEntityException({
        code: 'CALENDAR_CONFLICT',
        message: 'This service is already booked for overlapping dates',
        bookedRanges: result.bookedRanges,
      });
    }
  }

  private async loadUnavailableRanges(
    tenantId: string,
    vendorId: string,
    window: { start: Date; end: Date },
  ): Promise<Array<BookedRange & { kind: PublicUnavailableRange['kind'] }>> {
    const out: Array<BookedRange & { kind: PublicUnavailableRange['kind'] }> = [];
    const pushClipped = (range: BookedRange, kind: PublicUnavailableRange['kind']) => {
      const clipped = clipRange(range, window);
      if (clipped) out.push({ ...clipped, kind });
    };

    const { rows: profile } = await this.pool.query<{ available_for_bookings: boolean | null }>(
      `SELECT available_for_bookings FROM vendor_profiles
       WHERE tenant_id = $1 AND vendor_id = $2
       LIMIT 1`,
      [tenantId, vendorId],
    );
    if (profile[0]?.available_for_bookings === false) {
      pushClipped(window, 'closed');
    }

    const { rows: settings } = await this.pool.query<{
      vacation_mode: boolean;
      vacation_until: Date | null;
    }>(
      `SELECT vacation_mode, vacation_until FROM vendor_availability_settings WHERE vendor_id = $1`,
      [vendorId],
    );
    const s = settings[0];
    if (s?.vacation_mode) {
      const vacationEnd = s.vacation_until ?? window.end;
      pushClipped({ start: window.start, end: vacationEnd }, 'vacation');
    }

    const { rows: blocks } = await this.pool.query<{
      starts_at: Date;
      ends_at: Date;
      kind: string;
    }>(
      `SELECT starts_at, ends_at, kind FROM vendor_calendar_blocks
       WHERE tenant_id = $1 AND vendor_id = $2
         AND kind IN ('blackout', 'vacation')
         AND starts_at < $4 AND ends_at > $3`,
      [tenantId, vendorId, window.start, window.end],
    );
    for (const b of blocks) {
      if (!rangesOverlap(window.start, window.end, b.starts_at, b.ends_at)) continue;
      const kind = b.kind === 'vacation' ? 'vacation' : 'blackout';
      pushClipped({ start: b.starts_at, end: b.ends_at }, kind);
    }

    return out;
  }

  private async loadBookedRanges(opts: {
    tenantId: string;
    vendorId: string;
    vendorServiceId: string | null;
    serviceKey: string;
    window: { start: Date; end: Date };
    excludeRequestId: string | null;
  }): Promise<BookedRange[]> {
    const { rows } = await this.pool.query<{ starts_at: Date; ends_at: Date | null }>(
      `SELECT e.starts_at, e.ends_at
       FROM vendor_event_requests r
       JOIN events e ON e.id = r.event_id
       WHERE r.tenant_id = $1
         AND r.vendor_id = $2
         AND r.stage IN ('accepted', 'scheduled', 'arrived', 'completed')
         AND ($6::uuid IS NULL OR r.id <> $6)
         AND (
           ($3::uuid IS NOT NULL AND r.vendor_service_id = $3)
           OR (
             r.service_key = $4
             AND ($3::uuid IS NULL OR r.vendor_service_id IS NULL OR r.vendor_service_id = $3)
           )
         )
         AND e.starts_at < $5
         AND COALESCE(e.ends_at, e.starts_at + interval '24 hours') > $7`,
      [
        opts.tenantId,
        opts.vendorId,
        opts.vendorServiceId,
        opts.serviceKey,
        opts.window.end,
        opts.excludeRequestId,
        opts.window.start,
      ],
    );
    return rows.map((r) => resolveEventWindow(r.starts_at, r.ends_at));
  }
}
