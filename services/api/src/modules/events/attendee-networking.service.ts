import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Inject,
  NotFoundException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';

export type ConnectionStatusView = 'none' | 'pending_outgoing' | 'pending_incoming' | 'connected' | 'declined';

export type DirectoryPersonView = {
  userId: string;
  displayName: string;
  avatarUrl: string | null;
  company: string | null;
  occupation: string | null;
  interests: string[];
  mutualInterests: string[];
  ticketTierName: string | null;
  connectionStatus: ConnectionStatusView;
  connectionId: string | null;
  isSelf: boolean;
};

@Injectable()
export class AttendeeNetworkingService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  async listPeople(
    actor: CommerceActor,
    eventKey: string,
    query: { q?: string; company?: string; interest?: string },
  ) {
    const event = await this.access.resolveEventRow(actor.tenantId, eventKey, true);
    await this.assertViewerAttends(actor, event.id);

    const q = query.q?.trim().toLowerCase() ?? '';
    const company = query.company?.trim().toLowerCase() ?? '';
    const interest = query.interest?.trim().toLowerCase() ?? '';

    const { rows } = await this.pool.query<{
      user_id: string;
      display_name: string | null;
      preferred_display_name: string | null;
      first_name: string | null;
      last_name: string | null;
      avatar_url: string | null;
      company: string | null;
      occupation: string | null;
      interests: unknown;
      attendee_interests: unknown;
      tier_name: string | null;
      privacy_show_to_attendees: boolean | null;
    }>(
      `SELECT DISTINCT ON (u.id)
              u.id AS user_id,
              u.display_name,
              u.first_name,
              u.last_name,
              u.avatar_url,
              u.company,
              u.occupation,
              u.interests,
              ap.preferred_display_name,
              ap.interests AS attendee_interests,
              ap.privacy_show_to_attendees,
              COALESCE(te.metadata->>'tier_name', 'Ticket') AS tier_name
       FROM ticket_entitlements te
       INNER JOIN users u ON u.id = te.holder_user_id AND u.tenant_id = te.tenant_id
       LEFT JOIN attendee_profiles ap ON ap.user_id = u.id AND ap.tenant_id = te.tenant_id
       WHERE te.tenant_id = $1
         AND te.event_id = $2
         AND te.status IN ('issued', 'checked_in')
         AND (
           u.id = $3
           OR COALESCE(ap.privacy_show_to_attendees, false) = true
         )
       ORDER BY u.id, te.issued_at DESC`,
      [actor.tenantId, event.id, actor.userId],
    );

    const viewerInterests = await this.loadViewerInterests(actor.tenantId, actor.userId);
    const connections = await this.loadConnectionMap(actor.tenantId, event.id, actor.userId);

    let people: DirectoryPersonView[] = rows.map((r) => {
      const interests = this.mergeInterests(r.attendee_interests, r.interests);
      const displayName =
        r.preferred_display_name?.trim() ||
        r.display_name?.trim() ||
        [r.first_name, r.last_name].filter(Boolean).join(' ').trim() ||
        'Attendee';
      const mutual = interests.filter((i) =>
        viewerInterests.some((v) => v.toLowerCase() === i.toLowerCase()),
      );
      const link = connections.get(r.user_id);
      return {
        userId: r.user_id,
        displayName,
        avatarUrl: r.avatar_url,
        company: r.company,
        occupation: r.occupation,
        interests,
        mutualInterests: mutual,
        ticketTierName: r.tier_name,
        connectionStatus: link?.status ?? 'none',
        connectionId: link?.id ?? null,
        isSelf: r.user_id === actor.userId,
      };
    });

    if (q) {
      people = people.filter((p) => {
        const hay = `${p.displayName} ${p.company ?? ''} ${p.occupation ?? ''} ${p.interests.join(' ')}`.toLowerCase();
        return hay.includes(q);
      });
    }
    if (company) {
      people = people.filter((p) => (p.company ?? '').toLowerCase().includes(company));
    }
    if (interest) {
      people = people.filter((p) => p.interests.some((i) => i.toLowerCase().includes(interest)));
    }

    people.sort((a, b) => a.displayName.localeCompare(b.displayName));
    return { items: people, eventId: event.id };
  }

  async suggestions(actor: CommerceActor, eventKey: string) {
    const { items } = await this.listPeople(actor, eventKey, {});
    const others = items.filter((p) => !p.isSelf && p.connectionStatus !== 'connected');
    const scored = others
      .map((p) => {
        let score = 0;
        score += p.mutualInterests.length * 3;
        score += p.connectionStatus === 'pending_incoming' ? 5 : 0;
        const viewerTier = items.find((x) => x.isSelf)?.ticketTierName?.toLowerCase();
        if (viewerTier && p.ticketTierName?.toLowerCase() === viewerTier) score += 2;
        return { person: p, score };
      })
      .sort((a, b) => b.score - a.score || a.person.displayName.localeCompare(b.person.displayName));

    // Same company boost among remaining
    const viewer = items.find((p) => p.isSelf);
    const company = viewer?.company?.trim().toLowerCase();
    if (company) {
      scored.sort((a, b) => {
        const ac = (a.person.company ?? '').toLowerCase() === company ? 1 : 0;
        const bc = (b.person.company ?? '').toLowerCase() === company ? 1 : 0;
        if (ac !== bc) return bc - ac;
        return b.score - a.score;
      });
    }

    return { items: scored.slice(0, 12).map((s) => s.person) };
  }

  async listConnections(actor: CommerceActor, eventKey: string) {
    const event = await this.access.resolveEventRow(actor.tenantId, eventKey, true);
    await this.assertViewerAttends(actor, event.id);
    const { rows } = await this.pool.query<{
      id: string;
      status: string;
      requester_user_id: string;
      recipient_user_id: string;
      created_at: Date;
      other_id: string;
      display_name: string | null;
      preferred_display_name: string | null;
      avatar_url: string | null;
      company: string | null;
    }>(
      `SELECT c.id, c.status, c.requester_user_id, c.recipient_user_id, c.created_at,
              CASE WHEN c.requester_user_id = $3 THEN c.recipient_user_id ELSE c.requester_user_id END AS other_id,
              u.display_name, ap.preferred_display_name, u.avatar_url, u.company
       FROM event_attendee_connections c
       INNER JOIN users u ON u.id = CASE
         WHEN c.requester_user_id = $3 THEN c.recipient_user_id ELSE c.requester_user_id END
       LEFT JOIN attendee_profiles ap ON ap.user_id = u.id AND ap.tenant_id = c.tenant_id
       WHERE c.tenant_id = $1 AND c.event_id = $2
         AND (c.requester_user_id = $3 OR c.recipient_user_id = $3)
       ORDER BY c.updated_at DESC`,
      [actor.tenantId, event.id, actor.userId],
    );

    return {
      items: rows.map((r) => {
        const isRequester = r.requester_user_id === actor.userId;
        let connectionStatus: ConnectionStatusView = 'none';
        if (r.status === 'accepted') connectionStatus = 'connected';
        else if (r.status === 'declined') connectionStatus = 'declined';
        else connectionStatus = isRequester ? 'pending_outgoing' : 'pending_incoming';
        return {
          id: r.id,
          otherUserId: r.other_id,
          displayName:
            r.preferred_display_name?.trim() || r.display_name?.trim() || 'Attendee',
          avatarUrl: r.avatar_url,
          company: r.company,
          status: r.status,
          connectionStatus,
          createdAt: r.created_at.toISOString(),
        };
      }),
    };
  }

  async requestConnection(actor: CommerceActor, eventKey: string, recipientUserId: string) {
    const event = await this.access.resolveEventRow(actor.tenantId, eventKey, true);
    await this.assertViewerAttends(actor, event.id);
    if (recipientUserId === actor.userId) {
      throw new BadRequestException({ code: 'INVALID', message: 'Cannot connect to yourself' });
    }
    await this.assertUserOptedInAndAttends(actor.tenantId, event.id, recipientUserId);

    const existing = await this.findPair(actor.tenantId, event.id, actor.userId, recipientUserId);
    if (existing) {
      if (existing.status === 'accepted') {
        throw new ConflictException({ code: 'ALREADY_CONNECTED', message: 'Already connected' });
      }
      if (existing.status === 'pending') {
        throw new ConflictException({ code: 'PENDING', message: 'Connection already pending' });
      }
      // declined → allow re-request by updating
      await this.pool.query(
        `UPDATE event_attendee_connections
         SET requester_user_id = $1, recipient_user_id = $2, status = 'pending', updated_at = now()
         WHERE id = $3`,
        [actor.userId, recipientUserId, existing.id],
      );
      await this.notify(
        actor.tenantId,
        recipientUserId,
        'connection_request',
        'New connection request',
        'Someone wants to connect with you at this event.',
        { eventId: event.id, connectionId: existing.id, fromUserId: actor.userId },
      );
      return { id: existing.id, status: 'pending' };
    }

    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO event_attendee_connections
         (tenant_id, event_id, requester_user_id, recipient_user_id, status)
       VALUES ($1, $2, $3, $4, 'pending')
       RETURNING id`,
      [actor.tenantId, event.id, actor.userId, recipientUserId],
    );
    const id = rows[0]!.id;
    await this.notify(
      actor.tenantId,
      recipientUserId,
      'connection_request',
      'New connection request',
      'Someone wants to connect with you at this event.',
      { eventId: event.id, connectionId: id, fromUserId: actor.userId },
    );
    return { id, status: 'pending' };
  }

  async acceptConnection(actor: CommerceActor, connectionId: string) {
    const row = await this.getConnection(actor.tenantId, connectionId);
    if (row.recipient_user_id !== actor.userId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'Only the recipient can accept' });
    }
    if (row.status !== 'pending') {
      throw new BadRequestException({ code: 'INVALID_STATE', message: `Status is ${row.status}` });
    }
    await this.pool.query(
      `UPDATE event_attendee_connections SET status = 'accepted', updated_at = now() WHERE id = $1`,
      [connectionId],
    );
    await this.notify(
      actor.tenantId,
      row.requester_user_id,
      'connection_accepted',
      'Connection accepted',
      'Your connection request was accepted.',
      { eventId: row.event_id, connectionId, fromUserId: actor.userId },
    );
    return { id: connectionId, status: 'accepted' };
  }

  async declineConnection(actor: CommerceActor, connectionId: string) {
    const row = await this.getConnection(actor.tenantId, connectionId);
    if (row.recipient_user_id !== actor.userId && row.requester_user_id !== actor.userId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'Not your connection' });
    }
    await this.pool.query(
      `UPDATE event_attendee_connections SET status = 'declined', updated_at = now() WHERE id = $1`,
      [connectionId],
    );
    return { id: connectionId, status: 'declined' };
  }

  async removeConnection(actor: CommerceActor, connectionId: string) {
    const row = await this.getConnection(actor.tenantId, connectionId);
    if (row.recipient_user_id !== actor.userId && row.requester_user_id !== actor.userId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'Not your connection' });
    }
    await this.pool.query(`DELETE FROM event_attendee_connections WHERE id = $1`, [connectionId]);
    return { ok: true };
  }

  async businessCard(actor: CommerceActor) {
    const { rows } = await this.pool.query<{
      id: string;
      email: string;
      phone_e164: string | null;
      display_name: string | null;
      first_name: string | null;
      last_name: string | null;
      avatar_url: string | null;
      bio: string | null;
      company: string | null;
      occupation: string | null;
      social_links: unknown;
      preferred_display_name: string | null;
      interests: unknown;
      attendee_interests: unknown;
    }>(
      `SELECT u.id, u.email, u.phone_e164, u.display_name, u.first_name, u.last_name,
              u.avatar_url, u.bio, u.company, u.occupation, u.social_links,
              ap.preferred_display_name, u.interests, ap.interests AS attendee_interests
       FROM users u
       LEFT JOIN attendee_profiles ap ON ap.user_id = u.id AND ap.tenant_id = u.tenant_id
       WHERE u.id = $1 AND u.tenant_id = $2`,
      [actor.userId, actor.tenantId],
    );
    const r = rows[0];
    if (!r) throw new NotFoundException({ code: 'NOT_FOUND', message: 'User not found' });
    const displayName =
      r.preferred_display_name?.trim() ||
      r.display_name?.trim() ||
      [r.first_name, r.last_name].filter(Boolean).join(' ').trim() ||
      'Attendee';
    const socialLinks = this.parseSocialLinks(r.social_links);
    const payload = [
      'BEGIN:VCARD',
      'VERSION:3.0',
      `FN:${displayName}`,
      r.company ? `ORG:${r.company}` : null,
      r.occupation ? `TITLE:${r.occupation}` : null,
      `EMAIL:${r.email}`,
      r.phone_e164 ? `TEL:${r.phone_e164}` : null,
      'END:VCARD',
    ]
      .filter(Boolean)
      .join('\n');

    return {
      userId: r.id,
      displayName,
      avatarUrl: r.avatar_url,
      bio: r.bio,
      company: r.company,
      occupation: r.occupation,
      email: r.email,
      phone: r.phone_e164,
      socialLinks,
      interests: this.mergeInterests(r.attendee_interests, r.interests),
      qrPayload: payload,
      shareText: [
        displayName,
        [r.occupation, r.company].filter(Boolean).join(' · '),
        r.email,
        r.phone_e164,
        ...Object.entries(socialLinks).map(([k, v]) => `${k}: ${v}`),
      ]
        .filter((s) => (s ?? '').toString().trim().length > 0)
        .join('\n'),
    };
  }

  async listMyNetworkingNotifications(actor: CommerceActor) {
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
           'connection_request', 'connection_accepted', 'profile_shared',
           'business_card_shared', 'community_activity'
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

  async notifyShare(
    actor: CommerceActor,
    body: { kind: 'profile_shared' | 'business_card_shared'; recipientUserId: string; eventId?: string },
  ) {
    await this.notify(
      actor.tenantId,
      body.recipientUserId,
      body.kind,
      body.kind === 'business_card_shared' ? 'Business card shared' : 'Profile shared',
      'An attendee shared their card with you.',
      { fromUserId: actor.userId, eventId: body.eventId },
    );
    return { ok: true };
  }

  private async assertViewerAttends(actor: CommerceActor, eventId: string) {
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
        message: 'You need a ticket for this event to use networking',
      });
    }
  }

  private async assertUserOptedInAndAttends(tenantId: string, eventId: string, userId: string) {
    const { rows } = await this.pool.query(
      `SELECT 1
       FROM ticket_entitlements te
       LEFT JOIN attendee_profiles ap ON ap.user_id = te.holder_user_id AND ap.tenant_id = te.tenant_id
       WHERE te.tenant_id = $1 AND te.event_id = $2 AND te.holder_user_id = $3
         AND te.status IN ('issued', 'checked_in')
         AND COALESCE(ap.privacy_show_to_attendees, false) = true
       LIMIT 1`,
      [tenantId, eventId, userId],
    );
    if (!rows.length) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'Attendee not available to connect' });
    }
  }

  private async loadViewerInterests(tenantId: string, userId: string): Promise<string[]> {
    const { rows } = await this.pool.query<{ interests: unknown; attendee_interests: unknown }>(
      `SELECT u.interests, ap.interests AS attendee_interests
       FROM users u
       LEFT JOIN attendee_profiles ap ON ap.user_id = u.id AND ap.tenant_id = u.tenant_id
       WHERE u.id = $1 AND u.tenant_id = $2`,
      [userId, tenantId],
    );
    if (!rows[0]) return [];
    return this.mergeInterests(rows[0].attendee_interests, rows[0].interests);
  }

  private async loadConnectionMap(
    tenantId: string,
    eventId: string,
    viewerId: string,
  ): Promise<Map<string, { status: ConnectionStatusView; id: string }>> {
    const { rows } = await this.pool.query<{
      id: string;
      status: string;
      requester_user_id: string;
      recipient_user_id: string;
    }>(
      `SELECT id, status, requester_user_id, recipient_user_id
       FROM event_attendee_connections
       WHERE tenant_id = $1 AND event_id = $2
         AND (requester_user_id = $3 OR recipient_user_id = $3)`,
      [tenantId, eventId, viewerId],
    );
    const map = new Map<string, { status: ConnectionStatusView; id: string }>();
    for (const r of rows) {
      const other = r.requester_user_id === viewerId ? r.recipient_user_id : r.requester_user_id;
      let status: ConnectionStatusView = 'none';
      if (r.status === 'accepted') status = 'connected';
      else if (r.status === 'declined') status = 'declined';
      else if (r.requester_user_id === viewerId) status = 'pending_outgoing';
      else status = 'pending_incoming';
      map.set(other, { status, id: r.id });
    }
    return map;
  }

  private async findPair(tenantId: string, eventId: string, a: string, b: string) {
    const { rows } = await this.pool.query<{
      id: string;
      status: string;
      requester_user_id: string;
      recipient_user_id: string;
    }>(
      `SELECT id, status, requester_user_id, recipient_user_id
       FROM event_attendee_connections
       WHERE tenant_id = $1 AND event_id = $2
         AND (
           (requester_user_id = $3 AND recipient_user_id = $4)
           OR (requester_user_id = $4 AND recipient_user_id = $3)
         )
       LIMIT 1`,
      [tenantId, eventId, a, b],
    );
    return rows[0] ?? null;
  }

  private async getConnection(tenantId: string, connectionId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      event_id: string;
      status: string;
      requester_user_id: string;
      recipient_user_id: string;
    }>(
      `SELECT id, event_id, status, requester_user_id, recipient_user_id
       FROM event_attendee_connections WHERE tenant_id = $1 AND id = $2`,
      [tenantId, connectionId],
    );
    if (!rows[0]) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Connection not found' });
    return rows[0];
  }

  private async notify(
    tenantId: string,
    userId: string,
    kind: string,
    title: string,
    body: string,
    data: Record<string, unknown>,
  ) {
    const dedupe = `${kind}:${data.connectionId ?? data.fromUserId ?? ''}:${Date.now()}`;
    await this.pool.query(
      `INSERT INTO notifications (tenant_id, user_id, channel, status, kind, title, body, data, dedupe_key, sent_at)
       VALUES ($1, $2, 'in_app', 'delivered', $3, $4, $5, $6::jsonb, $7, now())
       ON CONFLICT (tenant_id, user_id, dedupe_key) DO NOTHING`,
      [tenantId, userId, kind, title, body, JSON.stringify(data), dedupe],
    );
  }

  private mergeInterests(a: unknown, b: unknown): string[] {
    const out = new Set<string>();
    for (const list of [a, b]) {
      if (Array.isArray(list)) {
        for (const e of list) {
          const s = String(e).trim();
          if (s) out.add(s);
        }
      }
    }
    return [...out];
  }

  private parseSocialLinks(raw: unknown): Record<string, string> {
    if (!raw || typeof raw !== 'object') return {};
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(raw as Record<string, unknown>)) {
      const s = v != null ? String(v).trim() : '';
      if (s) out[k] = s;
    }
    return out;
  }
}
