import { Injectable, Inject, NotFoundException, ForbiddenException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';

@Injectable()
export class VendorNegotiationsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  async listForEvent(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      id: string;
      vendor_id: string;
      status: string;
      service_label: string | null;
      created_at: Date;
    }>(
      `SELECT id, vendor_id, status::text, service_label, created_at
       FROM vendor_negotiations WHERE tenant_id = $1 AND event_id = $2 ORDER BY created_at DESC`,
      [actor.tenantId, event.id],
    );
    const items = [];
    for (const row of rows) {
      const offers = await this.loadOffers(row.id);
      items.push({
        id: row.id,
        vendorId: row.vendor_id,
        status: row.status,
        serviceLabel: row.service_label,
        createdAt: row.created_at.toISOString(),
        offers,
      });
    }
    return { items };
  }

  async createRequest(actor: CommerceActor, eventKey: string, body: Record<string, unknown>) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    const vendorId = String(body.vendorId ?? '').trim();
    if (!vendorId) throw new NotFoundException({ code: 'VENDOR_REQUIRED' });
    const amountMinor = String(body.amountMinor ?? '0');
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO vendor_negotiations (tenant_id, event_id, vendor_id, organizer_id, service_label, status)
       VALUES ($1, $2, $3, $4, $5, 'pending') RETURNING id`,
      [actor.tenantId, event.id, vendorId, organizerId, body.serviceLabel ?? null],
    );
    const negotiationId = rows[0]!.id;
    await this.insertOffer(negotiationId, 'organizer', actor.userId, amountMinor, String(body.message ?? ''), 'pending');
    return this.getNegotiation(actor.tenantId, negotiationId);
  }

  async counterOffer(
    actor: CommerceActor,
    negotiationId: string,
    body: Record<string, unknown>,
    actorType: 'organizer' | 'vendor',
  ) {
    const neg = await this.getNegotiationRow(actor.tenantId, negotiationId);
    if (neg.status !== 'pending') {
      throw new ForbiddenException({ code: 'NEGOTIATION_CLOSED' });
    }
    const amountMinor = String(body.amountMinor ?? '0');
    const status = body.isFinal === true ? 'final' : 'countered';
    await this.insertOffer(negotiationId, actorType, actor.userId, amountMinor, String(body.message ?? ''), status);
    return this.getNegotiation(actor.tenantId, negotiationId);
  }

  async respondToOffer(
    actor: CommerceActor,
    negotiationId: string,
    offerId: string,
    body: Record<string, unknown>,
  ) {
    const action = String(body.action ?? '');
    const neg = await this.getNegotiationRow(actor.tenantId, negotiationId);
    if (action === 'accept') {
      await this.pool.query(`UPDATE vendor_negotiation_offers SET status = 'accepted' WHERE id = $1`, [offerId]);
      await this.pool.query(
        `UPDATE vendor_negotiations SET status = 'accepted', updated_at = now() WHERE id = $1`,
        [negotiationId],
      );
    } else if (action === 'reject') {
      await this.pool.query(`UPDATE vendor_negotiation_offers SET status = 'rejected' WHERE id = $1`, [offerId]);
      await this.pool.query(
        `UPDATE vendor_negotiations SET status = 'declined', updated_at = now() WHERE id = $1`,
        [negotiationId],
      );
    }
    return this.getNegotiation(actor.tenantId, negotiationId);
  }

  private async getNegotiationRow(tenantId: string, id: string) {
    const { rows } = await this.pool.query<{ id: string; status: string }>(
      `SELECT id, status::text FROM vendor_negotiations WHERE tenant_id = $1 AND id = $2`,
      [tenantId, id],
    );
    if (!rows.length) throw new NotFoundException({ code: 'NEGOTIATION_NOT_FOUND' });
    return rows[0]!;
  }

  private async getNegotiation(tenantId: string, id: string) {
    const neg = await this.getNegotiationRow(tenantId, id);
    const offers = await this.loadOffers(id);
    return { id: neg.id, status: neg.status, offers };
  }

  private async loadOffers(negotiationId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      actor_type: string;
      actor_user_id: string;
      amount_minor: string;
      currency: string;
      message: string | null;
      status: string;
      created_at: Date;
    }>(
      `SELECT id, actor_type, actor_user_id, amount_minor::text, currency, message, status::text, created_at
       FROM vendor_negotiation_offers WHERE negotiation_id = $1 ORDER BY created_at ASC`,
      [negotiationId],
    );
    return rows.map((o) => ({
      id: o.id,
      actorType: o.actor_type,
      actorUserId: o.actor_user_id,
      amountMinor: o.amount_minor,
      currency: o.currency,
      message: o.message ?? '',
      status: o.status,
      createdAt: o.created_at.toISOString(),
    }));
  }

  private async insertOffer(
    negotiationId: string,
    actorType: string,
    actorUserId: string,
    amountMinor: string,
    message: string,
    status: string,
  ) {
    await this.pool.query(
      `INSERT INTO vendor_negotiation_offers
         (negotiation_id, actor_type, actor_user_id, amount_minor, message, status)
       VALUES ($1, $2, $3, $4::bigint, $5, $6::negotiation_offer_status)`,
      [negotiationId, actorType, actorUserId, amountMinor, message, status],
    );
  }
}
