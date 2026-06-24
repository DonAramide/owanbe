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

export const SEATING_TABLE_KINDS = ['round', 'rectangular', 'head', 'vip'] as const;
export type SeatingTableKind = (typeof SEATING_TABLE_KINDS)[number];

export type SeatingAssignmentView = {
  id: string;
  guestRef: string;
  guestName: string;
  seatIndex: number | null;
};

export type SeatingTableView = {
  id: string;
  label: string;
  tableKind: SeatingTableKind;
  capacity: number;
  isVip: boolean;
  positionX: number;
  positionY: number;
  rotationDeg: number;
  sortOrder: number;
  assignments: SeatingAssignmentView[];
  assignedCount: number;
};

export type SeatingLayoutView = {
  id: string;
  name: string;
  canvasWidth: number;
  canvasHeight: number;
  tables: SeatingTableView[];
  unassignedGuestRefs: string[];
  stats: {
    tableCount: number;
    totalCapacity: number;
    assignedGuests: number;
    vipTableCount: number;
  };
};

@Injectable()
export class SeatingService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  private assertTableKind(raw: string): SeatingTableKind {
    if (!SEATING_TABLE_KINDS.includes(raw as SeatingTableKind)) {
      throw new BadRequestException({ code: 'INVALID_TABLE_KIND', message: 'Unknown table kind' });
    }
    return raw as SeatingTableKind;
  }

  private async ensureLayout(tenantId: string, eventId: string) {
    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO event_seating_layouts (tenant_id, event_id)
       VALUES ($1, $2)
       ON CONFLICT (event_id) DO UPDATE SET updated_at = event_seating_layouts.updated_at
       RETURNING id`,
      [tenantId, eventId],
    );
    return rows[0]!.id;
  }

  private async loadTables(tenantId: string, eventId: string): Promise<SeatingTableView[]> {
    const { rows: tableRows } = await this.pool.query<{
      id: string;
      label: string;
      table_kind: string;
      capacity: number;
      is_vip: boolean;
      position_x: string;
      position_y: string;
      rotation_deg: string;
      sort_order: number;
    }>(
      `SELECT id, label, table_kind, capacity, is_vip, position_x, position_y, rotation_deg, sort_order
       FROM event_seating_tables
       WHERE tenant_id = $1 AND event_id = $2
       ORDER BY sort_order, label`,
      [tenantId, eventId],
    );

    if (tableRows.length === 0) return [];

    const tableIds = tableRows.map((t) => t.id);
    const { rows: assignmentRows } = await this.pool.query<{
      id: string;
      table_id: string;
      guest_ref: string;
      guest_name: string;
      seat_index: number | null;
    }>(
      `SELECT id, table_id, guest_ref, guest_name, seat_index
       FROM event_seating_assignments
       WHERE tenant_id = $1 AND event_id = $2 AND table_id = ANY($3::uuid[])
       ORDER BY seat_index NULLS LAST, guest_name`,
      [tenantId, eventId, tableIds],
    );

    const byTable = new Map<string, SeatingAssignmentView[]>();
    for (const a of assignmentRows) {
      const list = byTable.get(a.table_id) ?? [];
      list.push({
        id: a.id,
        guestRef: a.guest_ref,
        guestName: a.guest_name,
        seatIndex: a.seat_index,
      });
      byTable.set(a.table_id, list);
    }

    return tableRows.map((t) => {
      const assignments = byTable.get(t.id) ?? [];
      return {
        id: t.id,
        label: t.label,
        tableKind: t.table_kind as SeatingTableKind,
        capacity: t.capacity,
        isVip: t.is_vip,
        positionX: Number(t.position_x),
        positionY: Number(t.position_y),
        rotationDeg: Number(t.rotation_deg),
        sortOrder: t.sort_order,
        assignments,
        assignedCount: assignments.length,
      };
    });
  }

  private buildLayoutView(
    layout: {
      id: string;
      name: string;
      canvas_width: number;
      canvas_height: number;
    },
    tables: SeatingTableView[],
  ): SeatingLayoutView {
    const assignedRefs = new Set<string>();
    for (const t of tables) {
      for (const a of t.assignments) assignedRefs.add(a.guestRef);
    }
    return {
      id: layout.id,
      name: layout.name,
      canvasWidth: layout.canvas_width,
      canvasHeight: layout.canvas_height,
      tables,
      unassignedGuestRefs: [],
      stats: {
        tableCount: tables.length,
        totalCapacity: tables.reduce((sum, t) => sum + t.capacity, 0),
        assignedGuests: assignedRefs.size,
        vipTableCount: tables.filter((t) => t.isVip).length,
      },
    };
  }

  async getLayout(tenantId: string, eventKey: string): Promise<SeatingLayoutView> {
    const event = await this.access.resolveEventRow(tenantId, eventKey, true);
    await this.ensureLayout(tenantId, event.id);
    const { rows } = await this.pool.query<{
      id: string;
      name: string;
      canvas_width: number;
      canvas_height: number;
    }>(
      `SELECT id, name, canvas_width, canvas_height
       FROM event_seating_layouts
       WHERE tenant_id = $1 AND event_id = $2`,
      [tenantId, event.id],
    );
    const layout = rows[0]!;
    const tables = await this.loadTables(tenantId, event.id);
    return this.buildLayoutView(layout, tables);
  }

  async getLayoutForOrganizer(actor: CommerceActor, eventKey: string): Promise<SeatingLayoutView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    await this.ensureLayout(actor.tenantId, event.id);
    return this.getLayout(actor.tenantId, event.id);
  }

  async patchLayout(
    actor: CommerceActor,
    eventKey: string,
    body: { name?: string; canvasWidth?: number; canvasHeight?: number },
  ): Promise<SeatingLayoutView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    await this.ensureLayout(actor.tenantId, event.id);
    const sets: string[] = [];
    const params: unknown[] = [actor.tenantId, event.id];
    if (body.name != null) {
      params.push(body.name);
      sets.push(`name = $${params.length}`);
    }
    if (body.canvasWidth != null) {
      params.push(body.canvasWidth);
      sets.push(`canvas_width = $${params.length}`);
    }
    if (body.canvasHeight != null) {
      params.push(body.canvasHeight);
      sets.push(`canvas_height = $${params.length}`);
    }
    if (sets.length > 0) {
      sets.push('updated_at = now()');
      await this.pool.query(
        `UPDATE event_seating_layouts SET ${sets.join(', ')} WHERE tenant_id = $1 AND event_id = $2`,
        params,
      );
    }
    return this.getLayout(actor.tenantId, event.id);
  }

  async createTable(
    actor: CommerceActor,
    eventKey: string,
    body: {
      label?: string;
      tableKind?: string;
      capacity?: number;
      isVip?: boolean;
      positionX?: number;
      positionY?: number;
      rotationDeg?: number;
    },
  ): Promise<SeatingLayoutView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const layoutId = await this.ensureLayout(actor.tenantId, event.id);
    const kind = body.tableKind ? this.assertTableKind(body.tableKind) : 'round';
    const isVip = Boolean(body.isVip) || kind === 'vip';
    const { rows: countRows } = await this.pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM event_seating_tables WHERE tenant_id = $1 AND event_id = $2`,
      [actor.tenantId, event.id],
    );
    const n = Number(countRows[0]?.n ?? 0) + 1;
    const label = body.label?.trim() || `Table ${n}`;
    await this.pool.query(
      `INSERT INTO event_seating_tables (
         tenant_id, event_id, layout_id, label, table_kind, capacity, is_vip,
         position_x, position_y, rotation_deg, sort_order
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
      [
        actor.tenantId,
        event.id,
        layoutId,
        label,
        kind,
        body.capacity ?? 8,
        isVip,
        body.positionX ?? 40 + (n % 5) * 120,
        body.positionY ?? 40 + Math.floor(n / 5) * 120,
        body.rotationDeg ?? 0,
        n,
      ],
    );
    return this.getLayout(actor.tenantId, event.id);
  }

  async patchTable(
    actor: CommerceActor,
    eventKey: string,
    tableId: string,
    body: Record<string, unknown>,
  ): Promise<SeatingLayoutView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows: exists } = await this.pool.query(
      `SELECT 1 FROM event_seating_tables WHERE tenant_id = $1 AND event_id = $2 AND id = $3`,
      [actor.tenantId, event.id, tableId],
    );
    if (!exists.length) {
      throw new NotFoundException({ code: 'TABLE_NOT_FOUND', message: 'Seating table not found' });
    }

    const fields: Array<[string, unknown]> = [
      ['label', body.label],
      ['table_kind', body.tableKind != null ? this.assertTableKind(String(body.tableKind)) : undefined],
      ['capacity', body.capacity],
      ['is_vip', body.isVip],
      ['position_x', body.positionX],
      ['position_y', body.positionY],
      ['rotation_deg', body.rotationDeg],
      ['sort_order', body.sortOrder],
    ];
    const sets: string[] = [];
    const params: unknown[] = [actor.tenantId, event.id, tableId];
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
      `UPDATE event_seating_tables SET ${sets.join(', ')}
       WHERE tenant_id = $1 AND event_id = $2 AND id = $3`,
      params,
    );
    return this.getLayout(actor.tenantId, event.id);
  }

  async deleteTable(actor: CommerceActor, eventKey: string, tableId: string): Promise<SeatingLayoutView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    await this.pool.query(
      `DELETE FROM event_seating_tables WHERE tenant_id = $1 AND event_id = $2 AND id = $3`,
      [actor.tenantId, event.id, tableId],
    );
    return this.getLayout(actor.tenantId, event.id);
  }

  async syncTablePositions(
    actor: CommerceActor,
    eventKey: string,
    tables: Array<{ id: string; positionX: number; positionY: number; rotationDeg?: number }>,
  ): Promise<SeatingLayoutView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    for (const t of tables) {
      await this.pool.query(
        `UPDATE event_seating_tables
         SET position_x = $4, position_y = $5, rotation_deg = COALESCE($6, rotation_deg), updated_at = now()
         WHERE tenant_id = $1 AND event_id = $2 AND id = $3`,
        [actor.tenantId, event.id, t.id, t.positionX, t.positionY, t.rotationDeg ?? null],
      );
    }
    return this.getLayout(actor.tenantId, event.id);
  }

  async assignGuest(
    actor: CommerceActor,
    eventKey: string,
    body: { tableId?: string; guestRef?: string; guestName?: string; seatIndex?: number },
  ): Promise<SeatingLayoutView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const tableId = body.tableId;
    const guestRef = body.guestRef?.trim();
    const guestName = body.guestName?.trim();
    if (!tableId || !guestRef || !guestName) {
      throw new BadRequestException({ code: 'INVALID_ASSIGNMENT', message: 'tableId, guestRef, and guestName required' });
    }

    const { rows: tableRows } = await this.pool.query<{ capacity: number; assigned: string }>(
      `SELECT t.capacity, (
         SELECT COUNT(*)::text FROM event_seating_assignments a WHERE a.table_id = t.id
       ) AS assigned
       FROM event_seating_tables t
       WHERE t.tenant_id = $1 AND t.event_id = $2 AND t.id = $3`,
      [actor.tenantId, event.id, tableId],
    );
    const table = tableRows[0];
    if (!table) {
      throw new NotFoundException({ code: 'TABLE_NOT_FOUND', message: 'Seating table not found' });
    }
    if (Number(table.assigned) >= table.capacity) {
      throw new UnprocessableEntityException({ code: 'TABLE_FULL', message: 'Table is at capacity' });
    }

    await this.pool.query(
      `DELETE FROM event_seating_assignments
       WHERE tenant_id = $1 AND event_id = $2 AND guest_ref = $3`,
      [actor.tenantId, event.id, guestRef],
    );

    await this.pool.query(
      `INSERT INTO event_seating_assignments (tenant_id, event_id, table_id, guest_ref, guest_name, seat_index)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (table_id, guest_ref) DO UPDATE
         SET guest_name = EXCLUDED.guest_name,
             seat_index = EXCLUDED.seat_index,
             updated_at = now()`,
      [actor.tenantId, event.id, tableId, guestRef, guestName, body.seatIndex ?? null],
    );
    return this.getLayout(actor.tenantId, event.id);
  }

  async unassignGuest(actor: CommerceActor, eventKey: string, assignmentId: string): Promise<SeatingLayoutView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    await this.pool.query(
      `DELETE FROM event_seating_assignments
       WHERE tenant_id = $1 AND event_id = $2 AND id = $3`,
      [actor.tenantId, event.id, assignmentId],
    );
    return this.getLayout(actor.tenantId, event.id);
  }

  async initializeFromGuestCount(
    actor: CommerceActor,
    eventKey: string,
    guestCount: number,
    vipTableCount = 1,
  ): Promise<SeatingLayoutView> {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const layoutId = await this.ensureLayout(actor.tenantId, event.id);

    const { rows: existing } = await this.pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM event_seating_tables WHERE tenant_id = $1 AND event_id = $2`,
      [actor.tenantId, event.id],
    );
    if (Number(existing[0]?.n ?? 0) > 0) {
      throw new UnprocessableEntityException({
        code: 'LAYOUT_EXISTS',
        message: 'Clear existing tables before auto-initialize',
      });
    }

    const guests = Math.max(guestCount, 8);
    const regularTables = Math.max(1, Math.ceil((guests - vipTableCount * 6) / 8));
    const cols = 4;
    let order = 0;

    for (let i = 0; i < vipTableCount; i++) {
      order++;
      await this.pool.query(
        `INSERT INTO event_seating_tables (
           tenant_id, event_id, layout_id, label, table_kind, capacity, is_vip,
           position_x, position_y, sort_order
         ) VALUES ($1, $2, $3, $4, 'vip', 6, true, $5, $6, $7)`,
        [actor.tenantId, event.id, layoutId, `VIP ${i + 1}`, 40 + i * 140, 40, order],
      );
    }

    for (let i = 0; i < regularTables; i++) {
      order++;
      const col = i % cols;
      const row = Math.floor(i / cols);
      await this.pool.query(
        `INSERT INTO event_seating_tables (
           tenant_id, event_id, layout_id, label, table_kind, capacity, is_vip,
           position_x, position_y, sort_order
         ) VALUES ($1, $2, $3, $4, 'round', 8, false, $5, $6, $7)`,
        [
          actor.tenantId,
          event.id,
          layoutId,
          `Table ${i + 1}`,
          40 + col * 160,
          180 + row * 140,
          order,
        ],
      );
    }

    return this.getLayout(actor.tenantId, event.id);
  }

  async exportLayout(actor: CommerceActor, eventKey: string) {
    const layout = await this.getLayoutForOrganizer(actor, eventKey);
    const rows: Array<Record<string, string | number | null>> = [];
    for (const table of layout.tables) {
      if (table.assignments.length === 0) {
        rows.push({
          table: table.label,
          kind: table.tableKind,
          vip: table.isVip ? 'yes' : 'no',
          guest: '',
          seat: null,
        });
        continue;
      }
      for (const a of table.assignments) {
        rows.push({
          table: table.label,
          kind: table.tableKind,
          vip: table.isVip ? 'yes' : 'no',
          guest: a.guestName,
          seat: a.seatIndex,
        });
      }
    }
    return { layout, rows };
  }
}
