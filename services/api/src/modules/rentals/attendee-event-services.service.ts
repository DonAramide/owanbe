import {
  ForbiddenException,
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';
import { RentalsService, type RentalBookingView, type RentalCatalogItemView } from './rentals.service';

export type EventServiceVendorView = {
  vendorId: string;
  businessName: string;
  slug: string;
  description: string | null;
  logoUrl: string | null;
  city: string | null;
  category: string | null;
  categories: string[];
  availability: 'available' | 'limited' | 'unavailable';
  hasRentals: boolean;
  rentalItemCount: number;
};

export type AttendeeServiceStatus =
  | 'pending'
  | 'confirmed'
  | 'in_progress'
  | 'ready'
  | 'completed'
  | 'cancelled'
  | 'expired';

@Injectable()
export class AttendeeEventServicesService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly rentals: RentalsService,
  ) {}

  /** Map rental booking status → attendee-facing service status. */
  static mapServiceStatus(status: string, eventEndsAt?: Date | null): AttendeeServiceStatus {
    const now = new Date();
    if (eventEndsAt && eventEndsAt.getTime() < now.getTime() && ['pending', 'approved', 'countered'].includes(status)) {
      return 'expired';
    }
    switch (status) {
      case 'pending':
      case 'countered':
        return 'pending';
      case 'approved':
        return 'confirmed';
      case 'delivered':
        return 'ready';
      case 'returned':
        return 'completed';
      case 'declined':
      case 'cancelled':
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  async hub(actor: CommerceActor, eventKey: string) {
    const event = await this.access.resolveEventRow(actor.tenantId, eventKey, true);
    await this.assertAttendee(actor, event.id);
    const vendors = await this.listEventVendors(actor, eventKey, {});
    const bookings = await this.listMyBookingsForEvent(actor, event.id);
    const categories = [
      ...new Set(vendors.items.flatMap((v) => (v.category ? [v.category] : v.categories))),
    ].sort();
    return {
      eventId: event.id,
      eventTitle: event.title,
      startsAt: event.starts_at instanceof Date ? event.starts_at.toISOString() : event.starts_at,
      endsAt: event.ends_at instanceof Date ? event.ends_at.toISOString() : event.ends_at,
      availableServices: [
        {
          id: 'rentals',
          label: 'Equipment rentals',
          description: 'Browse and book rental equipment from event vendors.',
          vendorCount: vendors.items.filter((v) => v.hasRentals).length,
          itemCount: vendors.items.reduce((n, v) => n + v.rentalItemCount, 0),
        },
      ],
      categories,
      vendors: vendors.items.slice(0, 8),
      myBookings: bookings.items.slice(0, 5),
      bookingCount: bookings.items.length,
    };
  }

  async listEventVendors(
    actor: CommerceActor,
    eventKey: string,
    query: { q?: string; category?: string },
  ) {
    const event = await this.access.resolveEventRow(actor.tenantId, eventKey, true);
    await this.assertAttendee(actor, event.id);

    const { rows } = await this.pool.query<{
      id: string;
      slug: string;
      business_name: string;
      description: string | null;
      logo_url: string | null;
      city: string | null;
      categories: string[] | null;
      rental_item_count: string;
      available_units: string;
    }>(
      `WITH attached AS (
         SELECT vendor_id FROM vendor_event_participations
         WHERE tenant_id = $1 AND event_id = $2
           AND status IN ('approved', 'live', 'completed', 'invited', 'pending', 'applied')
         UNION
         SELECT vendor_id FROM vendor_event_requests
         WHERE tenant_id = $1 AND event_id = $2
           AND stage IN ('new', 'negotiating', 'accepted', 'scheduled', 'arrived', 'completed')
       )
       SELECT v.id, v.slug, v.business_name, v.description, v.logo_url, v.city,
              COALESCE(
                (SELECT array_agg(DISTINCT i.category_slug)
                 FROM rental_catalog_items i
                 WHERE i.vendor_id = v.id AND i.tenant_id = v.tenant_id AND i.active = true),
                '{}'
              ) AS categories,
              (SELECT COUNT(*)::text FROM rental_catalog_items i
               WHERE i.vendor_id = v.id AND i.tenant_id = v.tenant_id AND i.active = true) AS rental_item_count,
              (SELECT COALESCE(SUM(i.available_quantity), 0)::text FROM rental_catalog_items i
               WHERE i.vendor_id = v.id AND i.tenant_id = v.tenant_id AND i.active = true) AS available_units
       FROM vendors v
       INNER JOIN attached a ON a.vendor_id = v.id
       WHERE v.tenant_id = $1 AND v.status = 'active'
       ORDER BY v.business_name ASC`,
      [actor.tenantId, event.id],
    );

    let items: EventServiceVendorView[] = rows.map((r) => {
      const cats = (r.categories ?? []).filter(Boolean);
      const rentalCount = Number(r.rental_item_count) || 0;
      const units = Number(r.available_units) || 0;
      let availability: EventServiceVendorView['availability'] = 'unavailable';
      if (rentalCount > 0 && units > 0) availability = units < 3 ? 'limited' : 'available';
      else if (rentalCount > 0) availability = 'unavailable';
      return {
        vendorId: r.id,
        businessName: r.business_name,
        slug: r.slug,
        description: r.description,
        logoUrl: r.logo_url,
        city: r.city,
        category: cats[0] ?? (rentalCount > 0 ? 'rentals' : 'services'),
        categories: cats.length ? cats : rentalCount > 0 ? ['rentals'] : ['services'],
        availability,
        hasRentals: rentalCount > 0,
        rentalItemCount: rentalCount,
      };
    });

    const q = query.q?.trim().toLowerCase() ?? '';
    const category = query.category?.trim().toLowerCase() ?? '';
    if (q) {
      items = items.filter((v) => {
        const hay = `${v.businessName} ${v.description ?? ''} ${v.categories.join(' ')}`.toLowerCase();
        return hay.includes(q);
      });
    }
    if (category) {
      items = items.filter(
        (v) =>
          v.categories.some((c) => c.toLowerCase().includes(category)) ||
          (category === 'rentals' && v.hasRentals),
      );
    }

    return { items, eventId: event.id };
  }

  async listEventRentalCatalog(actor: CommerceActor, eventKey: string, category?: string) {
    const event = await this.access.resolveEventRow(actor.tenantId, eventKey, true);
    await this.assertAttendee(actor, event.id);
    const attachedIds = await this.attachedVendorIds(actor.tenantId, event.id);
    if (!attachedIds.size) return { items: [] as RentalCatalogItemView[], eventId: event.id };

    const { items } = await this.rentals.listMarketplaceCatalog(actor.tenantId, category);
    const filtered = items.filter((i) => attachedIds.has(i.vendorId));
    return { items: filtered, eventId: event.id };
  }

  async bookRental(actor: CommerceActor, eventKey: string, body: Record<string, unknown>) {
    const event = await this.access.resolveEventRow(actor.tenantId, eventKey, true);
    await this.assertAttendee(actor, event.id);

    const catalogItemId = String(body.catalogItemId ?? '');
    const { rows: items } = await this.pool.query<{ vendor_id: string }>(
      `SELECT vendor_id FROM rental_catalog_items
       WHERE tenant_id = $1 AND id = $2::uuid AND active = true`,
      [actor.tenantId, catalogItemId],
    );
    const item = items[0];
    if (!item) throw new NotFoundException({ code: 'ITEM_NOT_FOUND', message: 'Rental item not found' });
    const attached = await this.attachedVendorIds(actor.tenantId, event.id);
    if (!attached.has(item.vendor_id)) {
      throw new ForbiddenException({
        code: 'VENDOR_NOT_ON_EVENT',
        message: 'This rental vendor is not available for this event',
      });
    }

    const displayName = await this.requesterName(actor);
    const booking = await this.rentals.createBooking(
      actor.tenantId,
      event.id,
      { ...body, requesterName: String(body.requesterName ?? displayName) },
      actor.userId,
    );
    await this.notify(
      actor.tenantId,
      actor.userId,
      'service_booking_updated',
      'Rental request submitted',
      `${booking.itemName} — pending vendor confirmation.`,
      { eventId: event.id, bookingId: booking.id, status: booking.status, kind: 'rental' },
    );
    return this.enrichBooking(booking, event.ends_at as Date | null);
  }

  async listMyBookings(actor: CommerceActor, eventId?: string) {
    const params: unknown[] = [actor.tenantId, actor.userId];
    let eventFilter = '';
    if (eventId) {
      const event = await this.access.resolveEventRow(actor.tenantId, eventId, true);
      eventFilter = ' AND b.event_id = $3';
      params.push(event.id);
    }
    const { rows } = await this.pool.query<{
      id: string;
      event_id: string;
      event_title: string;
      ends_at: Date | null;
      vendor_id: string;
      vendor_name: string;
      catalog_item_id: string;
      item_name: string;
      category_slug: string;
      requester_name: string;
      quantity_requested: number;
      quantity_approved: number | null;
      counter_quantity: number | null;
      status: string;
      rental_fee_minor: string;
      deposit_minor: string;
      delivery_date: Date | null;
      pickup_date: Date | null;
      delivery_address: string | null;
      damage_notes: string | null;
      delivered_at: Date | null;
      returned_at: Date | null;
      created_at: Date;
    }>(
      `SELECT b.id, b.event_id, e.title AS event_title, e.ends_at, b.vendor_id, v.business_name AS vendor_name,
              b.catalog_item_id, i.name AS item_name, i.category_slug, b.requester_name,
              b.quantity_requested, b.quantity_approved, b.counter_quantity, b.status,
              b.rental_fee_minor, b.deposit_minor, b.delivery_date, b.pickup_date,
              b.delivery_address, b.damage_notes, b.delivered_at, b.returned_at, b.created_at
       FROM rental_bookings b
       JOIN events e ON e.id = b.event_id
       JOIN vendors v ON v.id = b.vendor_id
       JOIN rental_catalog_items i ON i.id = b.catalog_item_id
       WHERE b.tenant_id = $1 AND b.requester_user_id = $2
       ${eventFilter}
       ORDER BY b.created_at DESC`,
      params,
    );

    return {
      items: rows.map((r) => ({
        ...this.rowToBooking(r),
        serviceStatus: AttendeeEventServicesService.mapServiceStatus(r.status, r.ends_at),
        confirmationNumber: `OB-${r.id.replace(/-/g, '').slice(0, 8).toUpperCase()}`,
        serviceKind: 'rental' as const,
      })),
    };
  }

  async listMyBookingsForEvent(actor: CommerceActor, eventId: string) {
    return this.listMyBookings(actor, eventId);
  }

  async cancelBooking(actor: CommerceActor, bookingId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      status: string;
      requester_user_id: string | null;
      event_id: string;
      item_name: string;
    }>(
      `SELECT b.id, b.status, b.requester_user_id, b.event_id, i.name AS item_name
       FROM rental_bookings b
       JOIN rental_catalog_items i ON i.id = b.catalog_item_id
       WHERE b.tenant_id = $1 AND b.id = $2::uuid`,
      [actor.tenantId, bookingId],
    );
    const row = rows[0];
    if (!row) throw new NotFoundException({ code: 'BOOKING_NOT_FOUND', message: 'Booking not found' });
    if (row.requester_user_id !== actor.userId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'Not your booking' });
    }
    if (!['pending', 'countered'].includes(row.status)) {
      throw new UnprocessableEntityException({
        code: 'INVALID_STATE',
        message: 'Only pending requests can be cancelled',
      });
    }
    await this.pool.query(
      `UPDATE rental_bookings SET status = 'cancelled', updated_at = now()
       WHERE tenant_id = $1 AND id = $2::uuid`,
      [actor.tenantId, bookingId],
    );
    await this.notify(
      actor.tenantId,
      actor.userId,
      'service_booking_cancelled',
      'Booking cancelled',
      `${row.item_name} was cancelled.`,
      { eventId: row.event_id, bookingId: row.id, status: 'cancelled', kind: 'rental' },
    );
    const listed = await this.listMyBookings(actor);
    const booking = listed.items.find((b) => b.id === bookingId);
    if (!booking) throw new NotFoundException({ code: 'BOOKING_NOT_FOUND', message: 'Booking not found' });
    return booking;
  }

  async listNotifications(actor: CommerceActor) {
    const { rows } = await this.pool.query<{
      id: string;
      kind: string;
      title: string | null;
      body: string | null;
      data: Record<string, unknown>;
      created_at: Date;
      read_at: Date | null;
    }>(
      `SELECT id, kind, title, body, data, created_at, read_at
       FROM notifications
       WHERE tenant_id = $1 AND user_id = $2 AND channel = 'in_app'
         AND kind IN (
           'service_booking_confirmed', 'service_booking_updated',
           'service_booking_cancelled', 'service_booking_completed'
         )
       ORDER BY created_at DESC
       LIMIT 50`,
      [actor.tenantId, actor.userId],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        kind: r.kind,
        title: r.title,
        body: r.body,
        data: r.data ?? {},
        createdAt: r.created_at.toISOString(),
        read: r.read_at != null,
      })),
    };
  }

  /** Called from vendor status transitions. */
  async notifyRequesterOfStatus(tenantId: string, bookingId: string, kind: string, title: string, body: string) {
    const { rows } = await this.pool.query<{
      requester_user_id: string | null;
      event_id: string;
      status: string;
    }>(
      `SELECT requester_user_id, event_id, status FROM rental_bookings
       WHERE tenant_id = $1 AND id = $2::uuid`,
      [tenantId, bookingId],
    );
    const row = rows[0];
    if (!row?.requester_user_id) return;
    await this.notify(tenantId, row.requester_user_id, kind, title, body, {
      eventId: row.event_id,
      bookingId,
      status: row.status,
      kind: 'rental',
    });
  }

  private enrichBooking(booking: RentalBookingView, endsAt: Date | null) {
    return {
      ...booking,
      serviceStatus: AttendeeEventServicesService.mapServiceStatus(booking.status, endsAt),
      confirmationNumber: `OB-${booking.id.replace(/-/g, '').slice(0, 8).toUpperCase()}`,
      serviceKind: 'rental' as const,
    };
  }

  private rowToBooking(r: {
    id: string;
    event_id: string;
    event_title: string;
    vendor_id: string;
    vendor_name: string;
    catalog_item_id: string;
    item_name: string;
    category_slug: string;
    requester_name: string;
    quantity_requested: number;
    quantity_approved: number | null;
    counter_quantity: number | null;
    status: string;
    rental_fee_minor: string;
    deposit_minor: string;
    delivery_date: Date | null;
    pickup_date: Date | null;
    delivery_address: string | null;
    damage_notes: string | null;
    delivered_at: Date | null;
    returned_at: Date | null;
    created_at: Date;
  }): RentalBookingView {
    return {
      id: r.id,
      eventId: r.event_id,
      eventTitle: r.event_title,
      vendorId: r.vendor_id,
      vendorName: r.vendor_name,
      catalogItemId: r.catalog_item_id,
      itemName: r.item_name,
      categorySlug: r.category_slug,
      requesterName: r.requester_name,
      quantityRequested: r.quantity_requested,
      quantityApproved: r.quantity_approved,
      counterQuantity: r.counter_quantity,
      status: r.status as RentalBookingView['status'],
      rentalFeeMinor: Number(r.rental_fee_minor),
      depositMinor: Number(r.deposit_minor),
      deliveryDate: r.delivery_date ? r.delivery_date.toISOString().slice(0, 10) : null,
      pickupDate: r.pickup_date ? r.pickup_date.toISOString().slice(0, 10) : null,
      deliveryAddress: r.delivery_address,
      damageNotes: r.damage_notes,
      deliveredAt: r.delivered_at?.toISOString() ?? null,
      returnedAt: r.returned_at?.toISOString() ?? null,
      createdAt: r.created_at.toISOString(),
    };
  }

  private async attachedVendorIds(tenantId: string, eventId: string): Promise<Set<string>> {
    const { rows } = await this.pool.query<{ vendor_id: string }>(
      `SELECT vendor_id FROM vendor_event_participations
       WHERE tenant_id = $1 AND event_id = $2
         AND status IN ('approved', 'live', 'completed', 'invited', 'pending', 'applied')
       UNION
       SELECT vendor_id FROM vendor_event_requests
       WHERE tenant_id = $1 AND event_id = $2
         AND stage IN ('new', 'negotiating', 'accepted', 'scheduled', 'arrived', 'completed')`,
      [tenantId, eventId],
    );
    return new Set(rows.map((r) => r.vendor_id));
  }

  private async assertAttendee(actor: CommerceActor, eventId: string) {
    const { rows } = await this.pool.query(
      `SELECT 1 FROM ticket_entitlements
       WHERE tenant_id = $1 AND event_id = $2 AND holder_user_id = $3
         AND status IN ('issued', 'checked_in')
       LIMIT 1`,
      [actor.tenantId, eventId, actor.userId],
    );
    if (!rows.length) {
      throw new ForbiddenException({
        code: 'NOT_ATTENDING',
        message: 'You need a ticket for this event to use event services',
      });
    }
  }

  private async requesterName(actor: CommerceActor): Promise<string> {
    const { rows } = await this.pool.query<{ display_name: string | null; email: string }>(
      `SELECT display_name, email FROM users WHERE id = $1 AND tenant_id = $2`,
      [actor.userId, actor.tenantId],
    );
    const r = rows[0];
    return r?.display_name?.trim() || r?.email?.split('@')[0] || 'Attendee';
  }

  private async notify(
    tenantId: string,
    userId: string,
    kind: string,
    title: string,
    body: string,
    data: Record<string, unknown>,
  ) {
    const dedupe = `${kind}:${data.bookingId ?? ''}:${data.status ?? ''}`;
    await this.pool.query(
      `INSERT INTO notifications (tenant_id, user_id, channel, status, kind, title, body, data, dedupe_key, sent_at, delivered_at)
       VALUES ($1, $2, 'in_app', 'delivered', $3, $4, $5, $6::jsonb, $7, now(), now())
       ON CONFLICT (tenant_id, user_id, dedupe_key) DO UPDATE
         SET title = EXCLUDED.title, body = EXCLUDED.body, data = EXCLUDED.data,
             updated_at = now(), sent_at = now(), delivered_at = now()`,
      [tenantId, userId, kind, title, body, JSON.stringify(data), dedupe],
    );
  }
}
