import { ForbiddenException, Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import {
  capabilitiesForOrgRole,
  orgRoleHasCapability,
  sqlOrganizerOwnerOrMember,
  type OrgCapability,
  type OrgMemberRole,
} from './organizer-access.sql';

@Injectable()
export class EventsAccessService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /**
   * Resolve the active organizer for a user: owned org first, else membership.
   * Owner behaviour unchanged when the user owns an org.
   */
  async resolveOrganizerId(tenantId: string, userId: string): Promise<string> {
    const { rows } = await this.pool.query<{ id: string }>(
      `SELECT id FROM (
         SELECT id, 0 AS rank
         FROM organizers
         WHERE tenant_id = $1 AND owner_user_id = $2 AND status = 'active'
         UNION ALL
         SELECT o.id, 1 AS rank
         FROM organizers o
         INNER JOIN organizer_members om
           ON om.organizer_id = o.id AND om.user_id = $2 AND om.status = 'active'
         WHERE o.tenant_id = $1 AND o.status = 'active'
       ) x
       ORDER BY rank ASC
       LIMIT 1`,
      [tenantId, userId],
    );
    const id = rows[0]?.id;
    if (!id) {
      throw new ForbiddenException({
        code: 'ORGANIZER_REQUIRED',
        message: 'Active organizer profile required',
      });
    }
    return id;
  }

  async resolveVendorId(tenantId: string, userId: string): Promise<string> {
    const { rows } = await this.pool.query<{ id: string }>(
      `SELECT COALESCE(
         (
           SELECT vp.vendor_id
           FROM vendor_profiles vp
           WHERE vp.tenant_id = $1 AND vp.user_id = $2 AND vp.vendor_id IS NOT NULL
           LIMIT 1
         ),
         (
           SELECT v.id
           FROM vendors v
           WHERE v.tenant_id = $1 AND v.owner_user_id = $2 AND v.status = 'active'
           LIMIT 1
         )
       ) AS id`,
      [tenantId, userId],
    );
    const id = rows[0]?.id;
    if (!id) {
      throw new ForbiddenException({ code: 'VENDOR_REQUIRED', message: 'Active vendor profile required' });
    }
    return id;
  }

  async resolveEventRow(
    tenantId: string,
    eventKey: string,
    publicOnly = false,
  ): Promise<{
    id: string;
    organizer_id: string;
    title: string;
    slug: string;
    status: string;
    external_ref: string | null;
    starts_at: Date;
    ends_at: Date | null;
    metadata: Record<string, unknown>;
  }> {
    const { rows } = await this.pool.query<{
      id: string;
      organizer_id: string;
      title: string;
      slug: string;
      status: string;
      external_ref: string | null;
      starts_at: Date;
      ends_at: Date | null;
      metadata: Record<string, unknown>;
    }>(
      `SELECT id, organizer_id, title, slug, status::text, external_ref, starts_at, ends_at, metadata
       FROM events
       WHERE tenant_id = $1
         AND (id::text = $2 OR external_ref = $2 OR slug = $2)
         ${publicOnly ? `AND status::text IN ('published', 'live', 'completed')` : ''}
       LIMIT 1`,
      [tenantId, eventKey],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'EVENT_NOT_FOUND', message: 'Event not found' });
    }
    return row;
  }

  /**
   * Assert organizer access to event: owner OR active organization member.
   * Method name retained for backward compatibility with frozen callers.
   */
  async assertOrganizerOwnsEvent(tenantId: string, userId: string, eventKey: string) {
    const event = await this.resolveEventRow(tenantId, eventKey);
    const { rows } = await this.pool.query<{ id: string }>(
      `SELECT o.id FROM organizers o
       WHERE o.id = $1 AND o.tenant_id = $2
         AND ${sqlOrganizerOwnerOrMember('$3')}`,
      [event.organizer_id, tenantId, userId],
    );
    if (!rows[0]) {
      throw new ForbiddenException({ code: 'ACCESS_DENIED', message: 'Not event organizer' });
    }
    return event;
  }

  async resolveOrgRole(
    tenantId: string,
    userId: string,
    organizerId: string,
  ): Promise<'owner' | OrgMemberRole> {
    const { rows: owned } = await this.pool.query<{ id: string }>(
      `SELECT id FROM organizers
       WHERE id = $1 AND tenant_id = $2 AND owner_user_id = $3 AND status = 'active'`,
      [organizerId, tenantId, userId],
    );
    if (owned[0]) return 'owner';

    const { rows: member } = await this.pool.query<{ org_role: string }>(
      `SELECT org_role FROM organizer_members
       WHERE organizer_id = $1 AND user_id = $2 AND status = 'active'
       LIMIT 1`,
      [organizerId, userId],
    );
    if (!member[0]) {
      throw new ForbiddenException({ code: 'ACCESS_DENIED', message: 'Not organization member' });
    }
    return member[0].org_role as OrgMemberRole;
  }

  async assertOrgCapability(
    tenantId: string,
    userId: string,
    organizerId: string,
    capability: OrgCapability,
  ): Promise<'owner' | OrgMemberRole> {
    const role = await this.resolveOrgRole(tenantId, userId, organizerId);
    if (!orgRoleHasCapability(role, capability)) {
      throw new ForbiddenException({
        code: 'ORG_CAPABILITY_DENIED',
        message: `Missing organization capability: ${capability}`,
      });
    }
    return role;
  }

  /**
   * Membership + capability for an event (Phase 25 hardening).
   * Does not redesign access — layers capability on owner-or-member.
   */
  async assertEventCapability(
    tenantId: string,
    userId: string,
    eventKey: string,
    capability: OrgCapability,
  ) {
    const event = await this.assertOrganizerOwnsEvent(tenantId, userId, eventKey);
    await this.assertOrgCapability(tenantId, userId, event.organizer_id, capability);
    return event;
  }

  capabilitiesFor(role: 'owner' | OrgMemberRole) {
    return capabilitiesForOrgRole(role);
  }

  slugify(title: string): string {
    const base = title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 48);
    return base || `event-${Date.now()}`;
  }
}
