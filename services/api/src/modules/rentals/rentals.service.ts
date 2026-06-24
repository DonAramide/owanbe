import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool, PoolClient } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';

export const RENTAL_BOOKING_STATUSES = [
  'pending',
  'approved',
  'countered',
  'declined',
  'delivered',
  'returned',
  'cancelled',
] as const;
export type RentalBookingStatus = (typeof RENTAL_BOOKING_STATUSES)[number];

export type RentalCatalogItemView = {
  id: string;
  vendorId: string;
  vendorName: string;
  categorySlug: string;
  name: string;
  description: string;
  photoUrl: string | null;
  totalQuantity: number;
  availableQuantity: number;
  reservedQuantity: number;
  rentalFeeMinor: number;
  depositMinor: number;
  active: boolean;
};

export type RentalBookingView = {
  id: string;
  eventId: string;
  eventTitle: string;
  vendorId: string;
  vendorName: string;
  catalogItemId: string;
  itemName: string;
  categorySlug: string;
  requesterName: string;
  quantityRequested: number;
  quantityApproved: number | null;
  counterQuantity: number | null;
  status: RentalBookingStatus;
  rentalFeeMinor: number;
  depositMinor: number;
  deliveryDate: string | null;
  pickupDate: string | null;
  deliveryAddress: string | null;
  damageNotes: string | null;
  deliveredAt: string | null;
  returnedAt: string | null;
  createdAt: string;
};

export type RentalBlackoutView = {
  id: string;
  catalogItemId: string | null;
  blackoutDate: string;
  reason: string | null;
};

