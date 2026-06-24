import {
  BadRequestException,
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool, PoolClient } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';

export const ASO_EBI_PACKAGE_TYPES = ['fabric_only', 'fabric_cap', 'premium'] as const;
export type AsoEbiPackageType = (typeof ASO_EBI_PACKAGE_TYPES)[number];

export type AsoEbiPackageView = {
  packageType: AsoEbiPackageType;
  priceMinor: number;
};

export type AsoEbiInventoryView = {
  packageType: AsoEbiPackageType;
  size: string;
  available: number;
  reserved: number;
  collected: number;
};

export type AsoEbiFabricView = {
  id: string;
  name: string;
  photoUrl: string | null;
  description: string;
  active: boolean;
  sortOrder: number;
  packages: AsoEbiPackageView[];
  inventory: AsoEbiInventoryView[];
};

export type AsoEbiReservationView = {
  id: string;
  fabricId: string;
  fabricName: string;
  packageType: AsoEbiPackageType;
  size: string;
  guestName: string;
  guestEmail: string | null;
  priceMinor: number;
  paymentStatus: 'pending' | 'paid';
  fulfillmentStatus: 'reserved' | 'collected' | 'cancelled';
  reservedAt: string;
  paidAt: string | null;
  collectedAt: string | null;
};

export type AsoEbiDashboardView = {
  totalSales: number;
  revenueMinor: number;
  outstandingPickup: number;
  pendingPayment: number;
};

