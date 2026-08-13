import { Injectable, Inject, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';
import { EventsService } from './events.service';
import { parseTierMeta } from '../commerce/ticket-tier-rules';
import { isPublicEventPageAllowed } from '../commerce/event-visibility-rules';

@Injectable()
export class EventTiersService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly events: EventsService,
  ) {}

  async list(
    actor: CommerceActor | null,
    tenantId: string,
    eventKey: string,
    opts?: { publicStorefront?: boolean },
  ) {
    const publicStorefront = opts?.publicStorefront === true;
    if (actor && !publicStorefront) {
      try {
        const event = await this.access.assertOrganizerOwnsEvent(tenantId, actor.userId, eventKey);
        return {
          items: await this.events.loadTiersForEvent(tenantId, event.id, { includeArchived: true }),
        };
      } catch {
        // public fallback for marketplace
      }
    }
    const event = await this.access.resolveEventRow(tenantId, eventKey, !actor || publicStorefront);
    if (
      publicStorefront &&
      !isPublicEventPageAllowed({
        status: event.status,
        metadata: event.metadata as Record<string, unknown>,
      })
    ) {
      throw new NotFoundException({ code: 'EVENT_NOT_FOUND', message: 'Event not found' });
    }
    const items = await this.events.loadTiersForEvent(tenantId, event.id, {
      includeArchived: false,
      publicStorefront: true,
    });
    return { items };
  }

  async create(actor: CommerceActor, eventKey: string, body: Record<string, unknown>) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const externalId = String(body.id ?? body.externalTierId ?? `tier_${Date.now()}`);
    const unlimited = body.unlimitedCapacity === true;
    let capacity = Number(body.capacity ?? (unlimited ? 0 : 0));
    if (unlimited) {
      capacity = Math.max(capacity, 0);
    }
    if (capacity < 0) {
      throw new UnprocessableEntityException({ code: 'INVALID_CAPACITY', message: 'Invalid capacity' });
    }
    const remaining = unlimited
      ? capacity
      : body.remaining != null
        ? Number(body.remaining)
        : capacity;
    const meta = this.buildMeta(body, {});
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO event_ticket_tiers (
         tenant_id, event_id, external_tier_id, name, description, tier_type,
         price_minor, currency, capacity, remaining, sales_paused, metadata
       ) VALUES ($1, $2, $3, $4, $5, $6, $7::bigint, $8, $9, $10, $11, $12::jsonb)
       RETURNING id`,
      [
        actor.tenantId,
        event.id,
        externalId,
        String(body.name ?? 'Ticket'),
        String(body.description ?? ''),
        String(body.tierType ?? 'regular'),
        String(body.priceMinor ?? '0'),
        String(body.currency ?? 'NGN'),
        capacity,
        remaining,
        body.salesPaused === true,
        JSON.stringify(meta),
      ],
    );
    return { id: rows[0]!.id, externalTierId: externalId };
  }

  async patch(actor: CommerceActor, tierId: string, body: Record<string, unknown>) {
    const row = await this.getTier(actor.tenantId, tierId);
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    const meta = this.buildMeta(body, row.metadata);
    const unlimited = meta.unlimitedCapacity === true;
    await this.pool.query(
      `UPDATE event_ticket_tiers
       SET name = COALESCE($3, name),
           description = COALESCE($4, description),
           tier_type = COALESCE($5, tier_type),
           price_minor = COALESCE($6::bigint, price_minor),
           capacity = COALESCE($7, capacity),
           remaining = COALESCE($8, remaining),
           sales_paused = COALESCE($9, sales_paused),
           metadata = $10::jsonb,
           updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [
        tierId,
        actor.tenantId,
        body.name != null ? String(body.name) : null,
        body.description != null ? String(body.description) : null,
        body.tierType != null ? String(body.tierType) : null,
        body.priceMinor != null ? String(body.priceMinor) : null,
        body.capacity != null ? Number(body.capacity) : null,
        body.remaining != null
          ? Number(body.remaining)
          : unlimited && body.capacity != null
            ? Number(body.capacity)
            : null,
        body.salesPaused != null ? body.salesPaused === true : null,
        JSON.stringify(meta),
      ],
    );
    return { ok: true };
  }

  /**
   * Soft-delete (archive) when sold; hard-delete when never sold.
   */
  async remove(actor: CommerceActor, tierId: string) {
    const row = await this.getTier(actor.tenantId, tierId);
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    const sold = row.capacity - row.remaining;
    const unlimited = parseTierMeta(row.metadata).unlimitedCapacity === true;
    // Unlimited tiers: treat any fulfilled order lines as "has sales"
    const { rows: salesRows } = await this.pool.query<{ c: string }>(
      `SELECT COUNT(*)::text AS c FROM ticket_order_lines l
       INNER JOIN ticket_orders o ON o.id = l.ticket_order_id
       WHERE l.tenant_id = $1 AND l.tier_id = $2
         AND o.status IN ('pending_payment', 'confirmed', 'fulfilled')`,
      [actor.tenantId, row.external_tier_id],
    );
    const hasOrderLines = Number(salesRows[0]?.c ?? 0) > 0;

    if ((!unlimited && sold > 0) || hasOrderLines) {
      const meta = {
        ...row.metadata,
        archived: true,
        archivedAt: new Date().toISOString(),
      };
      await this.pool.query(
        `UPDATE event_ticket_tiers
         SET sales_paused = true, metadata = $3::jsonb, updated_at = now()
         WHERE id = $1 AND tenant_id = $2`,
        [tierId, actor.tenantId, JSON.stringify(meta)],
      );
      return { ok: true, softDeleted: true, archived: true };
    }

    await this.pool.query(`DELETE FROM event_ticket_tiers WHERE id = $1 AND tenant_id = $2`, [
      tierId,
      actor.tenantId,
    ]);
    return { ok: true, softDeleted: false, archived: false };
  }

  async archive(actor: CommerceActor, tierId: string) {
    const row = await this.getTier(actor.tenantId, tierId);
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    const meta = {
      ...row.metadata,
      archived: true,
      archivedAt: new Date().toISOString(),
    };
    await this.pool.query(
      `UPDATE event_ticket_tiers
       SET sales_paused = true, metadata = $3::jsonb, updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [tierId, actor.tenantId, JSON.stringify(meta)],
    );
    return { ok: true, archived: true };
  }

  async unarchive(actor: CommerceActor, tierId: string) {
    const row = await this.getTier(actor.tenantId, tierId);
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    const meta: Record<string, unknown> = { ...row.metadata, archived: false };
    delete meta.archivedAt;
    await this.pool.query(
      `UPDATE event_ticket_tiers
       SET metadata = $3::jsonb, updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [tierId, actor.tenantId, JSON.stringify(meta)],
    );
    return { ok: true, archived: false };
  }

  async duplicate(actor: CommerceActor, tierId: string) {
    const row = await this.getTierFull(actor.tenantId, tierId);
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    const newExternal = `tier_${Date.now()}_copy`;
    const meta: Record<string, unknown> = {
      ...row.metadata,
      archived: false,
      sortOrder: Number(row.metadata?.sortOrder ?? 0) + 1,
    };
    delete meta.archivedAt;
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO event_ticket_tiers (
         tenant_id, event_id, external_tier_id, name, description, tier_type,
         price_minor, currency, capacity, remaining, sales_paused, metadata
       ) VALUES ($1, $2, $3, $4, $5, $6, $7::bigint, $8, $9, $10, false, $11::jsonb)
       RETURNING id`,
      [
        actor.tenantId,
        row.event_id,
        newExternal,
        `${row.name} (Copy)`,
        row.description,
        row.tier_type,
        row.price_minor,
        row.currency,
        row.capacity,
        row.capacity,
        JSON.stringify(meta),
      ],
    );
    return { id: rows[0]!.id, externalTierId: newExternal };
  }

  async reorder(actor: CommerceActor, eventKey: string, orderedExternalIds: string[]) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    let i = 0;
    for (const extId of orderedExternalIds) {
      await this.pool.query(
        `UPDATE event_ticket_tiers
         SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{sortOrder}', to_jsonb($4::int), true),
             updated_at = now()
         WHERE tenant_id = $1 AND event_id = $2 AND external_tier_id = $3`,
        [actor.tenantId, event.id, extId, i],
      );
      i += 1;
    }
    return { ok: true };
  }

  /** Sales + remaining by tier for organizer reporting. */
  async salesByTier(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const tiers = await this.events.loadTiersForEvent(actor.tenantId, event.id, {
      includeArchived: true,
    });
    const { rows: soldRows } = await this.pool.query<{
      tier_id: string;
      qty: string;
      revenue: string;
    }>(
      `SELECT l.tier_id,
              COALESCE(SUM(l.quantity), 0)::text AS qty,
              COALESCE(SUM(l.line_subtotal_minor), 0)::text AS revenue
       FROM ticket_order_lines l
       INNER JOIN ticket_orders o ON o.id = l.ticket_order_id
       WHERE o.tenant_id = $1 AND o.event_id = $2
         AND o.status IN ('confirmed', 'fulfilled')
       GROUP BY l.tier_id`,
      [actor.tenantId, event.id],
    );
    const soldMap = new Map(soldRows.map((r) => [r.tier_id, r]));
    return {
      items: tiers.map((t) => {
        const s = soldMap.get(String(t.id));
        const capacity = Number(t.capacity ?? 0);
        const remaining = Number(t.remaining ?? 0);
        const unlimited = t.unlimitedCapacity === true;
        const soldFromInv = unlimited ? Number(s?.qty ?? 0) : capacity - remaining;
        const sold = Number(s?.qty ?? soldFromInv);
        return {
          tierId: t.tierId,
          externalTierId: t.id,
          name: t.name,
          tierType: t.tierType,
          capacity,
          remaining: unlimited ? null : remaining,
          unlimitedCapacity: unlimited,
          sold,
          revenueMinor: s?.revenue ?? '0',
          soldOut: !unlimited && remaining <= 0,
          archived: t.archived === true,
          salesPaused: t.salesPaused === true,
        };
      }),
    };
  }

  private buildMeta(
    body: Record<string, unknown>,
    existing: Record<string, unknown>,
  ): Record<string, unknown> {
    const out: Record<string, unknown> = { ...existing };
    if (body.visibility !== undefined) out.visibility = body.visibility;
    if (body.salesStartAt !== undefined) out.salesStartAt = body.salesStartAt;
    if (body.salesEndAt !== undefined) out.salesEndAt = body.salesEndAt;
    if (body.archived !== undefined) out.archived = body.archived === true;
    if (body.unlimitedCapacity !== undefined) out.unlimitedCapacity = body.unlimitedCapacity === true;
    if (body.minQuantity !== undefined) out.minQuantity = Number(body.minQuantity);
    if (body.maxQuantity !== undefined) {
      out.maxQuantity = body.maxQuantity == null ? null : Number(body.maxQuantity);
    }
    if (body.maxPerUser !== undefined) {
      out.maxPerUser = body.maxPerUser == null ? null : Number(body.maxPerUser);
    }
    if (body.sortOrder !== undefined) out.sortOrder = Number(body.sortOrder);
    return out;
  }

  private tierMeta(body: Record<string, unknown>) {
    return this.buildMeta(body, {});
  }

  private async getTier(tenantId: string, tierId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      event_id: string;
      external_tier_id: string;
      capacity: number;
      remaining: number;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, event_id, external_tier_id, capacity, remaining, metadata
       FROM event_ticket_tiers WHERE id = $1 AND tenant_id = $2`,
      [tierId, tenantId],
    );
    const row = rows[0];
    if (!row) throw new NotFoundException({ code: 'TIER_NOT_FOUND', message: 'Tier not found' });
    return row;
  }

  private async getTierFull(tenantId: string, tierId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      event_id: string;
      external_tier_id: string;
      name: string;
      description: string;
      tier_type: string;
      price_minor: string;
      currency: string;
      capacity: number;
      remaining: number;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, event_id, external_tier_id, name, description, tier_type, price_minor::text,
              currency, capacity, remaining, metadata
       FROM event_ticket_tiers WHERE id = $1 AND tenant_id = $2`,
      [tierId, tenantId],
    );
    const row = rows[0];
    if (!row) throw new NotFoundException({ code: 'TIER_NOT_FOUND', message: 'Tier not found' });
    return row;
  }
}
