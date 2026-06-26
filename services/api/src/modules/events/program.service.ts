import {
  BadRequestException,
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';

export const PROGRAM_STATUSES = [
  'planned',
  'ready',
  'in_progress',
  'completed',
  'skipped',
  'delayed',
] as const;
export type ProgramStatus = (typeof PROGRAM_STATUSES)[number];

export const PROGRAM_OWNER_TYPES = ['mc', 'bride', 'groom', 'planner', 'coordinator', 'vendor'] as const;
export type ProgramOwnerType = (typeof PROGRAM_OWNER_TYPES)[number];

export const PROGRAM_TEMPLATES = ['wedding', 'birthday', 'corporate', 'naming_ceremony'] as const;
export type ProgramTemplateKey = (typeof PROGRAM_TEMPLATES)[number];

export const PROGRAM_ACTIVITY_KINDS = [
  'program_created',
  'program_updated',
  'program_started',
  'program_completed',
  'program_delayed',
  'program_reminder',
] as const;
export type ProgramActivityKind = (typeof PROGRAM_ACTIVITY_KINDS)[number];

export type ProgramItemView = {
  id: string;
  title: string;
  description: string;
  startTime: string;
  endTime: string;
  durationMinutes: number;
  ownerType: ProgramOwnerType;
  ownerId: string | null;
  ownerName: string;
  vendorId: string | null;
  status: ProgramStatus;
  sortOrder: number;
};

export type ProgramDaySnapshot = {
  current: ProgramItemView | null;
  next: ProgramItemView | null;
  countdownSeconds: number | null;
  countdownLabel: string | null;
};

export type ProgramActivityView = {
  id: string;
  activityKind: ProgramActivityKind;
  headline: string;
  detail: string;
  programItemId: string | null;
  createdAt: string;
};

export type ProgramView = {
  items: ProgramItemView[];
  day: ProgramDaySnapshot;
  recentActivity: ProgramActivityView[];
};

type TemplateSeed = {
  title: string;
  description: string;
  offsetMinutes: number;
  durationMinutes: number;
  ownerType: ProgramOwnerType;
  ownerName: string;
};

const TEMPLATE_SEEDS: Record<ProgramTemplateKey, TemplateSeed[]> = {
  wedding: [
    { title: 'Guest arrival & seating', description: 'Ushers seat guests', offsetMinutes: -90, durationMinutes: 60, ownerType: 'coordinator', ownerName: 'Coordinator' },
    { title: 'Opening prayer', description: 'Traditional opening', offsetMinutes: -30, durationMinutes: 10, ownerType: 'mc', ownerName: 'MC' },
    { title: 'Entrance of the couple', description: 'Grand entrance', offsetMinutes: 0, durationMinutes: 15, ownerType: 'bride', ownerName: 'Couple' },
    { title: 'Cake cutting', description: 'Cake ceremony', offsetMinutes: 45, durationMinutes: 15, ownerType: 'bride', ownerName: 'Couple' },
    { title: 'First dance', description: 'Couple dance', offsetMinutes: 65, durationMinutes: 10, ownerType: 'bride', ownerName: 'Couple' },
    { title: 'Thank you & closing', description: 'MC closing remarks', offsetMinutes: 120, durationMinutes: 10, ownerType: 'mc', ownerName: 'MC' },
  ],
  birthday: [
    { title: 'Guest arrival', description: 'Welcome drinks', offsetMinutes: -60, durationMinutes: 45, ownerType: 'coordinator', ownerName: 'Coordinator' },
    { title: 'Birthday entrance', description: 'Celebrant entrance', offsetMinutes: 0, durationMinutes: 10, ownerType: 'planner', ownerName: 'Celebrant' },
    { title: 'Cake cutting', description: 'Happy birthday moment', offsetMinutes: 30, durationMinutes: 15, ownerType: 'planner', ownerName: 'Celebrant' },
    { title: 'Games & dance', description: 'Party segment', offsetMinutes: 50, durationMinutes: 60, ownerType: 'mc', ownerName: 'MC' },
    { title: 'Closing toast', description: 'Thank guests', offsetMinutes: 120, durationMinutes: 10, ownerType: 'mc', ownerName: 'MC' },
  ],
  corporate: [
    { title: 'Registration & networking', description: 'Badge pickup', offsetMinutes: -45, durationMinutes: 45, ownerType: 'coordinator', ownerName: 'Events team' },
    { title: 'Welcome remarks', description: 'Host opening', offsetMinutes: 0, durationMinutes: 10, ownerType: 'mc', ownerName: 'Host' },
    { title: 'Keynote address', description: 'Main presentation', offsetMinutes: 15, durationMinutes: 45, ownerType: 'planner', ownerName: 'Speaker' },
    { title: 'Panel discussion', description: 'Q&A session', offsetMinutes: 65, durationMinutes: 40, ownerType: 'mc', ownerName: 'Moderator' },
    { title: 'Closing & departures', description: 'Wrap-up', offsetMinutes: 110, durationMinutes: 15, ownerType: 'coordinator', ownerName: 'Events team' },
  ],
  naming_ceremony: [
    { title: 'Family gathering', description: 'Close family arrives', offsetMinutes: -60, durationMinutes: 45, ownerType: 'coordinator', ownerName: 'Family elder' },
    { title: 'Opening prayers', description: 'Traditional prayers', offsetMinutes: -15, durationMinutes: 15, ownerType: 'mc', ownerName: 'MC' },
    { title: 'Naming ritual', description: 'Child naming', offsetMinutes: 0, durationMinutes: 30, ownerType: 'planner', ownerName: 'Parents' },
    { title: 'Blessings & gifts', description: 'Family blessings', offsetMinutes: 35, durationMinutes: 30, ownerType: 'coordinator', ownerName: 'Family elder' },
    { title: 'Reception & food', description: 'Celebration meal', offsetMinutes: 70, durationMinutes: 90, ownerType: 'vendor', ownerName: 'Catering' },
  ],
};

@Injectable()
export class ProgramService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  private assertStatus(raw: string): ProgramStatus {
    if (!PROGRAM_STATUSES.includes(raw as ProgramStatus)) {
      throw new BadRequestException({ code: 'INVALID_STATUS', message: 'Unknown program status' });
    }
    return raw as ProgramStatus;
  }

  private assertOwnerType(raw: string): ProgramOwnerType {
    if (!PROGRAM_OWNER_TYPES.includes(raw as ProgramOwnerType)) {
      throw new BadRequestException({ code: 'INVALID_OWNER', message: 'Unknown owner type' });
    }
    return raw as ProgramOwnerType;
  }

  private assertTemplate(raw: string): ProgramTemplateKey {
    if (!PROGRAM_TEMPLATES.includes(raw as ProgramTemplateKey)) {
      throw new BadRequestException({ code: 'INVALID_TEMPLATE', message: 'Unknown program template' });
    }
    return raw as ProgramTemplateKey;
  }

  private rowToItem(row: {
    id: string;
    title: string;
    description: string;
    start_time: Date;
    duration_minutes: number;
    owner_type: string;
    owner_id: string | null;
    owner_name: string;
    vendor_id: string | null;
    status: string;
    sort_order: number;
  }): ProgramItemView {
    const end = new Date(row.start_time.getTime() + row.duration_minutes * 60_000);
    return {
      id: row.id,
      title: row.title,
      description: row.description,
      startTime: row.start_time.toISOString(),
      endTime: end.toISOString(),
      durationMinutes: row.duration_minutes,
      ownerType: row.owner_type as ProgramOwnerType,
      ownerId: row.owner_id,
      ownerName: row.owner_name,
      vendorId: row.vendor_id,
      status: row.status as ProgramStatus,
      sortOrder: row.sort_order,
    };
  }

  private async loadItems(tenantId: string, eventId: string): Promise<ProgramItemView[]> {
    const { rows } = await this.pool.query<{
      id: string;
      title: string;
      description: string;
      start_time: Date;
      duration_minutes: number;
      owner_type: string;
      owner_id: string | null;
      owner_name: string;
      vendor_id: string | null;
      status: string;
      sort_order: number;
    }>(
      `SELECT id, title, description, start_time, duration_minutes, owner_type, owner_id,
              owner_name, vendor_id, status, sort_order
       FROM event_program_items
       WHERE tenant_id = $1 AND event_id = $2
       ORDER BY sort_order, start_time`,
      [tenantId, eventId],
    );
    return rows.map((r) => this.rowToItem(r));
  }

  private buildDaySnapshot(items: ProgramItemView[], now = new Date()): ProgramDaySnapshot {
    const active = items.filter((i) => !['skipped', 'completed'].includes(i.status));
    const current =
      active.find((i) => {
        const start = new Date(i.startTime);
        const end = new Date(i.endTime);
        return i.status === 'in_progress' || (now >= start && now < end);
      }) ?? null;

    const next = active.find((i) => {
      if (current && i.id === current.id) return false;
      const start = new Date(i.startTime);
      return start > now && i.status !== 'completed' && i.status !== 'skipped';
    }) ?? null;

    const focus = current ?? next;
    let countdownSeconds: number | null = null;
    let countdownLabel: string | null = null;
    if (focus) {
      const target = current ? new Date(current.endTime) : new Date(focus.startTime);
      countdownSeconds = Math.max(0, Math.floor((target.getTime() - now.getTime()) / 1000));
      countdownLabel = current ? 'Time remaining' : 'Starts in';
    }

    return { current, next, countdownSeconds, countdownLabel };
  }

  private async writeActivity(
    tenantId: string,
    eventId: string,
    kind: ProgramActivityKind,
    headline: string,
    detail: string,
    programItemId?: string,
    metadata: Record<string, unknown> = {},
  ) {
    await this.pool.query(
      `INSERT INTO event_activity_log (tenant_id, event_id, program_item_id, activity_kind, headline, detail, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)`,
      [tenantId, eventId, programItemId ?? null, kind, headline, detail, JSON.stringify(metadata)],
    );
    await this.pool.query(
      `INSERT INTO event_feed_items (tenant_id, event_id, feed_type, headline, detail, metadata)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb)`,
      [tenantId, eventId, kind, headline, detail, JSON.stringify({ programItemId, ...metadata })],
    );
  }

  private async syncReminders(tenantId: string, eventId: string, itemId: string, startTime: Date) {
    for (const offset of [15, 5]) {
      const remindAt = new Date(startTime.getTime() - offset * 60_000);
      await this.pool.query(
        `INSERT INTO event_program_reminders (tenant_id, event_id, program_item_id, offset_minutes, remind_at)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (program_item_id, offset_minutes) DO UPDATE
           SET remind_at = EXCLUDED.remind_at, status = 'pending'`,
        [tenantId, eventId, itemId, offset, remindAt],
      );
    }
  }

  private async processDueReminders(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      program_item_id: string;
      offset_minutes: number;
      title: string;
    }>(
      `SELECT r.id, r.program_item_id, r.offset_minutes, p.title
       FROM event_program_reminders r
       JOIN event_program_items p ON p.id = r.program_item_id
       WHERE r.tenant_id = $1 AND r.event_id = $2 AND r.status = 'pending' AND r.remind_at <= now()
       ORDER BY r.remind_at`,
      [tenantId, eventId],
    );
    for (const r of rows) {
      const headline = `${r.offset_minutes} min reminder: ${r.title}`;
      await this.writeActivity(
        tenantId,
        eventId,
        'program_reminder',
        headline,
        `Activity starts in ${r.offset_minutes} minutes`,
        r.program_item_id,
        { offsetMinutes: r.offset_minutes },
      );
      await this.pool.query(`UPDATE event_program_reminders SET status = 'sent' WHERE id = $1`, [r.id]);
    }
  }

  private async loadRecentActivity(tenantId: string, eventId: string): Promise<ProgramActivityView[]> {
    const { rows } = await this.pool.query<{
      id: string;
      activity_kind: string;
      headline: string;
      detail: string;
      program_item_id: string | null;
      created_at: Date;
    }>(
      `SELECT id, activity_kind, headline, detail, program_item_id, created_at
       FROM event_activity_log
       WHERE tenant_id = $1 AND event_id = $2
       ORDER BY created_at DESC
       LIMIT 30`,
      [tenantId, eventId],
    );
    return rows.map((r) => ({
      id: r.id,
      activityKind: r.activity_kind as ProgramActivityKind,
      headline: r.headline,
      detail: r.detail,
      programItemId: r.program_item_id,
      createdAt: r.created_at.toISOString(),
    }));
  }

  async getProgram(tenantId: string, eventKey: string): Promise<ProgramView> {
    const event = await this.access.resolveEventRow(tenantId, eventKey, true);
    await this.processDueReminders(tenantId, event.id);
    const items = await this.loadItems(tenantId, event.id);
    return {
      items,
      day: this.buildDaySnapshot(items),
      recentActivity: await this.loadRecentActivity(tenantId, event.id),
    };
  }

  async getProgramForOrganizer(actor: CommerceActor, eventKey: string): Promise<ProgramView> {
    await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    return this.getProgram(actor.tenantId, eventKey);
  }

  async createItem(actor: CommerceActor, eventKey: string, body: Record<string, unknown>): Promise<ProgramView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const title = String(body.title ?? '').trim();
    if (!title) {
      throw new BadRequestException({ code: 'TITLE_REQUIRED', message: 'Title is required' });
    }
    const startRaw = body.startTime ?? body.start_time;
    if (!startRaw) {
      throw new BadRequestException({ code: 'START_REQUIRED', message: 'startTime is required' });
    }
    const startTime = new Date(String(startRaw));
    if (Number.isNaN(startTime.getTime())) {
      throw new BadRequestException({ code: 'INVALID_START', message: 'Invalid startTime' });
    }
    const ownerType = this.assertOwnerType(String(body.ownerType ?? 'planner'));
    const { rows: orderRows } = await this.pool.query<{ n: string }>(
      `SELECT COALESCE(MAX(sort_order), 0)::text AS n FROM event_program_items WHERE tenant_id = $1 AND event_id = $2`,
      [actor.tenantId, event.id],
    );
    const sortOrder = Number(orderRows[0]?.n ?? 0) + 1;
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO event_program_items (
         tenant_id, event_id, title, description, start_time, duration_minutes,
         owner_type, owner_id, owner_name, vendor_id, status, sort_order
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'planned', $11)
       RETURNING id`,
      [
        actor.tenantId,
        event.id,
        title,
        String(body.description ?? ''),
        startTime,
        Number(body.durationMinutes ?? 15),
        ownerType,
        body.ownerId ? String(body.ownerId) : null,
        String(body.ownerName ?? ''),
        body.vendorId ? String(body.vendorId) : null,
        sortOrder,
      ],
    );
    const itemId = rows[0]!.id;
    await this.syncReminders(actor.tenantId, event.id, itemId, startTime);
    await this.writeActivity(actor.tenantId, event.id, 'program_created', `Added: ${title}`, 'New program item', itemId);
    return this.getProgram(actor.tenantId, event.id);
  }

  async patchItem(
    actor: CommerceActor,
    eventKey: string,
    itemId: string,
    body: Record<string, unknown>,
  ): Promise<ProgramView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows: exists } = await this.pool.query<{ start_time: Date }>(
      `SELECT start_time FROM event_program_items WHERE tenant_id = $1 AND event_id = $2 AND id = $3`,
      [actor.tenantId, event.id, itemId],
    );
    if (!exists.length) {
      throw new NotFoundException({ code: 'ITEM_NOT_FOUND', message: 'Program item not found' });
    }

    const fields: Array<[string, unknown]> = [
      ['title', body.title != null ? String(body.title).trim() : undefined],
      ['description', body.description],
      ['start_time', body.startTime != null ? new Date(String(body.startTime)) : undefined],
      ['duration_minutes', body.durationMinutes != null ? Number(body.durationMinutes) : undefined],
      ['owner_type', body.ownerType != null ? this.assertOwnerType(String(body.ownerType)) : undefined],
      ['owner_id', body.ownerId != null ? String(body.ownerId) : body.ownerId === null ? null : undefined],
      ['owner_name', body.ownerName],
      ['vendor_id', body.vendorId != null ? String(body.vendorId) : body.vendorId === null ? null : undefined],
      ['status', body.status != null ? this.assertStatus(String(body.status)) : undefined],
      ['sort_order', body.sortOrder != null ? Number(body.sortOrder) : undefined],
    ];
    const sets: string[] = [];
    const params: unknown[] = [actor.tenantId, event.id, itemId];
    for (const [col, val] of fields) {
      if (val !== undefined) {
        params.push(val);
        sets.push(`${col} = $${params.length}`);
      }
    }
    if (sets.length === 0) {
      throw new BadRequestException({ code: 'NO_FIELDS', message: 'No fields to update' });
    }
    sets.push('updated_at = now()');
    await this.pool.query(
      `UPDATE event_program_items SET ${sets.join(', ')} WHERE tenant_id = $1 AND event_id = $2 AND id = $3`,
      params,
    );

    const { rows: updated } = await this.pool.query<{ title: string; start_time: Date }>(
      `SELECT title, start_time FROM event_program_items WHERE id = $1`,
      [itemId],
    );
    if (body.startTime != null) {
      await this.syncReminders(actor.tenantId, event.id, itemId, updated[0]!.start_time);
    }
    await this.writeActivity(
      actor.tenantId,
      event.id,
      'program_updated',
      `Updated: ${updated[0]?.title ?? 'item'}`,
      'Program item updated',
      itemId,
    );
    return this.getProgram(actor.tenantId, event.id);
  }

  async deleteItem(actor: CommerceActor, eventKey: string, itemId: string): Promise<ProgramView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    await this.pool.query(
      `DELETE FROM event_program_items WHERE tenant_id = $1 AND event_id = $2 AND id = $3`,
      [actor.tenantId, event.id, itemId],
    );
    return this.getProgram(actor.tenantId, event.id);
  }

  async setItemStatus(
    actor: CommerceActor,
    eventKey: string,
    itemId: string,
    status: string,
    delayMinutes?: number,
  ): Promise<ProgramView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const nextStatus = this.assertStatus(status);
    const { rows } = await this.pool.query<{ title: string }>(
      `UPDATE event_program_items SET status = $4, updated_at = now()
       WHERE tenant_id = $1 AND event_id = $2 AND id = $3
       RETURNING title`,
      [actor.tenantId, event.id, itemId, nextStatus],
    );
    if (!rows.length) {
      throw new NotFoundException({ code: 'ITEM_NOT_FOUND', message: 'Program item not found' });
    }
    const title = rows[0]!.title;
    if (nextStatus === 'in_progress') {
      await this.writeActivity(actor.tenantId, event.id, 'program_started', `Started: ${title}`, 'Activity in progress', itemId);
    } else if (nextStatus === 'completed') {
      await this.writeActivity(actor.tenantId, event.id, 'program_completed', `Completed: ${title}`, 'Activity completed', itemId);
    } else if (nextStatus === 'delayed') {
      await this.writeActivity(
        actor.tenantId,
        event.id,
        'program_delayed',
        `Delayed: ${title}`,
        delayMinutes ? `Delayed by ${delayMinutes} minutes` : 'Activity delayed',
        itemId,
        { delayMinutes: delayMinutes ?? null },
      );
      if (delayMinutes && delayMinutes > 0) {
        await this.autoShiftFollowing(actor, event.id, itemId, delayMinutes);
      }
    }
    return this.getProgram(actor.tenantId, event.id);
  }

  async reorder(actor: CommerceActor, eventKey: string, itemIds: string[]): Promise<ProgramView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    if (!itemIds.length) {
      throw new BadRequestException({ code: 'EMPTY_ORDER', message: 'itemIds required' });
    }
    for (let i = 0; i < itemIds.length; i++) {
      await this.pool.query(
        `UPDATE event_program_items SET sort_order = $4, updated_at = now()
         WHERE tenant_id = $1 AND event_id = $2 AND id = $3`,
        [actor.tenantId, event.id, itemIds[i], i + 1],
      );
    }
    return this.getProgram(actor.tenantId, event.id);
  }

  private async autoShiftFollowing(actor: CommerceActor, eventId: string, fromItemId: string, delayMinutes: number) {
    const { rows: pivot } = await this.pool.query<{ sort_order: number }>(
      `SELECT sort_order FROM event_program_items WHERE tenant_id = $1 AND event_id = $2 AND id = $3`,
      [actor.tenantId, eventId, fromItemId],
    );
    if (!pivot.length) return;

    await this.pool.query(
      `UPDATE event_program_items
       SET start_time = start_time + ($4::text || ' minutes')::interval, updated_at = now()
       WHERE tenant_id = $1 AND event_id = $2 AND sort_order >= $3`,
      [actor.tenantId, eventId, pivot[0]!.sort_order, delayMinutes],
    );

    const { rows: shifted } = await this.pool.query<{ id: string; start_time: Date }>(
      `SELECT id, start_time FROM event_program_items
       WHERE tenant_id = $1 AND event_id = $2 AND sort_order >= $3
       ORDER BY sort_order`,
      [actor.tenantId, eventId, pivot[0]!.sort_order],
    );
    for (const row of shifted) {
      await this.syncReminders(actor.tenantId, eventId, row.id, row.start_time);
    }
  }

  async autoShift(
    actor: CommerceActor,
    eventKey: string,
    fromItemId: string,
    delayMinutes: number,
  ): Promise<ProgramView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    if (!fromItemId || delayMinutes <= 0) {
      throw new BadRequestException({ code: 'INVALID_SHIFT', message: 'fromItemId and positive delayMinutes required' });
    }
    await this.autoShiftFollowing(actor, event.id, fromItemId, delayMinutes);
    const { rows } = await this.pool.query<{ title: string }>(
      `SELECT title FROM event_program_items WHERE id = $1`,
      [fromItemId],
    );
    await this.writeActivity(
      actor.tenantId,
      event.id,
      'program_delayed',
      `Schedule shifted after: ${rows[0]?.title ?? 'item'}`,
      `Following activities moved by ${delayMinutes} minutes`,
      fromItemId,
      { delayMinutes },
    );
    return this.getProgram(actor.tenantId, event.id);
  }

  async applyTemplate(actor: CommerceActor, eventKey: string, templateKey: string): Promise<ProgramView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const template = this.assertTemplate(templateKey);
    const { rows: existing } = await this.pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM event_program_items WHERE tenant_id = $1 AND event_id = $2`,
      [actor.tenantId, event.id],
    );
    if (Number(existing[0]?.n ?? 0) > 0) {
      throw new UnprocessableEntityException({
        code: 'PROGRAM_EXISTS',
        message: 'Clear existing program items before applying a template',
      });
    }
    const eventStart = event.starts_at;
    const seeds = TEMPLATE_SEEDS[template];
    let order = 0;
    for (const seed of seeds) {
      order++;
      const startTime = new Date(eventStart.getTime() + seed.offsetMinutes * 60_000);
      const { rows } = await this.pool.query<{ id: string }>(
        `INSERT INTO event_program_items (
           tenant_id, event_id, title, description, start_time, duration_minutes,
           owner_type, owner_name, status, sort_order
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'planned', $9)
         RETURNING id`,
        [
          actor.tenantId,
          event.id,
          seed.title,
          seed.description,
          startTime,
          seed.durationMinutes,
          seed.ownerType,
          seed.ownerName,
          order,
        ],
      );
      await this.syncReminders(actor.tenantId, event.id, rows[0]!.id, startTime);
    }
    await this.writeActivity(
      actor.tenantId,
      event.id,
      'program_created',
      `Applied ${template.replace('_', ' ')} template`,
      `${seeds.length} activities added`,
    );
    return this.getProgram(actor.tenantId, event.id);
  }
}