@Injectable()
export class AsoEbiService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  private assertPackageType(raw: string): AsoEbiPackageType {
    if (!ASO_EBI_PACKAGE_TYPES.includes(raw as AsoEbiPackageType)) {
      throw new BadRequestException({ code: 'INVALID_PACKAGE', message: 'Unknown package type' });
    }
    return raw as AsoEbiPackageType;
  }

  private async loadPackages(tenantId: string, eventId: string, fabricIds: string[]) {
    if (fabricIds.length === 0) return new Map<string, AsoEbiPackageView[]>();
    const { rows } = await this.pool.query<{
      fabric_id: string;
      package_type: string;
      price_minor: string;
    }>(
      `SELECT fabric_id, package_type, price_minor
       FROM event_aso_ebi_packages
       WHERE tenant_id = $1 AND event_id = $2 AND fabric_id = ANY($3::uuid[])
       ORDER BY package_type`,
      [tenantId, eventId, fabricIds],
    );
    const map = new Map<string, AsoEbiPackageView[]>();
    for (const r of rows) {
      const list = map.get(r.fabric_id) ?? [];
      list.push({
        packageType: r.package_type as AsoEbiPackageType,
        priceMinor: Number(r.price_minor),
      });
      map.set(r.fabric_id, list);
    }
    return map;
  }

  private async loadInventory(tenantId: string, eventId: string, fabricIds: string[]) {
    if (fabricIds.length === 0) return new Map<string, AsoEbiInventoryView[]>();
    const { rows } = await this.pool.query<{
      fabric_id: string;
      package_type: string;
      size: string;
      quantity_available: number;
      quantity_reserved: number;
      quantity_collected: number;
    }>(
      `SELECT fabric_id, package_type, size, quantity_available, quantity_reserved, quantity_collected
       FROM event_aso_ebi_inventory
       WHERE tenant_id = $1 AND event_id = $2 AND fabric_id = ANY($3::uuid[])
       ORDER BY package_type, size`,
      [tenantId, eventId, fabricIds],
    );
    const map = new Map<string, AsoEbiInventoryView[]>();
    for (const r of rows) {
      const list = map.get(r.fabric_id) ?? [];
      list.push({
        packageType: r.package_type as AsoEbiPackageType,
        size: r.size,
        available: r.quantity_available,
        reserved: r.quantity_reserved,
        collected: r.quantity_collected,
      });
      map.set(r.fabric_id, list);
    }
    return map;
  }

  private async fabricsForEvent(
    tenantId: string,
    eventId: string,
    activeOnly: boolean,
  ): Promise<AsoEbiFabricView[]> {
    const { rows } = await this.pool.query<{
      id: string;
      name: string;
      photo_url: string | null;
      description: string;
      active: boolean;
      sort_order: number;
    }>(
      `SELECT id, name, photo_url, description, active, sort_order
       FROM event_aso_ebi_fabrics
       WHERE tenant_id = $1 AND event_id = $2 ${activeOnly ? 'AND active = true' : ''}
       ORDER BY sort_order, created_at`,
      [tenantId, eventId],
    );
    const ids = rows.map((r) => r.id);
    const packages = await this.loadPackages(tenantId, eventId, ids);
    const inventory = await this.loadInventory(tenantId, eventId, ids);
    return rows.map((r) => ({
      id: r.id,
      name: r.name,
      photoUrl: r.photo_url,
      description: r.description,
      active: r.active,
      sortOrder: r.sort_order,
      packages: packages.get(r.id) ?? [],
      inventory: inventory.get(r.id) ?? [],
    }));
  }

  private async dashboard(tenantId: string, eventId: string): Promise<AsoEbiDashboardView> {
    const { rows } = await this.pool.query<{
      total_sales: string;
      revenue_minor: string;
      outstanding_pickup: string;
      pending_payment: string;
    }>(
      `SELECT
         COUNT(*) FILTER (WHERE fulfillment_status <> 'cancelled')::text AS total_sales,
         COALESCE(SUM(price_minor) FILTER (WHERE payment_status = 'paid' AND fulfillment_status <> 'cancelled'), 0)::text AS revenue_minor,
         COUNT(*) FILTER (WHERE payment_status = 'paid' AND fulfillment_status = 'reserved')::text AS outstanding_pickup,
         COUNT(*) FILTER (WHERE payment_status = 'pending' AND fulfillment_status = 'reserved')::text AS pending_payment
       FROM event_aso_ebi_reservations
       WHERE tenant_id = $1 AND event_id = $2`,
      [tenantId, eventId],
    );
    const r = rows[0]!;
    return {
      totalSales: Number(r.total_sales),
      revenueMinor: Number(r.revenue_minor),
      outstandingPickup: Number(r.outstanding_pickup),
      pendingPayment: Number(r.pending_payment),
    };
  }

  private async listReservations(tenantId: string, eventId: string): Promise<AsoEbiReservationView[]> {
    const { rows } = await this.pool.query<{
      id: string;
      fabric_id: string;
      fabric_name: string;
      package_type: string;
      size: string;
      guest_name: string;
      guest_email: string | null;
      price_minor: string;
      payment_status: string;
      fulfillment_status: string;
      reserved_at: Date;
      paid_at: Date | null;
      collected_at: Date | null;
    }>(
      `SELECT r.id, r.fabric_id, f.name AS fabric_name, r.package_type, r.size,
              r.guest_name, r.guest_email, r.price_minor, r.payment_status, r.fulfillment_status,
              r.reserved_at, r.paid_at, r.collected_at
       FROM event_aso_ebi_reservations r
       JOIN event_aso_ebi_fabrics f ON f.id = r.fabric_id
       WHERE r.tenant_id = $1 AND r.event_id = $2
       ORDER BY r.reserved_at DESC
       LIMIT 300`,
      [tenantId, eventId],
    );
    return rows.map((r) => ({
      id: r.id,
      fabricId: r.fabric_id,
      fabricName: r.fabric_name,
      packageType: r.package_type as AsoEbiPackageType,
      size: r.size,
      guestName: r.guest_name,
      guestEmail: r.guest_email,
      priceMinor: Number(r.price_minor),
      paymentStatus: r.payment_status as AsoEbiReservationView['paymentStatus'],
      fulfillmentStatus: r.fulfillment_status as AsoEbiReservationView['fulfillmentStatus'],
      reservedAt: r.reserved_at.toISOString(),
      paidAt: r.paid_at?.toISOString() ?? null,
      collectedAt: r.collected_at?.toISOString() ?? null,
    }));
  }

  async listPublic(tenantId: string, eventKey: string) {
    const event = await this.access.resolveEventRow(tenantId, eventKey, true);
    const fabrics = await this.fabricsForEvent(tenantId, event.id, true);
    return { fabrics };
  }

  async listForOrganizer(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const fabrics = await this.fabricsForEvent(actor.tenantId, event.id, false);
    const dashboard = await this.dashboard(actor.tenantId, event.id);
    const reservations = await this.listReservations(actor.tenantId, event.id);
    return { dashboard, fabrics, reservations };
  }

  async createFabric(
    actor: CommerceActor,
    eventKey: string,
    body: { name?: string; photoUrl?: string; description?: string },
  ): Promise<AsoEbiFabricView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const name = String(body.name ?? 'Aso-Ebi fabric').trim() || 'Aso-Ebi fabric';
    const description = String(body.description ?? '').trim();
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO event_aso_ebi_fabrics (tenant_id, event_id, name, photo_url, description)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [actor.tenantId, event.id, name, body.photoUrl?.trim() || null, description],
    );
    const fabricId = rows[0]!.id;
    for (const packageType of ASO_EBI_PACKAGE_TYPES) {
      await this.pool.query(
        `INSERT INTO event_aso_ebi_packages (tenant_id, event_id, fabric_id, package_type, price_minor)
         VALUES ($1, $2, $3, $4, 0)`,
        [actor.tenantId, event.id, fabricId, packageType],
      );
    }
    const fabrics = await this.fabricsForEvent(actor.tenantId, event.id, false);
    const fabric = fabrics.find((f) => f.id === fabricId);
    if (!fabric) throw new NotFoundException({ code: 'FABRIC_NOT_FOUND', message: 'Fabric not found' });
    return fabric;
  }

  async patchFabric(
    actor: CommerceActor,
    eventKey: string,
    fabricId: string,
    body: Record<string, unknown>,
  ): Promise<AsoEbiFabricView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const sets: string[] = [];
    const vals: unknown[] = [actor.tenantId, event.id, fabricId];
    let idx = 4;
    if (body.name !== undefined) {
      sets.push(`name = $${idx++}`);
      vals.push(String(body.name).trim());
    }
    if (body.photoUrl !== undefined) {
      sets.push(`photo_url = $${idx++}`);
      vals.push(String(body.photoUrl).trim() || null);
    }
    if (body.description !== undefined) {
      sets.push(`description = $${idx++}`);
      vals.push(String(body.description).trim());
    }
    if (body.active !== undefined) {
      sets.push(`active = $${idx++}`);
      vals.push(Boolean(body.active));
    }
    if (body.sortOrder !== undefined) {
      sets.push(`sort_order = $${idx++}`);
      vals.push(Number(body.sortOrder));
    }
    if (sets.length === 0) {
      throw new BadRequestException({ code: 'NO_CHANGES', message: 'No fields to update' });
    }
    sets.push('updated_at = now()');
    const { rowCount } = await this.pool.query(
      `UPDATE event_aso_ebi_fabrics SET ${sets.join(', ')}
       WHERE tenant_id = $1 AND event_id = $2 AND id = $3::uuid`,
      vals,
    );
    if (!rowCount) {
      throw new NotFoundException({ code: 'FABRIC_NOT_FOUND', message: 'Fabric not found' });
    }
    const fabrics = await this.fabricsForEvent(actor.tenantId, event.id, false);
    const fabric = fabrics.find((f) => f.id === fabricId);
    if (!fabric) throw new NotFoundException({ code: 'FABRIC_NOT_FOUND', message: 'Fabric not found' });
    return fabric;
  }

  async upsertPackages(
    actor: CommerceActor,
    eventKey: string,
    fabricId: string,
    packages: Array<{ packageType: string; priceMinor: number }>,
  ): Promise<AsoEbiFabricView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    for (const p of packages) {
      const packageType = this.assertPackageType(p.packageType);
      const priceMinor = Math.max(0, Math.floor(Number(p.priceMinor) || 0));
      await this.pool.query(
        `INSERT INTO event_aso_ebi_packages (tenant_id, event_id, fabric_id, package_type, price_minor)
         VALUES ($1, $2, $3::uuid, $4, $5)
         ON CONFLICT (fabric_id, package_type)
         DO UPDATE SET price_minor = EXCLUDED.price_minor, updated_at = now()`,
        [actor.tenantId, event.id, fabricId, packageType, priceMinor],
      );
    }
    const fabrics = await this.fabricsForEvent(actor.tenantId, event.id, false);
    const fabric = fabrics.find((f) => f.id === fabricId);
    if (!fabric) throw new NotFoundException({ code: 'FABRIC_NOT_FOUND', message: 'Fabric not found' });
    return fabric;
  }

  async upsertInventory(
    actor: CommerceActor,
    eventKey: string,
    fabricId: string,
    items: Array<{ packageType: string; size: string; available: number }>,
  ): Promise<AsoEbiFabricView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    for (const item of items) {
      const packageType = this.assertPackageType(item.packageType);
      const size = String(item.size ?? '').trim().toUpperCase();
      if (!size) {
        throw new BadRequestException({ code: 'INVALID_SIZE', message: 'Size is required' });
      }
      const available = Math.max(0, Math.floor(Number(item.available) || 0));
      await this.pool.query(
        `INSERT INTO event_aso_ebi_inventory
           (tenant_id, event_id, fabric_id, package_type, size, quantity_available)
         VALUES ($1, $2, $3::uuid, $4, $5, $6)
         ON CONFLICT (fabric_id, package_type, size)
         DO UPDATE SET quantity_available = EXCLUDED.quantity_available, updated_at = now()`,
        [actor.tenantId, event.id, fabricId, packageType, size, available],
      );
    }
    const fabrics = await this.fabricsForEvent(actor.tenantId, event.id, false);
    const fabric = fabrics.find((f) => f.id === fabricId);
    if (!fabric) throw new NotFoundException({ code: 'FABRIC_NOT_FOUND', message: 'Fabric not found' });
    return fabric;
  }

  private async reserveWithClient(
    client: PoolClient,
    tenantId: string,
    eventId: string,
    body: {
      fabricId: string;
      packageType: AsoEbiPackageType;
      size: string;
      guestName: string;
      guestEmail?: string;
      userId?: string;
    },
  ): Promise<AsoEbiReservationView> {
    const size = body.size.trim().toUpperCase();
    const guestName = body.guestName.trim();
    if (guestName.length < 2) {
      throw new BadRequestException({ code: 'INVALID_GUEST', message: 'Guest name is required' });
    }

    const { rows: pkgRows } = await client.query<{ price_minor: string }>(
      `SELECT price_minor FROM event_aso_ebi_packages
       WHERE tenant_id = $1 AND event_id = $2 AND fabric_id = $3::uuid AND package_type = $4`,
      [tenantId, eventId, body.fabricId, body.packageType],
    );
    const pkg = pkgRows[0];
    if (!pkg) {
      throw new NotFoundException({ code: 'PACKAGE_NOT_FOUND', message: 'Package not found' });
    }

    const { rows: invRows } = await client.query<{
      id: string;
      quantity_available: number;
    }>(
      `SELECT id, quantity_available FROM event_aso_ebi_inventory
       WHERE tenant_id = $1 AND event_id = $2 AND fabric_id = $3::uuid
         AND package_type = $4 AND size = $5
       FOR UPDATE`,
      [tenantId, eventId, body.fabricId, body.packageType, size],
    );
    const inv = invRows[0];
    if (!inv || inv.quantity_available < 1) {
      throw new UnprocessableEntityException({ code: 'OUT_OF_STOCK', message: 'Size not available' });
    }

    await client.query(
      `UPDATE event_aso_ebi_inventory
       SET quantity_available = quantity_available - 1,
           quantity_reserved = quantity_reserved + 1,
           updated_at = now()
       WHERE id = $1`,
      [inv.id],
    );

    const priceMinor = Number(pkg.price_minor);
    const { rows: fabricRows } = await client.query<{ name: string }>(
      `SELECT name FROM event_aso_ebi_fabrics WHERE id = $1::uuid AND tenant_id = $2`,
      [body.fabricId, tenantId],
    );
    const fabricName = fabricRows[0]?.name ?? 'Aso-Ebi';

    const { rows } = await client.query<{
      id: string;
      reserved_at: Date;
    }>(
      `INSERT INTO event_aso_ebi_reservations
         (tenant_id, event_id, fabric_id, package_type, size, guest_name, guest_email, user_id, price_minor)
       VALUES ($1, $2, $3::uuid, $4, $5, $6, $7, $8::uuid, $9)
       RETURNING id, reserved_at`,
      [
        tenantId,
        eventId,
        body.fabricId,
        body.packageType,
        size,
        guestName,
        body.guestEmail?.trim() || null,
        body.userId ?? null,
        priceMinor,
      ],
    );

    const row = rows[0]!;
    return {
      id: row.id,
      fabricId: body.fabricId,
      fabricName,
      packageType: body.packageType,
      size,
      guestName,
      guestEmail: body.guestEmail?.trim() || null,
      priceMinor,
      paymentStatus: 'pending',
      fulfillmentStatus: 'reserved',
      reservedAt: row.reserved_at.toISOString(),
      paidAt: null,
      collectedAt: null,
    };
  }

  async createReservation(
    tenantId: string,
    eventKey: string,
    body: {
      fabricId?: string;
      packageType?: string;
      size?: string;
      guestName?: string;
      guestEmail?: string;
    },
    userId?: string,
  ): Promise<AsoEbiReservationView> {
    const event = await this.access.resolveEventRow(tenantId, eventKey, true);
    const fabricId = String(body.fabricId ?? '');
    const packageType = this.assertPackageType(String(body.packageType ?? ''));
    const size = String(body.size ?? '').trim();
    if (!fabricId) {
      throw new BadRequestException({ code: 'INVALID_FABRIC', message: 'Fabric is required' });
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const reservation = await this.reserveWithClient(client, tenantId, event.id, {
        fabricId,
        packageType,
        size,
        guestName: String(body.guestName ?? ''),
        guestEmail: body.guestEmail,
        userId,
      });
      await client.query('COMMIT');
      return reservation;
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  async markPaid(
    tenantId: string,
    eventKey: string,
    reservationId: string,
  ): Promise<AsoEbiReservationView> {
    const event = await this.access.resolveEventRow(tenantId, eventKey, true);
    const { rows } = await this.pool.query<{
      id: string;
      fabric_id: string;
      fabric_name: string;
      package_type: string;
      size: string;
      guest_name: string;
      guest_email: string | null;
      price_minor: string;
      payment_status: string;
      fulfillment_status: string;
      reserved_at: Date;
      paid_at: Date | null;
      collected_at: Date | null;
    }>(
      `UPDATE event_aso_ebi_reservations r
       SET payment_status = 'paid', paid_at = now(), updated_at = now()
       FROM event_aso_ebi_fabrics f
       WHERE r.id = $3::uuid AND r.tenant_id = $1 AND r.event_id = $2
         AND f.id = r.fabric_id
         AND r.payment_status = 'pending' AND r.fulfillment_status = 'reserved'
       RETURNING r.id, r.fabric_id, f.name AS fabric_name, r.package_type, r.size,
                 r.guest_name, r.guest_email, r.price_minor, r.payment_status, r.fulfillment_status,
                 r.reserved_at, r.paid_at, r.collected_at`,
      [tenantId, event.id, reservationId],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'RESERVATION_NOT_FOUND', message: 'Reservation not found or already paid' });
    }
    return {
      id: row.id,
      fabricId: row.fabric_id,
      fabricName: row.fabric_name,
      packageType: row.package_type as AsoEbiPackageType,
      size: row.size,
      guestName: row.guest_name,
      guestEmail: row.guest_email,
      priceMinor: Number(row.price_minor),
      paymentStatus: 'paid',
      fulfillmentStatus: row.fulfillment_status as AsoEbiReservationView['fulfillmentStatus'],
      reservedAt: row.reserved_at.toISOString(),
      paidAt: row.paid_at?.toISOString() ?? null,
      collectedAt: row.collected_at?.toISOString() ?? null,
    };
  }

  async markCollected(actor: CommerceActor, eventKey: string, reservationId: string): Promise<AsoEbiReservationView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query<{
        id: string;
        fabric_id: string;
        package_type: string;
        size: string;
        guest_name: string;
        guest_email: string | null;
        price_minor: string;
        payment_status: string;
        fulfillment_status: string;
        reserved_at: Date;
        paid_at: Date | null;
        collected_at: Date | null;
        fabric_name: string;
      }>(
        `SELECT r.id, r.fabric_id, r.package_type, r.size, r.guest_name, r.guest_email,
                r.price_minor, r.payment_status, r.fulfillment_status,
                r.reserved_at, r.paid_at, r.collected_at, f.name AS fabric_name
         FROM event_aso_ebi_reservations r
         JOIN event_aso_ebi_fabrics f ON f.id = r.fabric_id
         WHERE r.id = $3::uuid AND r.tenant_id = $1 AND r.event_id = $2
           AND r.fulfillment_status = 'reserved'
         FOR UPDATE OF r`,
        [actor.tenantId, event.id, reservationId],
      );
      const row = rows[0];
      if (!row) {
        throw new NotFoundException({ code: 'RESERVATION_NOT_FOUND', message: 'Reservation not found' });
      }

      await client.query(
        `UPDATE event_aso_ebi_inventory
         SET quantity_reserved = GREATEST(quantity_reserved - 1, 0),
             quantity_collected = quantity_collected + 1,
             updated_at = now()
         WHERE tenant_id = $1 AND event_id = $2 AND fabric_id = $3::uuid
           AND package_type = $4 AND size = $5`,
        [actor.tenantId, event.id, row.fabric_id, row.package_type, row.size],
      );

      const { rows: updated } = await client.query<{
        paid_at: Date | null;
        collected_at: Date;
      }>(
        `UPDATE event_aso_ebi_reservations
         SET fulfillment_status = 'collected', collected_at = now(), updated_at = now()
         WHERE id = $1
         RETURNING paid_at, collected_at`,
        [reservationId],
      );

      await client.query('COMMIT');
      const u = updated[0]!;
      return {
        id: row.id,
        fabricId: row.fabric_id,
        fabricName: row.fabric_name,
        packageType: row.package_type as AsoEbiPackageType,
        size: row.size,
        guestName: row.guest_name,
        guestEmail: row.guest_email,
        priceMinor: Number(row.price_minor),
        paymentStatus: row.payment_status as AsoEbiReservationView['paymentStatus'],
        fulfillmentStatus: 'collected',
        reservedAt: row.reserved_at.toISOString(),
        paidAt: u.paid_at?.toISOString() ?? row.paid_at?.toISOString() ?? null,
        collectedAt: u.collected_at.toISOString(),
      };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  async cancelReservation(
    tenantId: string,
    eventKey: string,
    reservationId: string,
    actor?: CommerceActor,
  ): Promise<AsoEbiReservationView> {
    const event = actor
      ? await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey)
      : await this.access.resolveEventRow(tenantId, eventKey, true);
    const tid = actor?.tenantId ?? tenantId;

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query<{
        id: string;
        fabric_id: string;
        package_type: string;
        size: string;
        guest_name: string;
        guest_email: string | null;
        price_minor: string;
        payment_status: string;
        fulfillment_status: string;
        reserved_at: Date;
        paid_at: Date | null;
        collected_at: Date | null;
        fabric_name: string;
      }>(
        `SELECT r.id, r.fabric_id, r.package_type, r.size, r.guest_name, r.guest_email,
                r.price_minor, r.payment_status, r.fulfillment_status,
                r.reserved_at, r.paid_at, r.collected_at, f.name AS fabric_name
         FROM event_aso_ebi_reservations r
         JOIN event_aso_ebi_fabrics f ON f.id = r.fabric_id
         WHERE r.id = $3::uuid AND r.tenant_id = $1 AND r.event_id = $2
           AND r.fulfillment_status = 'reserved'
         FOR UPDATE OF r`,
        [tid, event.id, reservationId],
      );
      const row = rows[0];
      if (!row) {
        throw new NotFoundException({ code: 'RESERVATION_NOT_FOUND', message: 'Reservation not found' });
      }

      await client.query(
        `UPDATE event_aso_ebi_inventory
         SET quantity_available = quantity_available + 1,
             quantity_reserved = GREATEST(quantity_reserved - 1, 0),
             updated_at = now()
         WHERE tenant_id = $1 AND event_id = $2 AND fabric_id = $3::uuid
           AND package_type = $4 AND size = $5`,
        [tid, event.id, row.fabric_id, row.package_type, row.size],
      );

      await client.query(
        `UPDATE event_aso_ebi_reservations
         SET fulfillment_status = 'cancelled', updated_at = now()
         WHERE id = $1`,
        [reservationId],
      );

      await client.query('COMMIT');
      return {
        id: row.id,
        fabricId: row.fabric_id,
        fabricName: row.fabric_name,
        packageType: row.package_type as AsoEbiPackageType,
        size: row.size,
        guestName: row.guest_name,
        guestEmail: row.guest_email,
        priceMinor: Number(row.price_minor),
        paymentStatus: row.payment_status as AsoEbiReservationView['paymentStatus'],
        fulfillmentStatus: 'cancelled',
        reservedAt: row.reserved_at.toISOString(),
        paidAt: row.paid_at?.toISOString() ?? null,
        collectedAt: row.collected_at?.toISOString() ?? null,
      };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }
}
