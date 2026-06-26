import {
  BadRequestException,
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';

export const CALENDAR_BLOCK_KINDS = [
  'blackout',
  'vacation',
  'booking',
  'rental_delivery',
  'crm_scheduled',
  'tentative',
] as const;
export type CalendarBlockKind = (typeof CALENDAR_BLOCK_KINDS)[number];

export type CalendarBlockView = {
  id: string;
  kind: CalendarBlockKind;
  startsAt: string;
  endsAt: string;
  allDay: boolean;
  sourceType: string | null;
  sourceId: string | null;
  reason: string | null;
};

export type VendorCalendarView = {
  vacationMode: boolean;
  vacationUntil: string | null;
  blocks: CalendarBlockView[];
  conflicts: CalendarBlockView[];
};

@Injectable()
export class VendorCalendarService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  private async ensureSettings(tenantId: string, vendorId: string) {
    await this.pool.query(
      `INSERT INTO vendor_availability_settings (vendor_id, tenant_id)
       VALUES ($1, $2) ON CONFLICT (vendor_id) DO NOTHING`,
      [vendorId, tenantId],
    );
  }

  private rowToBlock(row: {
    id: string;
    kind: string;
    starts_at: Date;
    ends_at: Date;
    all_day: boolean;
    source_type: string | null;
    source_id: string | null;
    reason: string | null;
  }): CalendarBlockView {
    return {
      id: row.id,
      kind: row.kind as CalendarBlockKind,
      startsAt: row.starts_at.toISOString(),
      endsAt: row.ends_at.toISOString(),
      allDay: row.all_day,
      sourceType: row.source_type,
      sourceId: row.source_id,
      reason: row.reason,
    };
  }

  async assertAvailable(tenantId: string, vendorId: string, startsAt: Date, endsAt: Date) {
    await this.ensureSettings(tenantId, vendorId);
    const { rows: settings } = await this.pool.query<{ vacation_mode: boolean; vacation_until: Date | null }>(
      `SELECT vacation_mode, vacation_until FROM vendor_availability_settings WHERE vendor_id = $1`,
      [vendorId],
    );
    const s = settings[0];
    if (s?.vacation_mode) {
      if (!s.vacation_until || s.vacation_until >= startsAt) {
        throw new UnprocessableEntityException({ code: 'VENDOR_VACATION', message: 'Vendor is on vacation' });
      }
    }
    const conflicts = await this.findConflicts(tenantId, vendorId, startsAt, endsAt);
    if (conflicts.length > 0) {
      throw new UnprocessableEntityException({
        code: 'CALENDAR_CONFLICT',
        message: 'Vendor has a scheduling conflict',
        conflicts,
      });
    }
  }

  async findConflicts(tenantId: string, vendorId: string, startsAt: Date, endsAt: Date) {
    const blocks = await this.loadBlocks(tenantId, vendorId, startsAt, endsAt);
    const rentals = await this.loadRentalBlocks(tenantId, vendorId, startsAt, endsAt);
    return [...blocks, ...rentals];
  }

  private async loadBlocks(tenantId: string, vendorId: string, from: Date, to: Date) {
    const { rows } = await this.pool.query(
      `SELECT id, kind, starts_at, ends_at, all_day, source_type, source_id, reason
       FROM vendor_calendar_blocks
       WHERE tenant_id = $1 AND vendor_id = $2
         AND starts_at < $4 AND ends_at > $3
       ORDER BY starts_at`,
      [tenantId, vendorId, from, to],
    );
    return rows.map((r) => this.rowToBlock(r));
  }

  private async loadRentalBlocks(tenantId: string, vendorId: string, from: Date, to: Date) {
    const fromDate = from.toISOString().slice(0, 10);
    const toDate = to.toISOString().slice(0, 10);
    const { rows } = await this.pool.query(
      `SELECT rb.id, rb.delivery_date, rb.pickup_date, rc.name
       FROM rental_bookings rb
       JOIN rental_catalog_items rc ON rc.id = rb.catalog_item_id
       WHERE rb.tenant_id = $1 AND rb.vendor_id = $2
         AND rb.status IN ('approved', 'delivered')
         AND rb.delivery_date IS NOT NULL
         AND rb.delivery_date <= $4::date
         AND COALESCE(rb.pickup_date, rb.delivery_date) >= $3::date`,
      [tenantId, vendorId, fromDate, toDate],
    );
    return rows.map((r) => {
      const start = new Date(`${r.delivery_date}T08:00:00Z`);
      const endDate = r.pickup_date ?? r.delivery_date;
      const end = new Date(`${endDate}T20:00:00Z`);
      return {
        id: r.id,
        kind: 'rental_delivery' as CalendarBlockKind,
        startsAt: start.toISOString(),
        endsAt: end.toISOString(),
        allDay: true,
        sourceType: 'rental_booking',
        sourceId: r.id,
        reason: r.name,
      };
    });
  }

  async syncCrmBlock(tenantId: string, vendorId: string, requestId: string, startsAt: Date, endsAt: Date) {
    await this.pool.query(
      `DELETE FROM vendor_calendar_blocks
       WHERE tenant_id = $1 AND vendor_id = $2 AND source_type = 'vendor_request' AND source_id = $3`,
      [tenantId, vendorId, requestId],
    );
    await this.pool.query(
      `INSERT INTO vendor_calendar_blocks
         (tenant_id, vendor_id, kind, starts_at, ends_at, source_type, source_id, reason)
       VALUES ($1, $2, 'crm_scheduled', $3, $4, 'vendor_request', $5, 'CRM scheduled service')`,
      [tenantId, vendorId, startsAt, endsAt, requestId],
    );
  }

  async getCalendar(tenantId: string, vendorId: string, fromRaw: string, toRaw: string): Promise<VendorCalendarView> {
    await this.ensureSettings(tenantId, vendorId);
    const from = new Date(fromRaw);
    const to = new Date(toRaw);
    if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
      throw new BadRequestException({ code: 'INVALID_RANGE', message: 'from and to required' });
    }
    const { rows: settings } = await this.pool.query<{ vacation_mode: boolean; vacation_until: Date | null }>(
      `SELECT vacation_mode, vacation_until FROM vendor_availability_settings WHERE vendor_id = $1`,
      [vendorId],
    );
    const blocks = [
      ...(await this.loadBlocks(tenantId, vendorId, from, to)),
      ...(await this.loadRentalBlocks(tenantId, vendorId, from, to)),
    ].sort((a, b) => a.startsAt.localeCompare(b.startsAt));

    const { rows: blackouts } = await this.pool.query<{ blackout_date: Date; reason: string | null }>(
      `SELECT blackout_date, reason FROM rental_blackout_dates
       WHERE tenant_id = $1 AND vendor_id = $2 AND blackout_date >= $3::date AND blackout_date <= $4::date`,
      [tenantId, vendorId, from.toISOString().slice(0, 10), to.toISOString().slice(0, 10)],
    );
    for (const b of blackouts) {
      const d = b.blackout_date;
      const start = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 0, 0, 0));
      const end = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 23, 59, 59));
      blocks.push({
        id: `blackout-${d.toISOString()}`,
        kind: 'blackout',
        startsAt: start.toISOString(),
        endsAt: end.toISOString(),
        allDay: true,
        sourceType: 'rental_blackout',
        sourceId: null,
        reason: b.reason,
      });
    }

    return {
      vacationMode: settings[0]?.vacation_mode ?? false,
      vacationUntil: settings[0]?.vacation_until?.toISOString().slice(0, 10) ?? null,
      blocks,
      conflicts: [],
    };
  }

  async getCalendarForActor(actor: CommerceActor, vendorId: string, from: string, to: string) {
    const owned = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    if (owned !== vendorId) {
      throw new NotFoundException({ code: 'VENDOR_NOT_FOUND', message: 'Vendor not found' });
    }
    return this.getCalendar(actor.tenantId, vendorId, from, to);
  }

  async addBlock(actor: CommerceActor, vendorId: string, body: Record<string, unknown>) {
    const owned = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    if (owned !== vendorId) throw new NotFoundException({ code: 'VENDOR_NOT_FOUND' });
    const startsAt = new Date(String(body.startsAt ?? ''));
    const endsAt = new Date(String(body.endsAt ?? ''));
    if (Number.isNaN(startsAt.getTime()) || Number.isNaN(endsAt.getTime()) || endsAt <= startsAt) {
      throw new BadRequestException({ code: 'INVALID_WINDOW', message: 'Invalid time window' });
    }
    const kind = String(body.kind ?? 'blackout');
    if (!CALENDAR_BLOCK_KINDS.includes(kind as CalendarBlockKind)) {
      throw new BadRequestException({ code: 'INVALID_KIND', message: 'Unknown block kind' });
    }
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO vendor_calendar_blocks (tenant_id, vendor_id, kind, starts_at, ends_at, all_day, reason)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
      [
        actor.tenantId,
        vendorId,
        kind,
        startsAt,
        endsAt,
        Boolean(body.allDay),
        body.reason ? String(body.reason) : null,
      ],
    );
    return { id: rows[0]!.id };
  }

  async patchSettings(actor: CommerceActor, vendorId: string, body: Record<string, unknown>) {
    const owned = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    if (owned !== vendorId) throw new NotFoundException({ code: 'VENDOR_NOT_FOUND' });
    await this.ensureSettings(actor.tenantId, vendorId);
    await this.pool.query(
      `UPDATE vendor_availability_settings
       SET vacation_mode = COALESCE($3, vacation_mode),
           vacation_until = COALESCE($4::date, vacation_until),
           updated_at = now()
       WHERE vendor_id = $1 AND tenant_id = $2`,
      [
        vendorId,
        actor.tenantId,
        body.vacationMode != null ? Boolean(body.vacationMode) : null,
        body.vacationUntil ? String(body.vacationUntil) : null,
      ],
    );
    if (body.vacationMode === true) {
      const until = body.vacationUntil ? new Date(String(body.vacationUntil)) : new Date(Date.now() + 7 * 86400000);
      await this.pool.query(
        `INSERT INTO vendor_calendar_blocks (tenant_id, vendor_id, kind, starts_at, ends_at, all_day, reason)
         VALUES ($1, $2, 'vacation', now(), $3, true, 'Vacation mode')`,
        [actor.tenantId, vendorId, until],
      );
    }
    return this.getCalendar(actor.tenantId, vendorId, new Date().toISOString(), new Date(Date.now() + 30 * 86400000).toISOString());
  }

  async checkConflicts(actor: CommerceActor, vendorId: string, startsAtRaw: string, endsAtRaw: string) {
    const owned = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    if (owned !== vendorId) throw new NotFoundException({ code: 'VENDOR_NOT_FOUND' });
    const startsAt = new Date(startsAtRaw);
    const endsAt = new Date(endsAtRaw);
    const conflicts = await this.findConflicts(actor.tenantId, vendorId, startsAt, endsAt);
    return { hasConflict: conflicts.length > 0, conflicts };
  }
}
