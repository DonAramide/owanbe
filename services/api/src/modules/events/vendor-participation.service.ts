import { Injectable, Inject, UnprocessableEntityException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';

@Injectable()
export class VendorParticipationService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  async listForVendor(actor: CommerceActor) {
    const vendorId = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    const { rows: parts } = await this.pool.query<{
      id: string;
      event_id: string;
      status: string;
      booth_label: string;
      expected_payout_minor: string;
      title: string;
      starts_at: Date;
      metadata: Record<string, unknown>;
      external_ref: string | null;
    }>(
      `SELECT vep.id, vep.event_id, vep.status::text, vep.booth_label, vep.expected_payout_minor::text,
              e.title, e.starts_at, e.metadata, e.external_ref
       FROM vendor_event_participations vep
       INNER JOIN events e ON e.id = vep.event_id
       WHERE vep.tenant_id = $1 AND vep.vendor_id = $2
       ORDER BY e.starts_at ASC`,
      [actor.tenantId, vendorId],
    );

    const participated = new Set(parts.map((p) => p.event_id));
    const { rows: discover } = await this.pool.query<{
      id: string;
      external_ref: string | null;
      title: string;
      starts_at: Date;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, external_ref, title, starts_at, metadata
       FROM events
       WHERE tenant_id = $1 AND status::text IN ('published', 'live')
       ORDER BY starts_at ASC`,
      [actor.tenantId],
    );

    const items = [
      ...parts.map((p) => this.mapParticipation(p)),
      ...discover
        .filter((e) => !participated.has(e.id))
        .map((e) => ({
          id: `disc_${e.id}`,
          participationId: null,
          eventId: e.external_ref ?? e.id,
          eventUuid: e.id,
          eventTitle: e.title,
          city: String(e.metadata?.city ?? ''),
          venue: String(e.metadata?.venue ?? ''),
          startsAt: e.starts_at.toISOString(),
          status: 'invited',
          lifecycleStage: 'invited',
          boothLabel: 'Vendor village',
          expectedPayoutMinor: '25000000',
        })),
    ];
    return { items };
  }

  async apply(actor: CommerceActor, eventKey: string) {
    const vendorId = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    const event = await this.access.resolveEventRow(actor.tenantId, eventKey, true);
    try {
      const { rows } = await this.pool.query<{ id: string }>(
        `INSERT INTO vendor_event_participations (
           tenant_id, vendor_id, event_id, status, booth_label, expected_payout_minor
         ) VALUES ($1, $2, $3, 'applied', 'Vendor village', 25000000)
         RETURNING id`,
        [actor.tenantId, vendorId, event.id],
      );
      return { id: rows[0]!.id, status: 'applied', eventId: event.external_ref ?? event.id };
    } catch (e: unknown) {
      const err = e as { code?: string };
      if (err.code === '23505') {
        throw new UnprocessableEntityException({
          code: 'ALREADY_APPLIED',
          message: 'Already applied to this event',
        });
      }
      throw e;
    }
  }

  async accept(actor: CommerceActor, eventKey: string) {
    return this.transition(actor, eventKey, 'approved', ['invited', 'applied', 'pending']);
  }

  async reject(actor: CommerceActor, eventKey: string) {
    return this.transition(actor, eventKey, 'rejected', ['invited', 'applied', 'pending']);
  }

  private async transition(
    actor: CommerceActor,
    eventKey: string,
    next: string,
    allowed: string[],
  ) {
    const vendorId = await this.access.resolveVendorId(actor.tenantId, actor.userId);
    const event = await this.access.resolveEventRow(actor.tenantId, eventKey);
    const { rows } = await this.pool.query<{ id: string; status: string }>(
      `UPDATE vendor_event_participations
       SET status = $4::vendor_participation_status, updated_at = now()
       WHERE tenant_id = $1 AND vendor_id = $2 AND event_id = $3
         AND status::text = ANY($5::text[])
       RETURNING id, status::text`,
      [actor.tenantId, vendorId, event.id, next, allowed],
    );
    if (!rows[0]) {
      const ins = await this.pool.query<{ id: string }>(
        `INSERT INTO vendor_event_participations (tenant_id, vendor_id, event_id, status)
         VALUES ($1, $2, $3, $4::vendor_participation_status)
         ON CONFLICT (vendor_id, event_id) DO UPDATE SET status = EXCLUDED.status, updated_at = now()
         RETURNING id`,
        [actor.tenantId, vendorId, event.id, next],
      );
      return { id: ins.rows[0]!.id, status: next };
    }
    return { id: rows[0].id, status: rows[0].status };
  }

  private mapParticipation(p: {
    id: string;
    event_id: string;
    status: string;
    booth_label: string;
    expected_payout_minor: string;
    title: string;
    starts_at: Date;
    metadata: Record<string, unknown>;
    external_ref?: string | null;
  }) {
    const lifecycle = this.lifecycleFromStatus(p.status);
    const publicEventId = p.external_ref ?? p.event_id;
    return {
      id: p.id,
      participationId: p.id,
      eventId: publicEventId,
      eventUuid: p.event_id,
      eventTitle: p.title,
      city: String(p.metadata?.city ?? ''),
      venue: String(p.metadata?.venue ?? ''),
      startsAt: p.starts_at.toISOString(),
      status: p.status,
      lifecycleStage: lifecycle,
      boothLabel: p.booth_label,
      expectedPayoutMinor: p.expected_payout_minor,
    };
  }

  private lifecycleFromStatus(status: string): string {
    if (status === 'invited') return 'invited';
    if (status === 'applied' || status === 'pending') return 'applied';
    if (status === 'approved' || status === 'live') return 'approved';
    if (status === 'completed') return 'completed';
    return 'applied';
  }
}
