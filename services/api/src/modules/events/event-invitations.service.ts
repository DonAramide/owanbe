import {
  BadRequestException,
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { createHash, randomBytes } from 'crypto';
import type { Pool, PoolClient } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { NotificationService } from '../../integrations/notifications/notification.service';
import { MetricsService } from '../../integrations/observability/metrics.service';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';
import { issueInvitationEntitlement, resolveUserIdByEmail } from './invite-entitlement';
import { DomainEventsService } from '../domain-events/domain-events.service';
import { DOMAIN_EVENTS } from '../domain-events/domain-event.types';

export type InvitationStatsView = {
  sent: number;
  delivered: number;
  opened: number;
  rsvpConfirmed: number;
  rsvpDeclined: number;
  pending: number;
  ticketsIssued: number;
};

export type InvitationDeliveryView = {
  id: string;
  guestId: string;
  guestName: string;
  guestEmail: string | null;
  status: string;
  channel: string;
  rsvpStatus: string;
  entitlementRef: string | null;
  sentAt: string | null;
  deliveredAt: string | null;
  openedAt: string | null;
  failedAt: string | null;
  failureReason: string | null;
  respondedAt: string | null;
};

export type InvitationValidateView = {
  valid: boolean;
  reason?: string;
  eventId: string;
  eventTitle: string;
  guestId: string;
  guestName: string;
  rsvpStatus: string;
  expiresAt: string | null;
  usedAt: string | null;
  startsAt: string | null;
  venue: string | null;
  city: string | null;
};

@Injectable()
export class EventInvitationsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly notifications: NotificationService,
    private readonly metrics: MetricsService,
    private readonly domainEvents: DomainEventsService,
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
      tickets_issued: string;
    }>(
      `SELECT
         COUNT(*) FILTER (WHERE i.status IN ('sent','delivered','opened'))::text AS sent,
         COUNT(*) FILTER (WHERE i.status IN ('delivered','opened'))::text AS delivered,
         COUNT(*) FILTER (WHERE i.status = 'opened')::text AS opened,
         COUNT(*) FILTER (WHERE g.rsvp_status = 'confirmed')::text AS rsvp_confirmed,
         COUNT(*) FILTER (WHERE g.rsvp_status = 'declined')::text AS rsvp_declined,
         COUNT(*) FILTER (WHERE g.rsvp_status IN ('invited','pending'))::text AS pending,
         COUNT(*) FILTER (WHERE g.entitlement_ref IS NOT NULL)::text AS tickets_issued
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
      ticketsIssued: Number(r.tickets_issued),
    };
  }

  async listDeliveries(actor: CommerceActor, eventKey: string): Promise<{ items: InvitationDeliveryView[] }> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      id: string;
      guest_id: string;
      guest_name: string;
      guest_email: string | null;
      status: string;
      channel: string;
      rsvp_status: string;
      entitlement_ref: string | null;
      sent_at: Date | null;
      delivered_at: Date | null;
      opened_at: Date | null;
      failed_at: Date | null;
      failure_reason: string | null;
      guest_updated_at: Date;
    }>(
      `SELECT i.id, i.guest_id, g.name AS guest_name, g.email AS guest_email,
              i.status::text, i.channel::text, g.rsvp_status::text, g.entitlement_ref,
              i.sent_at, i.delivered_at, i.opened_at, i.failed_at, i.failure_reason,
              g.updated_at AS guest_updated_at
       FROM event_invitations i
       JOIN event_guests g ON g.id = i.guest_id
       WHERE i.tenant_id = $1 AND i.event_id = $2
         AND COALESCE(i.failure_reason, '') <> 'cancelled_by_organizer'
       ORDER BY i.created_at DESC`,
      [actor.tenantId, event.id],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        guestId: r.guest_id,
        guestName: r.guest_name,
        guestEmail: r.guest_email,
        status: r.status,
        channel: r.channel,
        rsvpStatus: r.rsvp_status,
        entitlementRef: r.entitlement_ref,
        sentAt: r.sent_at?.toISOString() ?? null,
        deliveredAt: r.delivered_at?.toISOString() ?? null,
        openedAt: r.opened_at?.toISOString() ?? null,
        failedAt: r.failed_at?.toISOString() ?? null,
        failureReason: r.failure_reason,
        respondedAt:
          r.rsvp_status === 'confirmed' || r.rsvp_status === 'declined'
            ? r.guest_updated_at.toISOString()
            : null,
      })),
    };
  }

  private appBaseUrl(): string {
    const fromEnv =
      process.env.PUBLIC_APP_BASE_URL?.trim() ||
      process.env.APP_PUBLIC_URL?.trim() ||
      process.env.PUBLIC_API_BASE_URL?.trim();
    return (fromEnv && fromEnv.length > 0 ? fromEnv : 'https://app.owanbe.com').replace(/\/$/, '');
  }

  private inviteUrlFor(eventId: string, plainToken: string): string {
    return `${this.appBaseUrl()}/events/${eventId}/rsvp?token=${encodeURIComponent(plainToken)}`;
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

    const baseUrl = this.appBaseUrl();
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
        [actor.tenantId, event.id, guest.id, channel === 'email' ? 'email' : 'link', templateId],
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

      const inviteUrl = this.inviteUrlFor(event.id, plainToken);
      tokens.push({ guestId: guest.id, inviteUrl });

      if (guest.email && (channel === 'email' || channel === 'link')) {
        const result = await this.notifications.send({
          tenantId: actor.tenantId,
          channel: 'email',
          template: 'event_invitation',
          recipient: guest.email,
          subject: `You're invited — ${event.title}`,
          body: `Hi ${guest.name},\n\nYou're invited to ${event.title}.\nRSVP: ${inviteUrl}`,
        });
        if (!result.ok && channel === 'email') {
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
      used_at: Date | null;
      starts_at: Date | null;
      venue: string | null;
      city: string | null;
      inv_failed: string | null;
    }>(
      `SELECT t.event_id, e.title AS event_title, t.guest_id, g.name AS guest_name,
              g.rsvp_status::text, t.expires_at, t.used_at, e.starts_at,
              e.metadata->>'venue' AS venue, e.metadata->>'city' AS city,
              (
                SELECT i.failure_reason FROM event_invitations i
                WHERE i.id = t.invitation_id LIMIT 1
              ) AS inv_failed
       FROM event_invitation_tokens t
       JOIN events e ON e.id = t.event_id
       JOIN event_guests g ON g.id = t.guest_id
       WHERE t.tenant_id = $1 AND t.token_hash = $2
       LIMIT 1`,
      [tenantId, tokenHash],
    );
    const row = rows[0];
    if (!row) {
      this.metrics.inc('invitations_failed_total', { reason: 'invalid_token' });
      throw new NotFoundException({
        code: 'INVALID_TOKEN',
        message: 'Invitation token is invalid',
        reason: 'invalid',
      });
    }
    if (row.inv_failed === 'cancelled_by_organizer') {
      throw new UnprocessableEntityException({
        code: 'INVITATION_CANCELLED',
        message: 'This invitation was cancelled',
        reason: 'cancelled',
        valid: false,
        eventId: row.event_id,
        eventTitle: row.event_title,
        guestId: row.guest_id,
        guestName: row.guest_name,
        rsvpStatus: row.rsvp_status,
      });
    }
    if (row.expires_at && row.expires_at.getTime() <= Date.now()) {
      throw new UnprocessableEntityException({
        code: 'INVITATION_EXPIRED',
        message: 'This invitation has expired',
        reason: 'expired',
        valid: false,
        eventId: row.event_id,
        eventTitle: row.event_title,
        guestId: row.guest_id,
        guestName: row.guest_name,
        rsvpStatus: row.rsvp_status,
        expiresAt: row.expires_at.toISOString(),
      });
    }

    await this.pool.query(
      `UPDATE event_invitations SET status = 'opened', opened_at = COALESCE(opened_at, now()), updated_at = now()
       WHERE guest_id = $1 AND event_id = $2 AND status IN ('sent','delivered')
         AND COALESCE(failure_reason, '') <> 'cancelled_by_organizer'`,
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
      usedAt: row.used_at?.toISOString() ?? null,
      startsAt: row.starts_at?.toISOString() ?? null,
      venue: row.venue,
      city: row.city,
    };
  }

  async rsvpWithToken(
    tenantId: string,
    token: string,
    status: 'confirmed' | 'declined',
    actorUserId?: string,
  ): Promise<{
    ok: true;
    rsvpStatus: string;
    entitlementId?: string;
    ticketCode?: string;
  }> {
    if (!['confirmed', 'declined'].includes(status)) {
      this.metrics.inc('rsvp_failed_total', { reason: 'invalid_status' });
      throw new BadRequestException({
        code: 'INVALID_RSVP',
        message: 'RSVP status must be confirmed or declined (maybe is not supported)',
      });
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const tokenHash = this.hashToken(token.trim());
      const { rows } = await client.query<{
        guest_id: string;
        event_id: string;
        used_at: Date | null;
        expires_at: Date | null;
        organizer_id: string;
        event_title: string;
        guest_name: string;
        guest_email: string | null;
        rsvp_status: string;
        entitlement_ref: string | null;
        inv_failed: string | null;
      }>(
        `SELECT t.guest_id, t.event_id, t.used_at, t.expires_at,
                e.organizer_id, e.title AS event_title,
                g.name AS guest_name, g.email AS guest_email, g.rsvp_status::text,
                g.entitlement_ref,
                (SELECT i.failure_reason FROM event_invitations i WHERE i.id = t.invitation_id) AS inv_failed
         FROM event_invitation_tokens t
         JOIN events e ON e.id = t.event_id
         JOIN event_guests g ON g.id = t.guest_id
         WHERE t.tenant_id = $1 AND t.token_hash = $2
         LIMIT 1`,
        [tenantId, tokenHash],
      );
      const row = rows[0];
      if (!row) {
        throw new NotFoundException({ code: 'INVALID_TOKEN', message: 'Invitation token is invalid or expired' });
      }
      if (row.inv_failed === 'cancelled_by_organizer') {
        throw new UnprocessableEntityException({
          code: 'INVITATION_CANCELLED',
          message: 'This invitation was cancelled',
        });
      }
      if (row.expires_at && row.expires_at.getTime() <= Date.now()) {
        throw new UnprocessableEntityException({
          code: 'INVITATION_EXPIRED',
          message: 'This invitation has expired',
        });
      }
      if (row.used_at && row.rsvp_status !== 'pending' && row.rsvp_status !== 'invited') {
        // One-time: already responded — return current state (idempotent).
        await client.query('COMMIT');
        return {
          ok: true,
          rsvpStatus: row.rsvp_status,
          entitlementId: row.entitlement_ref ?? undefined,
        };
      }

      await client.query(
        `UPDATE event_guests SET rsvp_status = $3::event_guest_rsvp_status, updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, row.guest_id, status],
      );
      await client.query(
        `UPDATE event_invitation_tokens SET used_at = COALESCE(used_at, now()) WHERE token_hash = $1`,
        [tokenHash],
      );

      let entitlementId: string | undefined;
      let ticketCode: string | undefined;

      if (status === 'confirmed') {
        const holderUserId =
          actorUserId ?? (await resolveUserIdByEmail(client, tenantId, row.guest_email));
        if (holderUserId) {
          const issued = await issueInvitationEntitlement(client, {
            tenantId,
            eventId: row.event_id,
            organizerId: row.organizer_id,
            guestId: row.guest_id,
            holderUserId,
            guestName: row.guest_name,
            eventTitle: row.event_title,
          });
          entitlementId = issued?.entitlementId;
          ticketCode = issued?.ticketCode;
        } else {
          await client.query(
            `UPDATE event_guests
             SET metadata = COALESCE(metadata, '{}'::jsonb) || $3::jsonb, updated_at = now()
             WHERE id = $1 AND tenant_id = $2`,
            [
              row.guest_id,
              tenantId,
              JSON.stringify({ pendingEntitlement: true, confirmedAt: new Date().toISOString() }),
            ],
          );
        }
        await this.notifyOrganizerRsvp(client, tenantId, row.organizer_id, row.event_title, row.guest_name, 'accepted');
        if (row.guest_email) {
          void this.notifications.send({
            tenantId,
            channel: 'email',
            template: 'rsvp_confirmation',
            recipient: row.guest_email,
            subject: `RSVP confirmed — ${row.event_title}`,
            body: `Hi ${row.guest_name},\n\nYour RSVP for ${row.event_title} is confirmed.${
              ticketCode ? `\nYour ticket code: ${ticketCode}` : '\nSign in with this email to see your pass.'
            }`,
          });
        }
      } else {
        await this.notifyOrganizerRsvp(client, tenantId, row.organizer_id, row.event_title, row.guest_name, 'declined');
      }

      await client.query('COMMIT');
      this.metrics.inc('rsvp_total', { status });
      this.emitRsvpChanged({
        tenantId,
        organizerId: row.organizer_id,
        eventId: row.event_id,
        guestId: row.guest_id,
        guestName: row.guest_name,
        eventTitle: row.event_title,
        status,
        actorUserId,
      });
      return { ok: true, rsvpStatus: status, entitlementId, ticketCode };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  private async notifyOrganizerRsvp(
    client: PoolClient,
    tenantId: string,
    organizerId: string,
    eventTitle: string,
    guestName: string,
    outcome: 'accepted' | 'declined',
  ) {
    const { rows } = await client.query<{ email: string | null }>(
      `SELECT u.email FROM organizers o
       INNER JOIN users u ON u.id = o.owner_user_id
       WHERE o.id = $1 AND o.tenant_id = $2 LIMIT 1`,
      [organizerId, tenantId],
    );
    const email = rows[0]?.email;
    if (!email) return;
    void this.notifications.send({
      tenantId,
      channel: 'email',
      template: outcome === 'accepted' ? 'invitation_accepted' : 'invitation_declined',
      recipient: email,
      subject: `Invitation ${outcome} — ${eventTitle}`,
      body: `${guestName} ${outcome} their invitation to ${eventTitle}.`,
    });
  }

  private emitRsvpChanged(params: {
    tenantId: string;
    organizerId: string;
    eventId: string;
    guestId: string;
    guestName: string;
    eventTitle: string;
    status: string;
    actorUserId?: string | null;
  }) {
    this.domainEvents.emit(DOMAIN_EVENTS.RSVP_CHANGED, {
      tenantId: params.tenantId,
      organizerId: params.organizerId,
      eventId: params.eventId,
      entityId: params.guestId,
      actorUserId: params.actorUserId ?? null,
      data: {
        rsvpStatus: params.status,
        guestName: params.guestName,
        eventTitle: params.eventTitle,
        summary: `RSVP ${params.status} — ${params.guestName}`,
      },
    });
  }

  async listHub(actor: CommerceActor, eventKey: string) {
    const stats = await this.getStats(actor, eventKey);
    const deliveries = await this.listDeliveries(actor, eventKey);
    const guests = await this.pool.query<{
      id: string;
      name: string;
      email: string | null;
      rsvp_status: string;
      entitlement_ref: string | null;
      updated_at: Date;
      created_at: Date;
    }>(
      `SELECT g.id, g.name, g.email, g.rsvp_status::text, g.entitlement_ref, g.updated_at, g.created_at
       FROM event_guests g
       WHERE g.tenant_id = $1 AND g.event_id = (
         SELECT id FROM events WHERE tenant_id = $1 AND (id::text = $2 OR external_ref = $2 OR slug = $2) LIMIT 1
       )
       ORDER BY g.name ASC`,
      [actor.tenantId, eventKey],
    );
    // Prefer latest invitation per guest; always surface every guest (even if never sent).
    const byGuest = new Map<string, (typeof deliveries.items)[number]>();
    for (const d of deliveries.items) {
      const prev = byGuest.get(d.guestId);
      if (!prev || (d.sentAt ?? '') >= (prev.sentAt ?? '')) {
        byGuest.set(d.guestId, d);
      }
    }
    const items = guests.rows.map((g) => {
      const d = byGuest.get(g.id);
      if (d) {
        return {
          id: d.id,
          guestId: d.guestId,
          guestName: d.guestName,
          guestEmail: d.guestEmail,
          channel: d.channel,
          status: d.status,
          deliveryStatus: d.status,
          rsvpStatus: d.rsvpStatus,
          entitlementRef: d.entitlementRef,
          ticketIssued: !!d.entitlementRef,
          sentAt: d.sentAt,
          respondedAt: d.respondedAt,
        };
      }
      return {
        id: '',
        guestId: g.id,
        guestName: g.name,
        guestEmail: g.email,
        channel: 'email',
        status: 'not_sent',
        deliveryStatus: 'not_sent',
        rsvpStatus: g.rsvp_status,
        entitlementRef: g.entitlement_ref,
        ticketIssued: !!g.entitlement_ref,
        sentAt: null,
        respondedAt:
          g.rsvp_status === 'confirmed' || g.rsvp_status === 'declined'
            ? g.updated_at.toISOString()
            : null,
      };
    });
    return {
      stats: {
        sent: stats.sent,
        delivered: stats.delivered,
        opened: stats.opened,
        rsvp: stats.rsvpConfirmed,
        pending: stats.pending,
        declined: stats.rsvpDeclined,
        ticketsIssued: stats.ticketsIssued,
        totalInvited: guests.rows.length,
        awaitingResponse: stats.pending,
        accepted: stats.rsvpConfirmed,
        eligibleForCheckIn: stats.ticketsIssued,
      },
      items,
      guests: guests.rows.map((g) => ({
        id: g.id,
        name: g.name,
        email: g.email,
        rsvpStatus: g.rsvp_status,
        entitlementRef: g.entitlement_ref,
        ticketIssued: !!g.entitlement_ref,
        invitedAt: g.created_at.toISOString(),
        respondedAt:
          g.rsvp_status === 'confirmed' || g.rsvp_status === 'declined'
            ? g.updated_at.toISOString()
            : null,
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

  async rsvpByToken(
    tenantId: string,
    token: string,
    status: 'confirmed' | 'declined',
    actorUserId?: string,
  ) {
    return this.rsvpWithToken(tenantId, token, status, actorUserId);
  }

  async resendInvitation(actor: CommerceActor, eventKey: string, invitationId: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{ guest_id: string; channel: string }>(
      `SELECT guest_id, channel::text FROM event_invitations
       WHERE id = $1 AND tenant_id = $2 AND event_id = $3`,
      [invitationId, actor.tenantId, event.id],
    );
    if (!rows[0]) {
      throw new NotFoundException({ code: 'INVITATION_NOT_FOUND', message: 'Invitation not found' });
    }
    return this.sendInvitations(actor, eventKey, {
      guestIds: [rows[0].guest_id],
      channel: rows[0].channel === 'email' ? 'email' : 'link',
    });
  }

  async cancelInvitation(actor: CommerceActor, eventKey: string, invitationId: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{ guest_id: string }>(
      `UPDATE event_invitations
       SET status = 'failed',
           failed_at = now(),
           failure_reason = 'cancelled_by_organizer',
           updated_at = now()
       WHERE id = $1 AND tenant_id = $2 AND event_id = $3
       RETURNING guest_id`,
      [invitationId, actor.tenantId, event.id],
    );
    if (!rows[0]) {
      throw new NotFoundException({ code: 'INVITATION_NOT_FOUND', message: 'Invitation not found' });
    }
    await this.pool.query(
      `UPDATE event_invitation_tokens SET expires_at = now()
       WHERE invitation_id = $1 AND tenant_id = $2`,
      [invitationId, actor.tenantId],
    );
    return { ok: true as const, guestId: rows[0].guest_id };
  }

  async createInviteLink(actor: CommerceActor, eventKey: string, guestId: string) {
    const result = await this.sendInvitations(actor, eventKey, {
      guestIds: [guestId],
      channel: 'link',
    });
    return {
      inviteUrl: result.tokens[0]?.inviteUrl ?? null,
      sent: result.sent,
    };
  }

  /** Invite an existing platform user by userId (creates guest from profile if needed). */
  async inviteExistingUser(
    actor: CommerceActor,
    eventKey: string,
    userId: string,
    channel: string = 'email',
  ) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows: users } = await this.pool.query<{
      id: string;
      email: string | null;
      display_name: string | null;
    }>(
      `SELECT id, email, display_name FROM users WHERE id = $1 AND tenant_id = $2 LIMIT 1`,
      [userId, actor.tenantId],
    );
    const user = users[0];
    if (!user?.email) {
      throw new NotFoundException({ code: 'USER_NOT_FOUND', message: 'User not found or has no email' });
    }
    const email = user.email.trim().toLowerCase();
    const existing = await this.pool.query<{ id: string }>(
      `SELECT id FROM event_guests
       WHERE tenant_id = $1 AND event_id = $2 AND lower(email) = $3 LIMIT 1`,
      [actor.tenantId, event.id, email],
    );
    let guestId = existing.rows[0]?.id;
    if (!guestId) {
      const ins = await this.pool.query<{ id: string }>(
        `INSERT INTO event_guests (tenant_id, event_id, name, email, source)
         VALUES ($1, $2, $3, $4, 'user')
         RETURNING id`,
        [
          actor.tenantId,
          event.id,
          (user.display_name && user.display_name.trim()) || email.split('@')[0],
          email,
        ],
      );
      guestId = ins.rows[0]!.id;
    }
    return this.sendInvitations(actor, eventKey, { guestIds: [guestId], channel });
  }

  /** Attendee inbox: guest rows matching the signed-in user's email. */
  async listForAttendee(actor: CommerceActor) {
    const email = await this.resolveActorEmail(actor);
    if (!email) {
      return { items: [] as Array<Record<string, unknown>> };
    }
    // Claim pending entitlements for confirmed guests now that user is signed in.
    await this.claimPendingEntitlementsForUser(actor);

    const { rows } = await this.pool.query<{
      guest_id: string;
      event_id: string;
      name: string;
      email: string | null;
      rsvp_status: string;
      entitlement_ref: string | null;
      title: string;
      city: string | null;
      venue: string | null;
      starts_at: Date;
      ends_at: Date | null;
    }>(
      `SELECT g.id AS guest_id, g.event_id, g.name, g.email, g.rsvp_status::text, g.entitlement_ref,
              e.title, e.metadata->>'city' AS city, e.metadata->>'venue' AS venue,
              e.starts_at, e.ends_at
       FROM event_guests g
       INNER JOIN events e ON e.id = g.event_id
       WHERE g.tenant_id = $1 AND lower(g.email) = $2
       ORDER BY e.starts_at ASC
       LIMIT 100`,
      [actor.tenantId, email],
    );
    return {
      items: rows.map((r) => ({
        id: r.guest_id,
        guestId: r.guest_id,
        eventId: r.event_id,
        guestName: r.name,
        email: r.email,
        rsvpStatus: r.rsvp_status,
        entitlementRef: r.entitlement_ref,
        ticketIssued: !!r.entitlement_ref,
        eventTitle: r.title,
        eventCity: r.city ?? '',
        eventVenue: r.venue ?? '',
        startsAt: r.starts_at.toISOString(),
        endsAt: r.ends_at?.toISOString() ?? null,
        kind: 'rsvp',
      })),
    };
  }

  private async claimPendingEntitlementsForUser(actor: CommerceActor) {
    const email = await this.resolveActorEmail(actor);
    if (!email) return;
    const { rows } = await this.pool.query<{
      guest_id: string;
      event_id: string;
      organizer_id: string;
      guest_name: string;
      event_title: string;
    }>(
      `SELECT g.id AS guest_id, g.event_id, e.organizer_id, g.name AS guest_name, e.title AS event_title
       FROM event_guests g
       INNER JOIN events e ON e.id = g.event_id
       WHERE g.tenant_id = $1
         AND lower(g.email) = $2
         AND g.rsvp_status = 'confirmed'
         AND g.entitlement_ref IS NULL`,
      [actor.tenantId, email],
    );
    for (const row of rows) {
      const client = await this.pool.connect();
      try {
        await client.query('BEGIN');
        await issueInvitationEntitlement(client, {
          tenantId: actor.tenantId,
          eventId: row.event_id,
          organizerId: row.organizer_id,
          guestId: row.guest_id,
          holderUserId: actor.userId,
          guestName: row.guest_name,
          eventTitle: row.event_title,
        });
        await client.query('COMMIT');
      } catch {
        await client.query('ROLLBACK');
      } finally {
        client.release();
      }
    }
  }

  /** Authenticated RSVP — email ownership replaces invitation token. */
  async rsvpForAttendee(
    actor: CommerceActor,
    guestId: string,
    status: 'confirmed' | 'declined',
  ): Promise<{ ok: true; rsvpStatus: string; entitlementId?: string; ticketCode?: string }> {
    if (!['confirmed', 'declined'].includes(status)) {
      throw new BadRequestException({
        code: 'INVALID_RSVP',
        message: 'RSVP status must be confirmed or declined',
      });
    }
    const email = await this.resolveActorEmail(actor);
    if (!email) {
      throw new BadRequestException({
        code: 'EMAIL_REQUIRED',
        message: 'Account email required to respond to invitations',
      });
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query<{
        id: string;
        event_id: string;
        name: string;
        organizer_id: string;
        event_title: string;
      }>(
        `SELECT g.id, g.event_id, g.name, e.organizer_id, e.title AS event_title
         FROM event_guests g
         INNER JOIN events e ON e.id = g.event_id
         WHERE g.id = $1 AND g.tenant_id = $2 AND lower(g.email) = $3
         FOR UPDATE OF g`,
        [guestId, actor.tenantId, email],
      );
      if (!rows[0]) {
        throw new NotFoundException({ code: 'INVITATION_NOT_FOUND', message: 'Invitation not found' });
      }
      const row = rows[0];
      await client.query(
        `UPDATE event_guests SET rsvp_status = $3::event_guest_rsvp_status, updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [actor.tenantId, guestId, status],
      );

      let entitlementId: string | undefined;
      let ticketCode: string | undefined;
      if (status === 'confirmed') {
        const issued = await issueInvitationEntitlement(client, {
          tenantId: actor.tenantId,
          eventId: row.event_id,
          organizerId: row.organizer_id,
          guestId: row.id,
          holderUserId: actor.userId,
          guestName: row.name,
          eventTitle: row.event_title,
        });
        entitlementId = issued?.entitlementId;
        ticketCode = issued?.ticketCode;
        await this.notifyOrganizerRsvp(
          client,
          actor.tenantId,
          row.organizer_id,
          row.event_title,
          row.name,
          'accepted',
        );
      } else {
        await this.notifyOrganizerRsvp(
          client,
          actor.tenantId,
          row.organizer_id,
          row.event_title,
          row.name,
          'declined',
        );
      }

      await client.query('COMMIT');
      this.metrics.inc('rsvp_total', { status });
      this.emitRsvpChanged({
        tenantId: actor.tenantId,
        organizerId: row.organizer_id,
        eventId: row.event_id,
        guestId: row.id,
        guestName: row.name,
        eventTitle: row.event_title,
        status,
        actorUserId: actor.userId,
      });
      return { ok: true, rsvpStatus: status, entitlementId, ticketCode };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  private async resolveActorEmail(actor: CommerceActor): Promise<string | null> {
    if (actor.email && actor.email.includes('@')) {
      return actor.email.trim().toLowerCase();
    }
    const { rows } = await this.pool.query<{ email: string }>(
      `SELECT email FROM users WHERE id = $1 AND tenant_id = $2 LIMIT 1`,
      [actor.userId, actor.tenantId],
    );
    const email = rows[0]?.email?.trim().toLowerCase();
    return email && email.includes('@') ? email : null;
  }
}
