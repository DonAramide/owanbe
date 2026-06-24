import { BadRequestException, Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';
import { RealtimeBroadcastService } from '../../integrations/realtime/realtime-broadcast.service';

export const WALL_REACTIONS = ['heart', 'celebrate', 'cheers', 'fire'] as const;
export type WallReactionType = (typeof WALL_REACTIONS)[number];

export type WallPostView = {
  id: string;
  guestName: string;
  message: string;
  photoUrl: string | null;
  status: 'visible' | 'hidden' | 'deleted';
  pinned: boolean;
  reactions: Record<WallReactionType, number>;
  createdAt: string;
  pinnedAt: string | null;
};

export type WallSettingsView = {
  liveMode: boolean;
};

@Injectable()
export class CelebrationWallService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly realtime: RealtimeBroadcastService,
  ) {}

  private emptyReactions(): Record<WallReactionType, number> {
    return { heart: 0, celebrate: 0, cheers: 0, fire: 0 };
  }

  private parseReactions(raw: unknown): Record<WallReactionType, number> {
    const base = this.emptyReactions();
    if (!raw || typeof raw !== 'object') return base;
    for (const key of WALL_REACTIONS) {
      const v = (raw as Record<string, unknown>)[key];
      if (typeof v === 'number') base[key] = v;
    }
    return base;
  }

  private rowToPost(row: {
    id: string;
    guest_name: string;
    message: string;
    photo_url: string | null;
    status: string;
    pinned: boolean;
    reactions: unknown;
    created_at: Date;
    pinned_at: Date | null;
  }): WallPostView {
    return {
      id: row.id,
      guestName: row.guest_name,
      message: row.message,
      photoUrl: row.photo_url,
      status: row.status as WallPostView['status'],
      pinned: row.pinned,
      reactions: this.parseReactions(row.reactions),
      createdAt: row.created_at.toISOString(),
      pinnedAt: row.pinned_at?.toISOString() ?? null,
    };
  }

  private async ensureSettings(tenantId: string, eventId: string) {
    await this.pool.query(
      `INSERT INTO event_wall_settings (tenant_id, event_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [tenantId, eventId],
    );
  }

  private async writeFeed(
    tenantId: string,
    eventId: string,
    feedType: string,
    headline: string,
    detail: string,
  ) {
    await this.pool.query(
      `INSERT INTO event_feed_items (tenant_id, event_id, feed_type, headline, detail)
       VALUES ($1, $2, $3, $4, $5)`,
      [tenantId, eventId, feedType, headline, detail],
    );
    this.realtime.publish({
      tenantId,
      eventId,
      feedType,
      headline,
      detail,
      timestamp: new Date().toISOString(),
    });
  }

  async getSettings(tenantId: string, eventKey: string): Promise<WallSettingsView> {
    const event = await this.access.resolveEventRow(tenantId, eventKey, true);
    await this.ensureSettings(tenantId, event.id);
    const { rows } = await this.pool.query<{ live_mode: boolean }>(
      `SELECT live_mode FROM event_wall_settings WHERE tenant_id = $1 AND event_id = $2`,
      [tenantId, event.id],
    );
    return { liveMode: rows[0]?.live_mode ?? true };
  }

  async patchSettings(actor: CommerceActor, eventKey: string, liveMode: boolean): Promise<WallSettingsView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    await this.ensureSettings(actor.tenantId, event.id);
    await this.pool.query(
      `UPDATE event_wall_settings SET live_mode = $3, updated_at = now()
       WHERE tenant_id = $1 AND event_id = $2`,
      [actor.tenantId, event.id, liveMode],
    );
    return { liveMode };
  }

  async listPublic(tenantId: string, eventKey: string, includeHidden = false): Promise<{ settings: WallSettingsView; items: WallPostView[] }> {
    const event = await this.access.resolveEventRow(tenantId, eventKey, true);
    const settings = await this.getSettings(tenantId, eventKey);
    const statusFilter = includeHidden ? `status IN ('visible', 'hidden')` : `status = 'visible'`;
    const { rows } = await this.pool.query<{
      id: string;
      guest_name: string;
      message: string;
      photo_url: string | null;
      status: string;
      pinned: boolean;
      reactions: unknown;
      created_at: Date;
      pinned_at: Date | null;
    }>(
      `SELECT id, guest_name, message, photo_url, status, pinned, reactions, created_at, pinned_at
       FROM event_wall_posts
       WHERE tenant_id = $1 AND event_id = $2 AND ${statusFilter}
       ORDER BY pinned DESC, pinned_at DESC NULLS LAST, created_at DESC
       LIMIT 200`,
      [tenantId, event.id],
    );
    return { settings, items: rows.map((r) => this.rowToPost(r)) };
  }

  async listForOrganizer(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      id: string;
      guest_name: string;
      message: string;
      photo_url: string | null;
      status: string;
      pinned: boolean;
      reactions: unknown;
      created_at: Date;
      pinned_at: Date | null;
    }>(
      `SELECT id, guest_name, message, photo_url, status, pinned, reactions, created_at, pinned_at
       FROM event_wall_posts
       WHERE tenant_id = $1 AND event_id = $2 AND status <> 'deleted'
       ORDER BY pinned DESC, pinned_at DESC NULLS LAST, created_at DESC
       LIMIT 200`,
      [actor.tenantId, event.id],
    );
    const settings = await this.getSettings(actor.tenantId, eventKey);
    return { settings, items: rows.map((r) => this.rowToPost(r)) };
  }

  async createPost(
    tenantId: string,
    eventKey: string,
    body: { guestName?: string; message?: string; photoUrl?: string },
  ): Promise<WallPostView> {
    const event = await this.access.resolveEventRow(tenantId, eventKey, true);
    const guestName = String(body.guestName ?? '').trim();
    const message = String(body.message ?? '').trim();
    if (!guestName || guestName.length < 2) {
      throw new BadRequestException({ code: 'INVALID_GUEST', message: 'Guest name is required' });
    }
    if (!message || message.length < 2) {
      throw new BadRequestException({ code: 'INVALID_MESSAGE', message: 'Message is required' });
    }
    if (message.length > 2000) {
      throw new BadRequestException({ code: 'MESSAGE_TOO_LONG', message: 'Message too long' });
    }

    const { rows } = await this.pool.query<{
      id: string;
      guest_name: string;
      message: string;
      photo_url: string | null;
      status: string;
      pinned: boolean;
      reactions: unknown;
      created_at: Date;
      pinned_at: Date | null;
    }>(
      `INSERT INTO event_wall_posts (tenant_id, event_id, guest_name, message, photo_url)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, guest_name, message, photo_url, status, pinned, reactions, created_at, pinned_at`,
      [tenantId, event.id, guestName, message, body.photoUrl?.trim() || null],
    );

    const post = this.rowToPost(rows[0]!);
    const preview = message.length > 80 ? `${message.slice(0, 77)}…` : message;
    await this.writeFeed(
      tenantId,
      event.id,
      'wall_post',
      `${guestName} posted on the celebration wall`,
      preview,
    );
    return post;
  }

  async addReaction(tenantId: string, eventKey: string, postId: string, reaction: string): Promise<WallPostView> {
    if (!WALL_REACTIONS.includes(reaction as WallReactionType)) {
      throw new BadRequestException({ code: 'INVALID_REACTION', message: 'Unknown reaction' });
    }
    const event = await this.access.resolveEventRow(tenantId, eventKey, true);
    const key = reaction as WallReactionType;
    const { rows } = await this.pool.query<{
      id: string;
      guest_name: string;
      message: string;
      photo_url: string | null;
      status: string;
      pinned: boolean;
      reactions: unknown;
      created_at: Date;
      pinned_at: Date | null;
    }>(
      `UPDATE event_wall_posts
       SET reactions = jsonb_set(
         COALESCE(reactions, '{}'::jsonb),
         ARRAY[$4],
         to_jsonb(COALESCE((reactions->>$4)::int, 0) + 1)
       ),
       updated_at = now()
       WHERE tenant_id = $1 AND event_id = $2 AND id = $3::uuid AND status = 'visible'
       RETURNING id, guest_name, message, photo_url, status, pinned, reactions, created_at, pinned_at`,
      [tenantId, event.id, postId, key],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'POST_NOT_FOUND', message: 'Wall post not found' });
    }
    return this.rowToPost(row);
  }

  async moderate(
    actor: CommerceActor,
    eventKey: string,
    postId: string,
    action: 'hide' | 'delete' | 'pin' | 'unpin' | 'show',
  ): Promise<WallPostView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);

    let sql: string;
    if (action === 'hide') {
      sql = `UPDATE event_wall_posts SET status = 'hidden', moderated_by = $4, moderated_at = now(), updated_at = now()`;
    } else if (action === 'show') {
      sql = `UPDATE event_wall_posts SET status = 'visible', moderated_by = $4, moderated_at = now(), updated_at = now()`;
    } else if (action === 'delete') {
      sql = `UPDATE event_wall_posts SET status = 'deleted', pinned = false, pinned_at = NULL, moderated_by = $4, moderated_at = now(), updated_at = now()`;
    } else if (action === 'pin') {
      sql = `UPDATE event_wall_posts SET pinned = true, pinned_at = now(), status = 'visible', moderated_by = $4, moderated_at = now(), updated_at = now()`;
    } else {
      sql = `UPDATE event_wall_posts SET pinned = false, pinned_at = NULL, moderated_by = $4, moderated_at = now(), updated_at = now()`;
    }

    const { rows } = await this.pool.query<{
      id: string;
      guest_name: string;
      message: string;
      photo_url: string | null;
      status: string;
      pinned: boolean;
      reactions: unknown;
      created_at: Date;
      pinned_at: Date | null;
    }>(
      `${sql}
       WHERE tenant_id = $1 AND event_id = $2 AND id = $3::uuid AND status <> 'deleted'
       RETURNING id, guest_name, message, photo_url, status, pinned, reactions, created_at, pinned_at`,
      [actor.tenantId, event.id, postId, actor.userId],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'POST_NOT_FOUND', message: 'Wall post not found' });
    }

    if (action === 'pin') {
      await this.writeFeed(
        actor.tenantId,
        event.id,
        'wall_pinned',
        `Pinned: ${row.guest_name}`,
        row.message.length > 80 ? `${row.message.slice(0, 77)}…` : row.message,
      );
    }

    return this.rowToPost(row);
  }

  async recentForTimeline(tenantId: string, eventId: string, limit = 10): Promise<WallPostView[]> {
    const { rows } = await this.pool.query<{
      id: string;
      guest_name: string;
      message: string;
      photo_url: string | null;
      status: string;
      pinned: boolean;
      reactions: unknown;
      created_at: Date;
      pinned_at: Date | null;
    }>(
      `SELECT id, guest_name, message, photo_url, status, pinned, reactions, created_at, pinned_at
       FROM event_wall_posts
       WHERE tenant_id = $1 AND event_id = $2 AND status = 'visible'
       ORDER BY created_at DESC LIMIT $3`,
      [tenantId, eventId, limit],
    );
    return rows.map((r) => this.rowToPost(r));
  }
}
