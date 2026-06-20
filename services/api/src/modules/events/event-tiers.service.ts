import { Injectable, Inject, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';
import { EventsService } from './events.service';

@Injectable()
export class EventTiersService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly events: EventsService,
  ) {}

  async list(actor: CommerceActor | null, tenantId: string, eventKey: string) {
    if (actor) {
      try {
        const event = await this.access.assertOrganizerOwnsEvent(tenantId, actor.userId, eventKey);
        return { items: await this.events.loadTiersForEvent(tenantId, event.id) };
      } catch {
        // public fallback for marketplace
      }
    }
    const event = await this.access.resolveEventRow(tenantId, eventKey, !actor);
    return { items: await this.events.loadTiersForEvent(tenantId, event.id) };
  }

  async create(actor: CommerceActor, eventKey: string, body: Record<string, unknown>) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const externalId = String(body.id ?? body.externalTierId ?? `tier_${Date.now()}`);
    const capacity = Number(body.capacity ?? 0);
    if (capacity < 0) {
      throw new UnprocessableEntityException({ code: 'INVALID_CAPACITY', message: 'Invalid capacity' });
    }
    const remaining = body.remaining != null ? Number(body.remaining) : capacity;
    const meta = {
      visibility: body.visibility ?? 'publicListing',
      salesStartAt: body.salesStartAt ?? null,
      salesEndAt: body.salesEndAt ?? null,
    };
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
    const meta = { ...row.metadata, ...this.tierMeta(body) };
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
        body.remaining != null ? Number(body.remaining) : null,
        body.salesPaused != null ? body.salesPaused === true : null,
        JSON.stringify(meta),
      ],
    );
    return { ok: true };
  }

  async remove(actor: CommerceActor, tierId: string) {
    const row = await this.getTier(actor.tenantId, tierId);
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, row.event_id);
    const sold = row.capacity - row.remaining;
    if (sold > 0) {
      throw new UnprocessableEntityException({
        code: 'TIER_HAS_SALES',
        message: 'Cannot delete tier with sales',
      });
    }
    await this.pool.query(`DELETE FROM event_ticket_tiers WHERE id = $1 AND tenant_id = $2`, [
      tierId,
      actor.tenantId,
    ]);
    return { ok: true };
  }

  private tierMeta(body: Record<string, unknown>) {
    const out: Record<string, unknown> = {};
    if (body.visibility !== undefined) out.visibility = body.visibility;
    if (body.salesStartAt !== undefined) out.salesStartAt = body.salesStartAt;
    if (body.salesEndAt !== undefined) out.salesEndAt = body.salesEndAt;
    return out;
  }

  private async getTier(tenantId: string, tierId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      event_id: string;
      capacity: number;
      remaining: number;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, event_id, capacity, remaining, metadata FROM event_ticket_tiers WHERE id = $1 AND tenant_id = $2`,
      [tierId, tenantId],
    );
    const row = rows[0];
    if (!row) throw new NotFoundException({ code: 'TIER_NOT_FOUND', message: 'Tier not found' });
    return row;
  }
}