@Injectable()
export class RentalsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  private async assertVendorOwns(actor: CommerceActor, vendorId: string) {
    const resolved = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    if (resolved !== vendorId) {
      throw new ForbiddenException({ code: 'VENDOR_FORBIDDEN', message: 'Not your vendor profile' });
    }
  }

  private rowToItem(row: {
    id: string;
    vendor_id: string;
    vendor_name: string;
    category_slug: string;
    name: string;
    description: string;
    photo_url: string | null;
    total_quantity: number;
    available_quantity: number;
    reserved_quantity: number;
    rental_fee_minor: string;
    deposit_minor: string;
    active: boolean;
  }): RentalCatalogItemView {
    return {
      id: row.id,
      vendorId: row.vendor_id,
      vendorName: row.vendor_name,
      categorySlug: row.category_slug,
      name: row.name,
      description: row.description,
      photoUrl: row.photo_url,
      totalQuantity: row.total_quantity,
      availableQuantity: row.available_quantity,
      reservedQuantity: row.reserved_quantity,
      rentalFeeMinor: Number(row.rental_fee_minor),
      depositMinor: Number(row.deposit_minor),
      active: row.active,
    };
  }

  private rowToBooking(row: {
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
      id: row.id,
      eventId: row.event_id,
      eventTitle: row.event_title,
      vendorId: row.vendor_id,
      vendorName: row.vendor_name,
      catalogItemId: row.catalog_item_id,
      itemName: row.item_name,
      categorySlug: row.category_slug,
      requesterName: row.requester_name,
      quantityRequested: row.quantity_requested,
      quantityApproved: row.quantity_approved,
      counterQuantity: row.counter_quantity,
      status: row.status as RentalBookingStatus,
      rentalFeeMinor: Number(row.rental_fee_minor),
      depositMinor: Number(row.deposit_minor),
      deliveryDate: row.delivery_date?.toISOString().slice(0, 10) ?? null,
      pickupDate: row.pickup_date?.toISOString().slice(0, 10) ?? null,
      deliveryAddress: row.delivery_address,
      damageNotes: row.damage_notes,
      deliveredAt: row.delivered_at?.toISOString() ?? null,
      returnedAt: row.returned_at?.toISOString() ?? null,
      createdAt: row.created_at.toISOString(),
    };
  }

  async listMarketplaceCatalog(tenantId: string, category?: string) {
    const params: unknown[] = [tenantId];
    let filter = '';
    if (category && category !== 'All' && category !== 'Rentals & Event Equipment') {
      params.push(category);
      filter = `AND (i.category_slug = $${params.length} OR i.category_slug ILIKE $${params.length})`;
    }
    const { rows } = await this.pool.query<{
      id: string;
      vendor_id: string;
      vendor_name: string;
      category_slug: string;
      name: string;
      description: string;
      photo_url: string | null;
      total_quantity: number;
      available_quantity: number;
      reserved_quantity: number;
      rental_fee_minor: string;
      deposit_minor: string;
      active: boolean;
    }>(
      `SELECT i.id, i.vendor_id, v.business_name AS vendor_name, i.category_slug, i.name, i.description,
              i.photo_url, i.total_quantity, i.available_quantity, i.reserved_quantity,
              i.rental_fee_minor, i.deposit_minor, i.active
       FROM rental_catalog_items i
       JOIN vendors v ON v.id = i.vendor_id
       WHERE i.tenant_id = $1 AND i.active = true ${filter}
       ORDER BY i.name`,
      params,
    );
    return { items: rows.map((r) => this.rowToItem(r)) };
  }

  async listVendorInventory(actor: CommerceActor, vendorId: string) {
    await this.assertVendorOwns(actor, vendorId);
    const { rows } = await this.pool.query<{
      id: string;
      vendor_id: string;
      vendor_name: string;
      category_slug: string;
      name: string;
      description: string;
      photo_url: string | null;
      total_quantity: number;
      available_quantity: number;
      reserved_quantity: number;
      rental_fee_minor: string;
      deposit_minor: string;
      active: boolean;
    }>(
      `SELECT i.id, i.vendor_id, v.business_name AS vendor_name, i.category_slug, i.name, i.description,
              i.photo_url, i.total_quantity, i.available_quantity, i.reserved_quantity,
              i.rental_fee_minor, i.deposit_minor, i.active
       FROM rental_catalog_items i
       JOIN vendors v ON v.id = i.vendor_id
       WHERE i.tenant_id = $1 AND i.vendor_id = $2::uuid
       ORDER BY i.name`,
      [actor.tenantId, vendorId],
    );
    const blackouts = await this.listBlackouts(actor, vendorId);
    return { items: rows.map((r) => this.rowToItem(r)), blackouts: blackouts.items };
  }

  async createInventoryItem(
    actor: CommerceActor,
    vendorId: string,
    body: Record<string, unknown>,
  ): Promise<RentalCatalogItemView> {
    await this.assertVendorOwns(actor, vendorId);
    const name = String(body.name ?? '').trim();
    if (!name) throw new BadRequestException({ code: 'INVALID_NAME', message: 'Name is required' });
    const total = Math.max(0, Math.floor(Number(body.totalQuantity) || 0));
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO rental_catalog_items
         (tenant_id, vendor_id, category_slug, name, description, photo_url, total_quantity,
          available_quantity, rental_fee_minor, deposit_minor)
       VALUES ($1, $2::uuid, $3, $4, $5, $6, $7, $7, $8, $9)
       RETURNING id`,
      [
        actor.tenantId,
        vendorId,
        String(body.categorySlug ?? 'event-equipment'),
        name,
        String(body.description ?? '').trim(),
        body.photoUrl ? String(body.photoUrl).trim() : null,
        total,
        Math.max(0, Math.floor(Number(body.rentalFeeMinor) || 0)),
        Math.max(0, Math.floor(Number(body.depositMinor) || 0)),
      ],
    );
    const catalog = await this.listVendorInventory(actor, vendorId);
    const item = catalog.items.find((i) => i.id === rows[0]!.id);
    if (!item) throw new NotFoundException({ code: 'ITEM_NOT_FOUND', message: 'Item not found' });
    return item;
  }

  async patchInventoryItem(
    actor: CommerceActor,
    vendorId: string,
    itemId: string,
    body: Record<string, unknown>,
  ): Promise<RentalCatalogItemView> {
    await this.assertVendorOwns(actor, vendorId);
    const sets: string[] = [];
    const vals: unknown[] = [actor.tenantId, vendorId, itemId];
    let idx = 4;
    if (body.name !== undefined) {
      sets.push(`name = $${idx++}`);
      vals.push(String(body.name).trim());
    }
    if (body.description !== undefined) {
      sets.push(`description = $${idx++}`);
      vals.push(String(body.description).trim());
    }
    if (body.photoUrl !== undefined) {
      sets.push(`photo_url = $${idx++}`);
      vals.push(String(body.photoUrl).trim() || null);
    }
    if (body.totalQuantity !== undefined) {
      const total = Math.max(0, Math.floor(Number(body.totalQuantity) || 0));
      sets.push(`total_quantity = $${idx++}`);
      vals.push(total);
      sets.push(`available_quantity = GREATEST($${idx - 1} - reserved_quantity, 0)`);
    }
    if (body.rentalFeeMinor !== undefined) {
      sets.push(`rental_fee_minor = $${idx++}`);
      vals.push(Math.max(0, Math.floor(Number(body.rentalFeeMinor) || 0)));
    }
    if (body.depositMinor !== undefined) {
      sets.push(`deposit_minor = $${idx++}`);
      vals.push(Math.max(0, Math.floor(Number(body.depositMinor) || 0)));
    }
    if (body.active !== undefined) {
      sets.push(`active = $${idx++}`);
      vals.push(Boolean(body.active));
    }
    if (sets.length === 0) {
      throw new BadRequestException({ code: 'NO_CHANGES', message: 'No fields to update' });
    }
    sets.push('updated_at = now()');
    const { rowCount } = await this.pool.query(
      `UPDATE rental_catalog_items SET ${sets.join(', ')}
       WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid`,
      vals,
    );
    if (!rowCount) throw new NotFoundException({ code: 'ITEM_NOT_FOUND', message: 'Item not found' });
    const catalog = await this.listVendorInventory(actor, vendorId);
    const item = catalog.items.find((i) => i.id === itemId);
    if (!item) throw new NotFoundException({ code: 'ITEM_NOT_FOUND', message: 'Item not found' });
    return item;
  }

  async listBlackouts(actor: CommerceActor, vendorId: string) {
    await this.assertVendorOwns(actor, vendorId);
    const { rows } = await this.pool.query<{
      id: string;
      catalog_item_id: string | null;
      blackout_date: Date;
      reason: string | null;
    }>(
      `SELECT id, catalog_item_id, blackout_date, reason
       FROM rental_blackout_dates
       WHERE tenant_id = $1 AND vendor_id = $2::uuid
       ORDER BY blackout_date`,
      [actor.tenantId, vendorId],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        catalogItemId: r.catalog_item_id,
        blackoutDate: r.blackout_date.toISOString().slice(0, 10),
        reason: r.reason,
      })),
    };
  }

  async addBlackout(actor: CommerceActor, vendorId: string, body: Record<string, unknown>) {
    await this.assertVendorOwns(actor, vendorId);
    const date = String(body.blackoutDate ?? '').trim();
    if (!date) throw new BadRequestException({ code: 'INVALID_DATE', message: 'Date required' });
    await this.pool.query(
      `INSERT INTO rental_blackout_dates (tenant_id, vendor_id, catalog_item_id, blackout_date, reason)
       VALUES ($1, $2::uuid, $3::uuid, $4::date, $5)
       ON CONFLICT (vendor_id, catalog_item_id, blackout_date) DO NOTHING`,
      [
        actor.tenantId,
        vendorId,
        body.catalogItemId ? String(body.catalogItemId) : null,
        date,
        body.reason ? String(body.reason) : null,
      ],
    );
    return this.listBlackouts(actor, vendorId);
  }

  async listEventRentals(tenantId: string, eventKey: string, actor?: CommerceActor) {
    const event = actor
      ? await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey)
      : await this.access.resolveEventRow(tenantId, eventKey, true);
    const { rows } = await this.pool.query<{
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
    }>(
      `SELECT b.id, b.event_id, e.title AS event_title, b.vendor_id, v.business_name AS vendor_name,
              b.catalog_item_id, i.name AS item_name, i.category_slug, b.requester_name,
              b.quantity_requested, b.quantity_approved, b.counter_quantity, b.status,
              b.rental_fee_minor, b.deposit_minor, b.delivery_date, b.pickup_date,
              b.delivery_address, b.damage_notes, b.delivered_at, b.returned_at, b.created_at
       FROM rental_bookings b
       JOIN events e ON e.id = b.event_id
       JOIN vendors v ON v.id = b.vendor_id
       JOIN rental_catalog_items i ON i.id = b.catalog_item_id
       WHERE b.tenant_id = $1 AND b.event_id = $2
       ORDER BY b.created_at DESC`,
      [tenantId, event.id],
    );
    return { bookings: rows.map((r) => this.rowToBooking(r)) };
  }

  async listVendorBookings(actor: CommerceActor, vendorId: string) {
    await this.assertVendorOwns(actor, vendorId);
    const { rows } = await this.pool.query<{
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
    }>(
      `SELECT b.id, b.event_id, e.title AS event_title, b.vendor_id, v.business_name AS vendor_name,
              b.catalog_item_id, i.name AS item_name, i.category_slug, b.requester_name,
              b.quantity_requested, b.quantity_approved, b.counter_quantity, b.status,
              b.rental_fee_minor, b.deposit_minor, b.delivery_date, b.pickup_date,
              b.delivery_address, b.damage_notes, b.delivered_at, b.returned_at, b.created_at
       FROM rental_bookings b
       JOIN events e ON e.id = b.event_id
       JOIN vendors v ON v.id = b.vendor_id
       JOIN rental_catalog_items i ON i.id = b.catalog_item_id
       WHERE b.tenant_id = $1 AND b.vendor_id = $2::uuid
       ORDER BY b.delivery_date NULLS LAST, b.created_at DESC`,
      [actor.tenantId, vendorId],
    );
    return { bookings: rows.map((r) => this.rowToBooking(r)) };
  }

  async createBooking(
    tenantId: string,
    eventKey: string,
    body: Record<string, unknown>,
    userId?: string,
  ): Promise<RentalBookingView> {
    const event = await this.access.resolveEventRow(tenantId, eventKey, true);
    const catalogItemId = String(body.catalogItemId ?? '');
    const qty = Math.floor(Number(body.quantityRequested) || 0);
    const requesterName = String(body.requesterName ?? '').trim();
    if (!catalogItemId || qty < 1) {
      throw new BadRequestException({ code: 'INVALID_REQUEST', message: 'Item and quantity required' });
    }
    if (requesterName.length < 2) {
      throw new BadRequestException({ code: 'INVALID_NAME', message: 'Requester name required' });
    }

    const { rows: items } = await this.pool.query<{
      vendor_id: string;
      rental_fee_minor: string;
      deposit_minor: string;
      available_quantity: number;
      name: string;
    }>(
      `SELECT vendor_id, rental_fee_minor, deposit_minor, available_quantity, name
       FROM rental_catalog_items
       WHERE tenant_id = $1 AND id = $2::uuid AND active = true`,
      [tenantId, catalogItemId],
    );
    const item = items[0];
    if (!item) throw new NotFoundException({ code: 'ITEM_NOT_FOUND', message: 'Rental item not found' });
    if (item.available_quantity < qty) {
      throw new UnprocessableEntityException({ code: 'INSUFFICIENT_STOCK', message: 'Not enough available units' });
    }

    const deliveryDate = body.deliveryDate ? String(body.deliveryDate) : null;
    const pickupDate = body.pickupDate ? String(body.pickupDate) : null;
    if (deliveryDate) {
      const { rows: blocked } = await this.pool.query(
        `SELECT 1 FROM rental_blackout_dates
         WHERE tenant_id = $1 AND vendor_id = $2::uuid
           AND blackout_date = $3::date
           AND (catalog_item_id IS NULL OR catalog_item_id = $4::uuid)
         LIMIT 1`,
        [tenantId, item.vendor_id, deliveryDate, catalogItemId],
      );
      if (blocked.length) {
        throw new UnprocessableEntityException({ code: 'BLACKOUT_DATE', message: 'Delivery date unavailable' });
      }
    }

    const rentalFee = Number(item.rental_fee_minor) * qty;
    const deposit = Number(item.deposit_minor) * qty;

    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO rental_bookings
         (tenant_id, event_id, vendor_id, catalog_item_id, requester_name, requester_user_id,
          quantity_requested, rental_fee_minor, deposit_minor, delivery_date, pickup_date, delivery_address)
       VALUES ($1, $2, $3::uuid, $4::uuid, $5, $6::uuid, $7, $8, $9, $10::date, $11::date, $12)
       RETURNING id`,
      [
        tenantId,
        event.id,
        item.vendor_id,
        catalogItemId,
        requesterName,
        userId ?? null,
        qty,
        rentalFee,
        deposit,
        deliveryDate,
        pickupDate,
        body.deliveryAddress ? String(body.deliveryAddress) : null,
      ],
    );

    const listed = await this.listEventRentals(tenantId, eventKey);
    const booking = listed.bookings.find((b) => b.id === rows[0]!.id);
    if (!booking) throw new NotFoundException({ code: 'BOOKING_NOT_FOUND', message: 'Booking not found' });
    return booking;
  }

  private async loadBookingForVendor(
    client: PoolClient,
    tenantId: string,
    vendorId: string,
    bookingId: string,
  ) {
    const { rows } = await client.query<{
      id: string;
      catalog_item_id: string;
      quantity_requested: number;
      status: string;
    }>(
      `SELECT id, catalog_item_id, quantity_requested, status
       FROM rental_bookings
       WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid
       FOR UPDATE`,
      [tenantId, vendorId, bookingId],
    );
    return rows[0];
  }

  private async reserveInventory(client: PoolClient, itemId: string, qty: number) {
    const { rowCount } = await client.query(
      `UPDATE rental_catalog_items
       SET available_quantity = available_quantity - $2,
           reserved_quantity = reserved_quantity + $2,
           updated_at = now()
       WHERE id = $1::uuid AND available_quantity >= $2`,
      [itemId, qty],
    );
    if (!rowCount) throw new UnprocessableEntityException({ code: 'INSUFFICIENT_STOCK', message: 'Stock changed' });
  }

  private async releaseInventory(client: PoolClient, itemId: string, qty: number) {
    await client.query(
      `UPDATE rental_catalog_items
       SET available_quantity = available_quantity + $2,
           reserved_quantity = GREATEST(reserved_quantity - $2, 0),
           updated_at = now()
       WHERE id = $1::uuid`,
      [itemId, qty],
    );
  }

  async approveBooking(actor: CommerceActor, vendorId: string, bookingId: string, quantity?: number) {
    await this.assertVendorOwns(actor, vendorId);
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const booking = await this.loadBookingForVendor(client, actor.tenantId, vendorId, bookingId);
      if (!booking || !['pending', 'countered'].includes(booking.status)) {
        throw new UnprocessableEntityException({ code: 'INVALID_STATE', message: 'Cannot approve booking' });
      }
      const qty = quantity ?? booking.quantity_requested;
      await this.reserveInventory(client, booking.catalog_item_id, qty);
      await client.query(
        `UPDATE rental_bookings
         SET status = 'approved', quantity_approved = $4, updated_at = now()
         WHERE id = $3::uuid AND tenant_id = $1 AND vendor_id = $2::uuid`,
        [actor.tenantId, vendorId, bookingId, qty],
      );
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
    const list = await this.listVendorBookings(actor, vendorId);
    return list.bookings.find((b) => b.id === bookingId)!;
  }

  async counterBooking(actor: CommerceActor, vendorId: string, bookingId: string, counterQuantity: number) {
    await this.assertVendorOwns(actor, vendorId);
    if (counterQuantity < 1) {
      throw new BadRequestException({ code: 'INVALID_QTY', message: 'Counter quantity required' });
    }
    await this.pool.query(
      `UPDATE rental_bookings
       SET status = 'countered', counter_quantity = $4, updated_at = now()
       WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid AND status = 'pending'`,
      [actor.tenantId, vendorId, bookingId, counterQuantity],
    );
    const list = await this.listVendorBookings(actor, vendorId);
    const booking = list.bookings.find((b) => b.id === bookingId);
    if (!booking) throw new NotFoundException({ code: 'BOOKING_NOT_FOUND', message: 'Booking not found' });
    return booking;
  }

  async declineBooking(actor: CommerceActor, vendorId: string, bookingId: string) {
    await this.assertVendorOwns(actor, vendorId);
    await this.pool.query(
      `UPDATE rental_bookings SET status = 'declined', updated_at = now()
       WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid AND status IN ('pending', 'countered')`,
      [actor.tenantId, vendorId, bookingId],
    );
    const list = await this.listVendorBookings(actor, vendorId);
    const booking = list.bookings.find((b) => b.id === bookingId);
    if (!booking) throw new NotFoundException({ code: 'BOOKING_NOT_FOUND', message: 'Booking not found' });
    return booking;
  }

  async markDelivered(actor: CommerceActor, vendorId: string, bookingId: string) {
    await this.assertVendorOwns(actor, vendorId);
    await this.pool.query(
      `UPDATE rental_bookings SET status = 'delivered', delivered_at = now(), updated_at = now()
       WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid AND status = 'approved'`,
      [actor.tenantId, vendorId, bookingId],
    );
    const list = await this.listVendorBookings(actor, vendorId);
    return list.bookings.find((b) => b.id === bookingId)!;
  }

  async markReturned(
    actor: CommerceActor,
    vendorId: string,
    bookingId: string,
    damageNotes?: string,
  ) {
    await this.assertVendorOwns(actor, vendorId);
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query<{
        catalog_item_id: string;
        quantity_approved: number | null;
        quantity_requested: number;
      }>(
        `SELECT catalog_item_id, quantity_approved, quantity_requested
         FROM rental_bookings
         WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid AND status = 'delivered'
         FOR UPDATE`,
        [actor.tenantId, vendorId, bookingId],
      );
      const booking = rows[0];
      if (!booking) throw new NotFoundException({ code: 'BOOKING_NOT_FOUND', message: 'Booking not found' });
      const qty = booking.quantity_approved ?? booking.quantity_requested;
      await client.query(
        `UPDATE rental_catalog_items
         SET reserved_quantity = GREATEST(reserved_quantity - $2, 0),
             available_quantity = available_quantity + $2,
             updated_at = now()
         WHERE id = $1::uuid`,
        [booking.catalog_item_id, qty],
      );
      await client.query(
        `UPDATE rental_bookings
         SET status = 'returned', returned_at = now(), damage_notes = $4, updated_at = now()
         WHERE tenant_id = $1 AND vendor_id = $2::uuid AND id = $3::uuid`,
        [actor.tenantId, vendorId, bookingId, damageNotes ?? null],
      );
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
    const list = await this.listVendorBookings(actor, vendorId);
    return list.bookings.find((b) => b.id === bookingId)!;
  }

  async getItemAvailability(tenantId: string, itemId: string, from: string, to: string) {
    const { rows: itemRows } = await this.pool.query<{ vendor_id: string; available_quantity: number }>(
      `SELECT vendor_id, available_quantity FROM rental_catalog_items
       WHERE tenant_id = $1 AND id = $2::uuid AND active = true`,
      [tenantId, itemId],
    );
    const item = itemRows[0];
    if (!item) throw new NotFoundException({ code: 'ITEM_NOT_FOUND', message: 'Item not found' });

    const { rows: blackouts } = await this.pool.query<{ blackout_date: Date }>(
      `SELECT blackout_date FROM rental_blackout_dates
       WHERE tenant_id = $1 AND vendor_id = $2::uuid
         AND blackout_date BETWEEN $3::date AND $4::date
         AND (catalog_item_id IS NULL OR catalog_item_id = $5::uuid)`,
      [tenantId, item.vendor_id, from, to, itemId],
    );

    const { rows: bookings } = await this.pool.query<{
      delivery_date: Date;
      quantity_approved: number | null;
      quantity_requested: number;
    }>(
      `SELECT delivery_date, quantity_approved, quantity_requested
       FROM rental_bookings
       WHERE tenant_id = $1 AND catalog_item_id = $2::uuid
         AND delivery_date BETWEEN $3::date AND $4::date
         AND status IN ('approved', 'delivered')`,
      [tenantId, itemId, from, to],
    );

    return {
      availableQuantity: item.available_quantity,
      blackoutDates: blackouts.map((b) => b.blackout_date.toISOString().slice(0, 10)),
      reservedByDate: bookings.map((b) => ({
        date: b.delivery_date.toISOString().slice(0, 10),
        quantity: b.quantity_approved ?? b.quantity_requested,
      })),
    };
  }
}
