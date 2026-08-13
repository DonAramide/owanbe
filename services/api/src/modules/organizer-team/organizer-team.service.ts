import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Inject,
  NotFoundException,
} from '@nestjs/common';
import { randomBytes } from 'crypto';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import { AuditLogService } from '../../audit/audit-log.service';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';
import {
  ORG_ROLES,
  capabilitiesForOrgRole,
  type OrgMemberRole,
} from '../events/organizer-access.sql';

export type OrganizerMemberView = {
  id: string;
  organizerId: string;
  userId: string | null;
  email: string;
  displayName: string | null;
  orgRole: 'owner' | OrgMemberRole;
  status: 'owner' | 'pending' | 'active' | 'revoked';
  invitedAt: string | null;
  acceptedAt: string | null;
  isOwner: boolean;
  capabilities: string[];
  /** Present on invite create only — share out-of-band */
  inviteToken?: string;
};

@Injectable()
export class OrganizerTeamService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly audit: AuditLogService,
  ) {}

  private async resolveManagedOrganizer(actor: CommerceActor): Promise<{
    organizerId: string;
    displayName: string;
  }> {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    const { rows } = await this.pool.query<{ display_name: string }>(
      `SELECT display_name FROM organizers WHERE id = $1 AND tenant_id = $2`,
      [organizerId, actor.tenantId],
    );
    return { organizerId, displayName: rows[0]?.display_name ?? 'Organization' };
  }

  async listMembers(
    actor: CommerceActor,
    filters?: { q?: string; role?: string; status?: string },
  ): Promise<{ items: OrganizerMemberView[]; organizerId: string; organizationName: string }> {
    const { organizerId, displayName } = await this.resolveManagedOrganizer(actor);
    // Any owner/member may view directory; manage actions gated separately
    await this.access.resolveOrgRole(actor.tenantId, actor.userId, organizerId);

    const { rows: ownerRows } = await this.pool.query<{
      owner_user_id: string;
      email: string;
      display_name: string | null;
    }>(
      `SELECT o.owner_user_id, u.email, u.display_name
       FROM organizers o
       INNER JOIN users u ON u.id = o.owner_user_id
       WHERE o.id = $1 AND o.tenant_id = $2`,
      [organizerId, actor.tenantId],
    );
    const owner = ownerRows[0];

    const { rows } = await this.pool.query<{
      id: string;
      user_id: string | null;
      email: string;
      display_name: string | null;
      org_role: string;
      status: string;
      invited_at: Date;
      accepted_at: Date | null;
    }>(
      `SELECT om.id, om.user_id, om.email, u.display_name, om.org_role, om.status,
              om.invited_at, om.accepted_at
       FROM organizer_members om
       LEFT JOIN users u ON u.id = om.user_id
       WHERE om.organizer_id = $1 AND om.tenant_id = $2
         AND om.status IN ('pending', 'active', 'revoked')
       ORDER BY om.invited_at DESC`,
      [organizerId, actor.tenantId],
    );

    const items: OrganizerMemberView[] = [];
    if (owner) {
      items.push({
        id: `owner:${owner.owner_user_id}`,
        organizerId,
        userId: owner.owner_user_id,
        email: owner.email,
        displayName: owner.display_name,
        orgRole: 'owner',
        status: 'owner',
        invitedAt: null,
        acceptedAt: null,
        isOwner: true,
        capabilities: capabilitiesForOrgRole('owner'),
      });
    }

    for (const r of rows) {
      items.push({
        id: r.id,
        organizerId,
        userId: r.user_id,
        email: r.email,
        displayName: r.display_name,
        orgRole: r.org_role as OrgMemberRole,
        status: r.status as OrganizerMemberView['status'],
        invitedAt: r.invited_at.toISOString(),
        acceptedAt: r.accepted_at?.toISOString() ?? null,
        isOwner: false,
        capabilities: capabilitiesForOrgRole(r.org_role as OrgMemberRole),
      });
    }

    const q = (filters?.q ?? '').trim().toLowerCase();
    const role = (filters?.role ?? '').trim().toLowerCase();
    const status = (filters?.status ?? '').trim().toLowerCase();

    const filtered = items.filter((m) => {
      if (q) {
        const hay = `${m.email} ${m.displayName ?? ''}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      if (role && m.orgRole !== role) return false;
      if (status) {
        if (status === 'owner' && !m.isOwner) return false;
        if (status !== 'owner' && m.status !== status) return false;
      }
      return true;
    });

    return { items: filtered, organizerId, organizationName: displayName };
  }

  async invite(
    actor: CommerceActor,
    body: { email: string; orgRole?: string },
  ): Promise<OrganizerMemberView> {
    const { organizerId } = await this.resolveManagedOrganizer(actor);
    await this.access.assertOrgCapability(actor.tenantId, actor.userId, organizerId, 'team.manage');

    const email = (body.email ?? '').trim().toLowerCase();
    if (!email || !email.includes('@')) {
      throw new BadRequestException({ code: 'INVALID_EMAIL', message: 'Valid email required' });
    }
    const orgRole = (body.orgRole ?? 'staff').toLowerCase();
    if (!ORG_ROLES.includes(orgRole as OrgMemberRole)) {
      throw new BadRequestException({ code: 'INVALID_ORG_ROLE', message: 'orgRole must be admin|manager|staff' });
    }

    const { rows: ownerCheck } = await this.pool.query<{ email: string }>(
      `SELECT u.email FROM organizers o
       INNER JOIN users u ON u.id = o.owner_user_id
       WHERE o.id = $1`,
      [organizerId],
    );
    if (ownerCheck[0]?.email?.toLowerCase() === email) {
      throw new BadRequestException({ code: 'ALREADY_OWNER', message: 'User is already the organization owner' });
    }

    const { rows: existingUser } = await this.pool.query<{ id: string; display_name: string | null }>(
      `SELECT id, display_name FROM users WHERE tenant_id = $1 AND lower(email) = $2 LIMIT 1`,
      [actor.tenantId, email],
    );

    const token = randomBytes(24).toString('hex');
    const { rows: prior } = await this.pool.query<{ id: string; status: string }>(
      `SELECT id, status FROM organizer_members
       WHERE organizer_id = $1 AND lower(email) = $2
       ORDER BY invited_at DESC LIMIT 1`,
      [organizerId, email],
    );
    if (prior[0]?.status === 'active' || prior[0]?.status === 'pending') {
      throw new BadRequestException({
        code: 'ALREADY_INVITED',
        message: 'Member already invited or active',
      });
    }

    let row: {
      id: string;
      user_id: string | null;
      email: string;
      org_role: string;
      status: string;
      invited_at: Date;
    };

    if (prior[0]?.status === 'revoked') {
      const { rows: revived } = await this.pool.query<{
        id: string;
        user_id: string | null;
        email: string;
        org_role: string;
        status: string;
        invited_at: Date;
      }>(
        `UPDATE organizer_members
         SET status = 'pending', org_role = $2, invite_token = $3, invited_by = $4,
             invited_at = now(), accepted_at = NULL, revoked_at = NULL, user_id = $5, updated_at = now()
         WHERE id = $1
         RETURNING id, user_id, email, org_role, status, invited_at`,
        [prior[0].id, orgRole, token, actor.userId, existingUser[0]?.id ?? null],
      );
      row = revived[0]!;
    } else {
      const { rows } = await this.pool.query<{
        id: string;
        user_id: string | null;
        email: string;
        org_role: string;
        status: string;
        invited_at: Date;
      }>(
        `INSERT INTO organizer_members (
           tenant_id, organizer_id, user_id, email, org_role, status, invite_token, invited_by
         ) VALUES ($1, $2, $3, $4, $5, 'pending', $6, $7)
         RETURNING id, user_id, email, org_role, status, invited_at`,
        [
          actor.tenantId,
          organizerId,
          existingUser[0]?.id ?? null,
          email,
          orgRole,
          token,
          actor.userId,
        ],
      );
      row = rows[0]!;
    }

    await this.audit.logAction({
      tenantId: actor.tenantId,
      actorUserId: actor.userId,
      action: 'organizer.team.invite_sent',
      resourceType: 'organizer_member',
      resourceId: row.id,
      metadata: { organizerId, email, orgRole, inviteToken: token },
    });

    // In-app notify if user exists
    if (existingUser[0]?.id) {
      await this.pool.query(
        `INSERT INTO notifications (tenant_id, user_id, channel, status, kind, title, body, data, dedupe_key, sent_at, delivered_at)
         VALUES ($1, $2, 'in_app', 'delivered', 'organizer_team_invite', $3, $4, $5::jsonb, $6, now(), now())
         ON CONFLICT (tenant_id, user_id, dedupe_key) DO UPDATE
           SET title = EXCLUDED.title, body = EXCLUDED.body, data = EXCLUDED.data, updated_at = now()`,
        [
          actor.tenantId,
          existingUser[0].id,
          'Organization invite',
          'You were invited to join an organizer team.',
          JSON.stringify({ organizerId, memberId: row.id, token }),
          `org-invite-${row.id}`,
        ],
      );
    }

    return {
      id: row.id,
      organizerId,
      userId: row.user_id,
      email: row.email,
      displayName: existingUser[0]?.display_name ?? null,
      orgRole: row.org_role as OrgMemberRole,
      status: 'pending',
      invitedAt: row.invited_at.toISOString(),
      acceptedAt: null,
      isOwner: false,
      capabilities: capabilitiesForOrgRole(row.org_role as OrgMemberRole),
      inviteToken: token,
    };
  }

  async acceptInvite(actor: CommerceActor, token: string): Promise<OrganizerMemberView> {
    const { rows } = await this.pool.query<{
      id: string;
      tenant_id: string;
      organizer_id: string;
      email: string;
      org_role: string;
      status: string;
      invited_at: Date;
    }>(
      `SELECT id, tenant_id, organizer_id, email, org_role, status, invited_at
       FROM organizer_members WHERE invite_token = $1 LIMIT 1`,
      [token],
    );
    const invite = rows[0];
    if (!invite || invite.tenant_id !== actor.tenantId) {
      throw new NotFoundException({ code: 'INVITE_NOT_FOUND', message: 'Invitation not found' });
    }
    if (invite.status !== 'pending') {
      throw new BadRequestException({ code: 'INVITE_NOT_PENDING', message: 'Invitation is not pending' });
    }

    const { rows: me } = await this.pool.query<{ email: string }>(
      `SELECT email FROM users WHERE id = $1 AND tenant_id = $2`,
      [actor.userId, actor.tenantId],
    );
    if ((me[0]?.email ?? '').toLowerCase() !== invite.email.toLowerCase()) {
      throw new ForbiddenException({
        code: 'INVITE_EMAIL_MISMATCH',
        message: 'Signed-in email must match the invitation',
      });
    }

    // Grant portal organizer role (reuse user_roles — do not create second org)
    await this.pool.query(
      `INSERT INTO user_roles (user_id, role_id)
       SELECT $1, r.id FROM roles r WHERE r.code = 'organizer'
       ON CONFLICT (user_id, role_id) DO NOTHING`,
      [actor.userId],
    );

    const { rows: updated } = await this.pool.query<{
      id: string;
      user_id: string | null;
      email: string;
      org_role: string;
      status: string;
      invited_at: Date;
      accepted_at: Date | null;
    }>(
      `UPDATE organizer_members
       SET status = 'active', user_id = $2, accepted_at = now(), updated_at = now()
       WHERE id = $1
       RETURNING id, user_id, email, org_role, status, invited_at, accepted_at`,
      [invite.id, actor.userId],
    );
    const row = updated[0]!;

    await this.audit.logAction({
      tenantId: actor.tenantId,
      actorUserId: actor.userId,
      action: 'organizer.team.invite_accepted',
      resourceType: 'organizer_member',
      resourceId: row.id,
      metadata: { organizerId: invite.organizer_id, orgRole: row.org_role },
    });

    return {
      id: row.id,
      organizerId: invite.organizer_id,
      userId: row.user_id,
      email: row.email,
      displayName: null,
      orgRole: row.org_role as OrgMemberRole,
      status: 'active',
      invitedAt: row.invited_at.toISOString(),
      acceptedAt: row.accepted_at?.toISOString() ?? null,
      isOwner: false,
      capabilities: capabilitiesForOrgRole(row.org_role as OrgMemberRole),
    };
  }

  async updateRole(
    actor: CommerceActor,
    memberId: string,
    orgRole: string,
  ): Promise<OrganizerMemberView> {
    const { organizerId } = await this.resolveManagedOrganizer(actor);
    await this.access.assertOrgCapability(actor.tenantId, actor.userId, organizerId, 'team.manage');
    if (!ORG_ROLES.includes(orgRole as OrgMemberRole)) {
      throw new BadRequestException({ code: 'INVALID_ORG_ROLE', message: 'orgRole must be admin|manager|staff' });
    }

    const { rows } = await this.pool.query<{
      id: string;
      user_id: string | null;
      email: string;
      org_role: string;
      status: string;
      invited_at: Date;
      accepted_at: Date | null;
    }>(
      `UPDATE organizer_members
       SET org_role = $3, updated_at = now()
       WHERE id = $1 AND organizer_id = $2 AND status IN ('pending', 'active')
       RETURNING id, user_id, email, org_role, status, invited_at, accepted_at`,
      [memberId, organizerId, orgRole],
    );
    if (!rows[0]) {
      throw new NotFoundException({ code: 'MEMBER_NOT_FOUND', message: 'Member not found' });
    }
    const row = rows[0];

    await this.audit.logAction({
      tenantId: actor.tenantId,
      actorUserId: actor.userId,
      action: 'organizer.team.role_changed',
      resourceType: 'organizer_member',
      resourceId: row.id,
      metadata: { organizerId, orgRole },
    });

    return {
      id: row.id,
      organizerId,
      userId: row.user_id,
      email: row.email,
      displayName: null,
      orgRole: row.org_role as OrgMemberRole,
      status: row.status as OrganizerMemberView['status'],
      invitedAt: row.invited_at.toISOString(),
      acceptedAt: row.accepted_at?.toISOString() ?? null,
      isOwner: false,
      capabilities: capabilitiesForOrgRole(row.org_role as OrgMemberRole),
    };
  }

  async removeMember(actor: CommerceActor, memberId: string): Promise<{ ok: true }> {
    const { organizerId } = await this.resolveManagedOrganizer(actor);
    await this.access.assertOrgCapability(actor.tenantId, actor.userId, organizerId, 'team.manage');

    const { rows } = await this.pool.query<{ id: string; email: string }>(
      `UPDATE organizer_members
       SET status = 'revoked', revoked_at = now(), updated_at = now()
       WHERE id = $1 AND organizer_id = $2 AND status IN ('pending', 'active')
       RETURNING id, email`,
      [memberId, organizerId],
    );
    if (!rows[0]) {
      throw new NotFoundException({ code: 'MEMBER_NOT_FOUND', message: 'Member not found' });
    }

    await this.audit.logAction({
      tenantId: actor.tenantId,
      actorUserId: actor.userId,
      action: 'organizer.team.member_removed',
      resourceType: 'organizer_member',
      resourceId: rows[0].id,
      metadata: { organizerId, email: rows[0].email },
    });

    return { ok: true };
  }

  async listActivity(actor: CommerceActor, limit = 50): Promise<{ items: Array<Record<string, unknown>> }> {
    const { organizerId } = await this.resolveManagedOrganizer(actor);
    const n = Math.min(100, Math.max(1, limit));

    const { rows } = await this.pool.query<{
      id: string;
      action: string;
      resource_type: string;
      resource_id: string;
      metadata: Record<string, unknown>;
      created_at: Date;
      actor_email: string | null;
    }>(
      `SELECT al.id::text, al.action, al.resource_type, al.resource_id, al.metadata, al.created_at,
              u.email AS actor_email
       FROM audit_log al
       LEFT JOIN users u ON u.id = al.actor_user_id
       WHERE al.tenant_id = $1
         AND (
           (al.resource_type = 'organizer_member' AND (al.metadata->>'organizerId') = $2)
           OR (al.resource_type = 'organizer' AND al.resource_id = $2)
           OR (al.action LIKE 'organizer.team.%' AND (al.metadata->>'organizerId') = $2)
           OR (al.action LIKE 'event.%' AND (al.metadata->>'organizerId') = $2)
         )
       ORDER BY al.created_at DESC
       LIMIT $3`,
      [actor.tenantId, organizerId, n],
    );

    return {
      items: rows.map((r) => ({
        id: r.id,
        action: r.action,
        resourceType: r.resource_type,
        resourceId: r.resource_id,
        metadata: r.metadata,
        createdAt: r.created_at.toISOString(),
        actorEmail: r.actor_email,
        label: this.labelForAction(r.action),
      })),
    };
  }

  async myMembership(actor: CommerceActor) {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    const role = await this.access.resolveOrgRole(actor.tenantId, actor.userId, organizerId);
    return {
      organizerId,
      orgRole: role,
      capabilities: this.access.capabilitiesFor(role),
    };
  }

  private labelForAction(action: string): string {
    switch (action) {
      case 'organizer.team.invite_sent':
        return 'Invite sent';
      case 'organizer.team.invite_accepted':
        return 'Invite accepted';
      case 'organizer.team.member_removed':
        return 'Member removed';
      case 'organizer.team.role_changed':
        return 'Permission / role changed';
      default:
        if (action.startsWith('event.')) return 'Event action';
        return action;
    }
  }
}
