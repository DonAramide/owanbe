import {
  BadRequestException,
  Injectable,
  Inject,
  NotFoundException,
} from '@nestjs/common';
import { createHash, randomBytes } from 'crypto';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { NotificationService } from '../../integrations/notifications/notification.service';
import { MetricsService } from '../../integrations/observability/metrics.service';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';

export type InvitationStatsView = {
  sent: number;
  delivered: number;
  opened: number;
  rsvpConfirmed: number;
  rsvpDeclined: number;
  pending: number;
};

export type InvitationDeliveryView = {
  id: string;
  guestId: string;
  guestName: string;
  status: string;
  channel: string;
  sentAt: string | null;
  deliveredAt: string | null;
  openedAt: string | null;
  failedAt: string | null;
  failureReason: string | null;
};

export type InvitationValidateView = {
  valid: boolean;
  eventId: string;
  eventTitle: string;
  guestId: string;
  guestName: string;
  rsvpStatus: string;
  expiresAt: string | null;
};

@Injectable()
export class EventInvitationsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly notifications: NotificationService,
    private readonly metrics: MetricsService,
  ) {}

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private generateToken(): string {
    return randomBytes(24).toString('base64url');
  }

  async getStats(actor: CommerceActor, eventKey: string): Promise<InvitationStatsView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      sent: string;
      delivered: string;
      opened: string;
      rsvp_confirmed: string;
      rsvp_declined: string;
      pending: string;
    }>(
      `SELECT
         COUNT(*) FILTER (WHERE i.status IN ('sent','delivered','opened'))::text AS sent,
         COUNT(*) FILTER (WHERE i.status IN ('delivered','opened'))::text AS delivered,
         COUNT(*) FILTER (WHERE i.status = 'opened')::text AS opened,
         COUNT(*) FILTER (WHERE g.rsvp_status = 'confirmed')::text AS rsvp_confirmed,
         COUNT(*) FILTER (WHERE g.rsvp_status = 'declined')::text AS rsvp_declined,
         COUNT(*) FILTER (WHERE g.rsvp_status IN ('invited','pending'))::text AS pending
       FROM event_guests g
       LEFT JOIN event_invitations i ON i.guest_id = g.id AND i.event_id = g.event_id
       WHERE g.tenant_id = $1 AND g.event_id = $2`,
      [actor.tenantId, event.id],
    );
    const r = rows[0]!;
    return {
      sent: Number(r.sent),
      delivered: Number(r.delivered),
      opened: Number(r.opened),
      rsvpConfirmed: Number(r.rsvp_confirmed),
      rsvpDeclined: Number(r.rsvp_declined),
      pending: Number(r.pending),
    };
  }

  async listDeliveries(actor: CommerceActor, eventKey: string): Promise<{ items: InvitationDeliveryView[] }> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      id: string;
      guest_id: string;
      guest_name: string;
      status: string;
      channel: string;
      sent_at: Date | null;
      delivered_at: Date | null;
      opened_at: Date | null;
      failed_at: Date | null;
      failure_reason: string | null;
    }>(
      `SELECT i.id, i.guest_id, g.name AS guest_name, i.status::text, i.channel::text,
              i.sent_at, i.delivered_at, i.opened_at, i.failed_at, i.failure_reason
       FROM event_invitations i
       JOIN event_guests g ON g.id = i.guest_id
       WHERE i.tenant_id = $1 AND i.event_id = $2
       ORDER BY i.created_at DESC`,
      [actor.tenantId, event.id],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        guestId: r.guest_id,
        guestName: r.guest_name,
        status: r.status,
        channel: r.channel,
        sentAt: r.sent_at?.toISOString() ?? null,
        deliveredAt: r.delivered_at?.toISOString() ?? null,
        openedAt: r.opened_at?.toISOString() ?? null,
        failedAt: r.failed_at?.toISOString() ?? null,
        failureReason: r.failure_reason,
      })),
    };
  }

  async sendInvitations(
    actor: CommerceActor,
    eventKey: string,
    body: { guestIds?: string[]; channel?: string; templateId?: string },
  ): Promise<{ sent: number; tokens: Array<{ guestId: string; inviteUrl: string }> }> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const channel = (body.channel ?? 'link').trim();
    const templateId = body.templateId?.trim() || null;
    const guestIds = body.guestIds ?? [];

    let guestFilter = '';
    const params: unknown[] = [actor.tenantId, event.id];
    if (guestIds.length > 0) {
      guestFilter = ' AND g.id = ANY($3::uuid[])';
      params.push(guestIds);
    }

    const { rows: guests } = await this.pool.query<{ id: string; name: string; email: string | null }>(
      `SELECT g.id, g.name, g.email
       FROM event_guests g
       WHERE g.tenant_id = $1 AND g.event_id = $2${guestFilter}`,
      params,
    );
    if (guests.length === 0) {
      throw new BadRequestException({ code: 'NO_GUESTS', message: 'No guests to invite' });
    }

    const baseUrl = process.env.PUBLIC_API_BASE_URL?.replace(/\/$/, '') ?? 'https://app.owanbe.com';
    const tokens: Array<{ guestId: string; inviteUrl: string }> = [];
    let sent = 0;

    for (const guest of guests) {
      const plainToken = this.generateToken();
      const tokenHash = this.hashToken(plainToken);
      const expiresAt = new Date(Date.now() + 90 * 24 * 60 * 60 * 1000);

      const { rows: invRows } = await this.pool.query<{ id: string }>(
        `INSERT INTO event_invitations (tenant_id, event_id, guest_id, status, channel, template_id, sent_at, delivered_at)
         VALUES ($1, $2, $3, 'sent', $4::event_invitation_channel, $5, now(), now())
         RETURNING id`,
        [actor.tenantId, event.id, guest.id, channel, templateId],
      );
      const invitationId = invRows[0]!.id;

      await this.pool.query(
        `INSERT INTO event_invitation_tokens (tenant_id, event_id, guest_id, invitation_id, token_hash, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [actor.tenantId, event.id, guest.id, invitationId, tokenHash, expiresAt],
      );

      await this.pool.query(
        `UPDATE event_guests SET rsvp_status = 'pending', updated_at = now()
         WHERE id = $1 AND rsvp_status = 'invited'`,
        [guest.id],
      );

      const inviteUrl = `${baseUrl}/events/${event.id}/rsvp?token=${plainToken}`;
      tokens.push({ guestId: guest.id, inviteUrl });

      if (guest.email && channel === 'email') {
        const result = await this.notifications.send({
          tenantId: actor.tenantId,
          channel: 'email',
          template: 'event_invitation',
          recipient: guest.email,
          subject: `You're invited — ${event.title}`,
          body: `Hi ${guest.name},\n\nYou're invited to ${event.title}.\nRSVP: ${inviteUrl}`,
        });
        if (!result.ok) {
          this.metrics.inc('invitations_failed_total', { reason: 'email_delivery' });
          await this.pool.query(
            `UPDATE event_invitations SET status = 'failed', failed_at = now(), failure_reason = 'email_delivery_failed', updated_at = now()
             WHERE id = $1`,
            [invitationId],
          );
          continue;
        }
      }

      await this.pool.query(
        `UPDATE event_invitations SET status = 'delivered', delivered_at = now(), updated_at = now() WHERE id = $1`,
        [invitationId],
      );
      sent += 1;
      this.metrics.inc('invitations_sent_total', { channel });
    }

    return { sent, tokens };
  }

  async validateToken(tenantId: string, token: string): Promise<InvitationValidateView> {
    const tokenHash = this.hashToken(token.trim());
    const { rows } = await this.pool.query<{
      event_id: string;
      event_title: string;
      guest_id: string;
      guest_name: string;
      rsvp_status: string;
      expires_at: Date | null;
    }>(
      `SELECT t.event_id, e.title AS event_title, t.guest_id, g.name AS guest_name,
              g.rsvp_status::text, t.expires_at
       FROM event_invitation_tokens t
       JOIN events e ON e.id = t.event_id
       JOIN event_guests g ON g.id = t.guest_id
       WHERE t.tenant_id = $1 AND t.token_hash = $2
         AND (t.expires_at IS NULL OR t.expires_at > now())
       LIMIT 1`,
      [tenantId, tokenHash],
    );
    const row = rows[0];
    if (!row) {
      this.metrics.inc('invitations_failed_total', { reason: 'invalid_token' });
      throw new NotFoundException({ code: 'INVALID_TOKEN', message: 'Invitation token is invalid or expired' });
    }

    await this.pool.query(
      `UPDATE event_invitations SET status = 'opened', opened_at = COALESCE(opened_at, now()), updated_at = now()
       WHERE guest_id = $1 AND event_id = $2 AND status IN ('sent','delivered')`,
      [row.guest_id, row.event_id],
    );

    return {
      valid: true,
      eventId: row.event_id,
      eventTitle: row.event_title,
      guestId: row.guest_id,
      guestName: row.guest_name,
      rsvpStatus: row.rsvp_status,
      expiresAt: row.expires_at?.toISOString() ?? null,
    };
  }

  async rsvpWithToken(
    tenantId: string,
    token: string,
    status: 'confirmed' | 'declined',
  ): Promise<{ ok: true; rsvpStatus: string }> {
    const tokenHash = this.hashToken(token.trim());
    const { rows } = await this.pool.query<{ guest_id: string; event_id: string }>(
      `SELECT guest_id, event_id FROM event_invitation_tokens
       WHERE tenant_id = $1 AND token_hash = $2
         AND (expires_at IS NULL OR expires_at > now())
       LIMIT 1`,
      [tenantId, tokenHash],
    );
    const row = rows[0];
    if (!row) {
      this.metrics.inc('rsvp_failed_total', { reason: 'invalid_token' });
      throw new NotFoundException({ code: 'INVALID_TOKEN', message: 'Invitation token is invalid or expired' });
    }
    if (!['confirmed', 'declined'].includes(status)) {
      this.metrics.inc('rsvp_failed_total', { reason: 'invalid_status' });
      throw new BadRequestException({ code: 'INVALID_RSVP', message: 'RSVP status must be confirmed or declined' });
    }

    await this.pool.query(
      `UPDATE event_guests SET rsvp_status = $3::event_guest_rsvp_status, updated_at = now()
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, row.guest_id, status],
    );
    await this.pool.query(
      `UPDATE event_invitation_tokens SET used_at = COALESCE(used_at, now()) WHERE token_hash = $1`,
      [tokenHash],
    );

    this.metrics.inc('rsvp_total', { status });
    return { ok: true, rsvpStatus: status };
  }

  async listHub(actor: CommerceActor, eventKey: string) {
    const stats = await this.getStats(actor, eventKey);
    const deliveries = await this.listDeliveries(actor, eventKey);
    return {
      stats: {
        sent: stats.sent,
        delivered: stats.delivered,
        opened: stats.opened,
        rsvp: stats.rsvpConfirmed,
      },
      items: deliveries.items.map((d) => ({
        id: d.id,
        guestId: d.guestId,
        guestName: d.guestName,
        guestEmail: null,
        channel: d.channel,
        status: d.status,
        deliveryStatus: d.status,
      })),
    };
  }

  async sendBatch(
    actor: CommerceActor,
    eventKey: string,
    body: { guestIds?: string[]; channel?: string; templateId?: string },
  ) {
    return this.sendInvitations(actor, eventKey, body);
  }

  async rsvpByToken(tenantId: string, token: string, status: 'confirmed' | 'declined') {
    return this.rsvpWithToken(tenantId, token, status);
  }
}
