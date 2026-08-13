import {
  ConflictException,
  ForbiddenException,
  Injectable,
  Inject,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Pool, PoolClient } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { JwtUser, OwanbeRole } from '../../common/types/jwt-user';
import { RolesService } from '../../roles/roles.service';
import { SupabaseAdminService } from '../../integrations/supabase/supabase-admin.service';
import { WorkspaceService } from './workspace.service';
import {
  onboardingCompleteForPortal,
  portalFromRoles,
  portalToPrimaryRole,
  rolesMatchPortal,
  type SignupPortal,
} from './portal.util';

export interface CompleteSignupResult {
  userId: string;
  portal: SignupPortal;
  roles: OwanbeRole[];
  signupPortal: SignupPortal;
  onboardingComplete: boolean;
  isNewRegistration: boolean;
}

export interface ValidatePortalResult {
  userId: string;
  portal: SignupPortal;
  roles: OwanbeRole[];
  signupPortal: SignupPortal;
  onboardingComplete: boolean;
}

export interface PortalLookupResult {
  registered: boolean;
  portal?: SignupPortal;
  signupPortal?: SignupPortal;
}

interface UserRow {
  id: string;
  email: string;
  display_name: string | null;
  signup_portal_deprecated: SignupPortal | null;
  onboarding_complete: boolean;
}

@Injectable()
export class AuthSignupService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly rolesService: RolesService,
    private readonly supabaseAdmin: SupabaseAdminService,
    private readonly workspaces: WorkspaceService,
  ) {}

  async completeSignup(
    user: JwtUser,
    portal: SignupPortal,
    displayNameHint?: string,
  ): Promise<CompleteSignupResult> {
    if (portal === 'admin') {
      throw new ForbiddenException({
        code: 'ADMIN_PROVISIONED',
        message: 'Admin accounts are provisioned by platform staff',
      });
    }

    const email = user.email?.trim();
    if (!email) {
      throw new UnprocessableEntityException({
        code: 'EMAIL_REQUIRED',
        message: 'Authenticated user must have an email to complete signup',
      });
    }

    const client = await this.pool.connect();
    let isNewRegistration = false;
    try {
      await client.query('BEGIN');

      const emailOwner = await this.findUserByEmail(client, user.tenantId, email);
      if (emailOwner && emailOwner.id !== user.userId) {
        throw new ConflictException({
          code: 'ROLE_MISMATCH',
          message: 'This email is already registered to another Owambe account',
        });
      }

      let row = await this.findUserById(client, user.tenantId, user.userId);
      const existingRoles = row ? await this.loadRoleCodes(client, row.id) : [];

      if (row?.signup_portal_deprecated && row.signup_portal_deprecated !== portal) {
        throw new ConflictException({
          code: 'ROLE_MISMATCH',
          message: `Account is registered for the ${row.signup_portal_deprecated} portal, not ${portal}`,
        });
      }

      if (existingRoles.length > 0 && !rolesMatchPortal(existingRoles, portal)) {
        const actual = portalFromRoles(existingRoles);
        throw new ConflictException({
          code: 'ROLE_MISMATCH',
          message: actual
            ? `Account is registered for the ${actual} portal, not ${portal}`
            : 'Account roles do not match this portal',
        });
      }

      const roleCode = portalToPrimaryRole(portal);
      const onboardingComplete = row?.onboarding_complete ?? onboardingCompleteForPortal(portal);

      if (!row) {
        isNewRegistration = true;
        row = await this.insertUser(client, {
          userId: user.userId,
          tenantId: user.tenantId,
          email,
          displayName: displayNameHint?.trim() || email.split('@')[0],
          portal,
          onboardingComplete,
        });
        await this.assignSingleRole(client, row.id, roleCode);
      } else if (existingRoles.length === 0) {
        isNewRegistration = true;
        await client.query(
          `UPDATE users
           SET signup_portal_deprecated = COALESCE(signup_portal_deprecated, $3),
               onboarding_complete = COALESCE(onboarding_complete, $4),
               status = 'active',
               updated_at = now()
           WHERE id = $1 AND tenant_id = $2`,
          [row.id, user.tenantId, portal, onboardingComplete],
        );
        row.signup_portal_deprecated = row.signup_portal_deprecated ?? portal;
        await this.assignSingleRole(client, row.id, roleCode);
      } else if (!row.signup_portal_deprecated) {
        await client.query(
          `UPDATE users SET signup_portal_deprecated = $3, updated_at = now()
           WHERE id = $1 AND tenant_id = $2`,
          [row.id, user.tenantId, portal],
        );
        row.signup_portal_deprecated = portal;
      }

      await client.query('COMMIT');

      const roles = await this.loadRoleCodes(this.pool, row.id);
      this.rolesService.invalidate(user.tenantId, user.userId);

      await this.supabaseAdmin.syncUserAppMetadata({
        userId: user.userId,
        tenantId: user.tenantId,
        roles,
        signupPortal: row.signup_portal_deprecated ?? portal,
        onboardingComplete: row.onboarding_complete,
      });

      return {
        userId: row.id,
        portal,
        roles,
        signupPortal: (row.signup_portal_deprecated ?? portal) as SignupPortal,
        onboardingComplete: row.onboarding_complete,
        isNewRegistration,
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async validatePortal(user: JwtUser, portal: SignupPortal): Promise<ValidatePortalResult> {
    const row = await this.findUserById(this.pool, user.tenantId, user.userId);
    if (!row) {
      throw new NotFoundException({
        code: 'NOT_REGISTERED',
        message: 'Complete signup for this portal before signing in',
      });
    }

    const roles = await this.loadRoleCodes(this.pool, row.id);
    if (roles.length === 0) {
      throw new NotFoundException({
        code: 'NOT_REGISTERED',
        message: 'Complete signup for this portal before signing in',
      });
    }

    const signupPortal = (row.signup_portal_deprecated ?? portalFromRoles(roles)) as SignupPortal | null;
    if (signupPortal && signupPortal !== portal) {
      throw new ConflictException({
        code: 'ROLE_MISMATCH',
        message: `Account is registered for the ${signupPortal} portal, not ${portal}`,
      });
    }

    if (!rolesMatchPortal(roles, portal)) {
      const actual = portalFromRoles(roles);
      throw new ConflictException({
        code: 'ROLE_MISMATCH',
        message: actual
          ? `Account is registered for the ${actual} portal, not ${portal}`
          : 'Account roles do not match this portal',
      });
    }

    return {
      userId: row.id,
      portal,
      roles,
      signupPortal: (signupPortal ?? portal) as SignupPortal,
      onboardingComplete: row.onboarding_complete,
    };
  }

  async lookupPortalByEmail(tenantId: string, email: string): Promise<PortalLookupResult> {
    const normalized = email.trim().toLowerCase();
    if (!normalized.includes('@')) {
      throw new UnprocessableEntityException({
        code: 'INVALID_EMAIL',
        message: 'A valid email address is required',
      });
    }

    const { rows } = await this.pool.query<UserRow & { roles: string[] | null }>(
      `SELECT u.id, u.email, u.display_name, u.signup_portal_deprecated, u.onboarding_complete,
        COALESCE(array_agg(r.code ORDER BY r.code) FILTER (WHERE r.code IS NOT NULL), '{}') AS roles
       FROM users u
       LEFT JOIN user_roles ur ON ur.user_id = u.id
       LEFT JOIN roles r ON r.id = ur.role_id
       WHERE u.tenant_id = $1 AND u.email_normalized = $2
       GROUP BY u.id, u.email, u.display_name, u.signup_portal_deprecated, u.onboarding_complete`,
      [tenantId, normalized],
    );

    const row = rows[0];
    if (!row) {
      return { registered: false };
    }

    const roles = (row.roles ?? []) as OwanbeRole[];
    const portal = (row.signup_portal_deprecated ?? portalFromRoles(roles)) as SignupPortal | undefined;
    if (!portal) {
      return { registered: true };
    }

    return {
      registered: true,
      portal,
      signupPortal: portal,
    };
  }

  async migrateUserPortal(
    tenantId: string,
    actorUserId: string,
    email: string,
    targetPortal: SignupPortal,
    reason: string,
  ): Promise<CompleteSignupResult> {
    const row = await this.findUserByEmail(this.pool, tenantId, email);
    if (!row) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'User not found for email' });
    }

    const roleCode = portalToPrimaryRole(targetPortal);
    const onboardingComplete = onboardingCompleteForPortal(targetPortal);
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `UPDATE users
         SET signup_portal_deprecated = $3, onboarding_complete = $4, updated_at = now()
         WHERE id = $1 AND tenant_id = $2`,
        [row.id, tenantId, targetPortal, onboardingComplete],
      );
      await client.query(`DELETE FROM user_roles WHERE user_id = $1`, [row.id]);
      await this.assignSingleRole(client, row.id, roleCode);
      await client.query(
        `INSERT INTO audit_log (tenant_id, actor_user_id, action, resource_type, resource_id, metadata)
         VALUES ($1, $2, 'user.portal_migrated', 'user', $3, $4::jsonb)`,
        [
          tenantId,
          actorUserId,
          row.id,
          JSON.stringify({ email, targetPortal, reason }),
        ],
      );
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    this.rolesService.invalidate(tenantId, row.id);
    const roles = await this.loadRoleCodes(this.pool, row.id);
    await this.supabaseAdmin.syncUserAppMetadata({
      userId: row.id,
      tenantId,
      roles,
      signupPortal: targetPortal,
      onboardingComplete,
    });

    return {
      userId: row.id,
      portal: targetPortal,
      roles,
      signupPortal: targetPortal,
      onboardingComplete,
      isNewRegistration: false,
    };
  }

  async completeOnboarding(
    user: JwtUser,
    input?: {
      displayName?: string;
      phoneE164?: string;
      workspace?: 'client' | 'organizer' | 'vendor';
    },
  ): Promise<{ userId: string; onboardingComplete: boolean }> {
    let row = await this.findUserById(this.pool, user.tenantId, user.userId);
    if (!row) {
      await this.workspaces.ensureUser(user, input?.displayName);
      row = await this.findUserById(this.pool, user.tenantId, user.userId);
      if (!row) {
        throw new NotFoundException({
          code: 'NOT_REGISTERED',
          message: 'Complete signup before finishing onboarding',
        });
      }
    }

    const displayName = input?.displayName?.trim();
    const phoneE164 = input?.phoneE164?.trim();

    await this.pool.query(
      `UPDATE users
       SET display_name = COALESCE(NULLIF($3, ''), display_name),
           phone_e164 = COALESCE(NULLIF($4, ''), phone_e164),
           updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [user.userId, user.tenantId, displayName ?? '', phoneE164 ?? ''],
    );

    if (input?.workspace) {
      await this.markWorkspaceOnboardingComplete(user, input.workspace, displayName);
      if (input.workspace === 'client') {
        await this.pool.query(
          `UPDATE users SET onboarding_complete = true, updated_at = now()
           WHERE id = $1 AND tenant_id = $2`,
          [user.userId, user.tenantId],
        );
      }
    } else {
      await this.pool.query(
        `UPDATE users SET onboarding_complete = true, updated_at = now()
         WHERE id = $1 AND tenant_id = $2`,
        [user.userId, user.tenantId],
      );
    }

    this.rolesService.invalidate(user.tenantId, user.userId);
    const roles = await this.loadRoleCodes(this.pool, user.userId);
    const refreshed = await this.findUserById(this.pool, user.tenantId, user.userId);
    await this.supabaseAdmin.syncUserAppMetadata({
      userId: user.userId,
      tenantId: user.tenantId,
      roles,
      signupPortal: refreshed?.signup_portal_deprecated ?? row.signup_portal_deprecated,
      onboardingComplete: refreshed?.onboarding_complete ?? true,
    });

    return {
      userId: user.userId,
      onboardingComplete: refreshed?.onboarding_complete ?? true,
    };
  }

  private async markWorkspaceOnboardingComplete(
    user: JwtUser,
    workspace: 'client' | 'organizer' | 'vendor',
    displayName?: string,
  ): Promise<void> {
    const name = displayName?.trim() || user.email?.split('@')[0] || 'User';
    const roleCode = workspace === 'client' ? 'client' : workspace;
    await this.pool.query(
      `INSERT INTO user_roles (user_id, role_id)
       SELECT $1, r.id FROM roles r WHERE r.code = $2
       ON CONFLICT DO NOTHING`,
      [user.userId, roleCode],
    );
    switch (workspace) {
      case 'client':
        await this.pool.query(
          `INSERT INTO attendee_profiles (tenant_id, user_id, onboarding_step, activated_at, updated_at)
           VALUES ($1, $2, 'complete', now(), now())
           ON CONFLICT (tenant_id, user_id) DO UPDATE SET
             onboarding_step = 'complete',
             activated_at = COALESCE(attendee_profiles.activated_at, now()),
             updated_at = now()`,
          [user.tenantId, user.userId],
        );
        break;
      case 'organizer': {
        const organizerId = await this.workspaces.ensureOrganizerBusiness(user, name);
        await this.pool.query(
          `INSERT INTO organizer_profiles (tenant_id, user_id, organizer_id, display_name, onboarding_step, profile_completion_pct, activated_at, updated_at)
           VALUES ($1, $2, $3, $4, 'complete', 100, now(), now())
           ON CONFLICT (tenant_id, user_id) DO UPDATE SET
             organizer_id = COALESCE(organizer_profiles.organizer_id, EXCLUDED.organizer_id),
             display_name = COALESCE(NULLIF($4, ''), organizer_profiles.display_name),
             onboarding_step = 'complete',
             profile_completion_pct = 100,
             activated_at = COALESCE(organizer_profiles.activated_at, now()),
             updated_at = now()`,
          [user.tenantId, user.userId, organizerId, name],
        );
        break;
      }
      case 'vendor': {
        const vendorId = await this.workspaces.ensureVendorBusiness(user, name);
        await this.pool.query(
          `INSERT INTO vendor_profiles (tenant_id, user_id, vendor_id, business_name, onboarding_step, profile_completion_pct, activated_at, updated_at)
           VALUES ($1, $2, $3, $4, 'complete', 100, now(), now())
           ON CONFLICT (tenant_id, user_id) DO UPDATE SET
             vendor_id = COALESCE(vendor_profiles.vendor_id, EXCLUDED.vendor_id),
             business_name = COALESCE(NULLIF($4, ''), vendor_profiles.business_name),
             onboarding_step = 'complete',
             profile_completion_pct = 100,
             activated_at = COALESCE(vendor_profiles.activated_at, now()),
             updated_at = now()`,
          [user.tenantId, user.userId, vendorId, name],
        );
        break;
      }
    }
  }

  private async findUserById(
    db: Pool | PoolClient,
    tenantId: string,
    userId: string,
  ): Promise<UserRow | null> {
    const { rows } = await db.query<UserRow>(
      `SELECT id, email, display_name, signup_portal_deprecated, onboarding_complete
       FROM users WHERE id = $1 AND tenant_id = $2`,
      [userId, tenantId],
    );
    return rows[0] ?? null;
  }

  private async findUserByEmail(
    db: Pool | PoolClient,
    tenantId: string,
    email: string,
  ): Promise<UserRow | null> {
    const { rows } = await db.query<UserRow>(
      `SELECT id, email, display_name, signup_portal_deprecated, onboarding_complete
       FROM users WHERE tenant_id = $1 AND email_normalized = lower(trim($2))`,
      [tenantId, email],
    );
    return rows[0] ?? null;
  }

  private async insertUser(
    client: PoolClient,
    input: {
      userId: string;
      tenantId: string;
      email: string;
      displayName: string;
      portal: SignupPortal;
      onboardingComplete: boolean;
    },
  ): Promise<UserRow> {
    const { rows } = await client.query<UserRow>(
      `INSERT INTO users (id, tenant_id, email, display_name, status, signup_portal_deprecated, onboarding_complete)
       VALUES ($1, $2, $3, $4, 'active', $5, $6)
       RETURNING id, email, display_name, signup_portal_deprecated, onboarding_complete`,
      [
        input.userId,
        input.tenantId,
        input.email,
        input.displayName,
        input.portal,
        input.onboardingComplete,
      ],
    );
    return rows[0]!;
  }

  private async loadRoleCodes(db: Pool | PoolClient, userId: string): Promise<OwanbeRole[]> {
    const { rows } = await db.query<{ code: string }>(
      `SELECT r.code FROM user_roles ur
       INNER JOIN roles r ON r.id = ur.role_id
       WHERE ur.user_id = $1`,
      [userId],
    );
    return rows.map((r) => r.code as OwanbeRole);
  }

  private async assignSingleRole(
    client: PoolClient,
    userId: string,
    roleCode: OwanbeRole,
  ): Promise<void> {
    const { rows } = await client.query<{ id: number }>(
      `SELECT id FROM roles WHERE code = $1`,
      [roleCode],
    );
    const roleId = rows[0]?.id;
    if (!roleId) {
      throw new UnprocessableEntityException({
        code: 'ROLE_NOT_CONFIGURED',
        message: `Role "${roleCode}" is not configured in the database`,
      });
    }
    await client.query(`DELETE FROM user_roles WHERE user_id = $1`, [userId]);
    await client.query(
      `INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)
       ON CONFLICT (user_id, role_id) DO NOTHING`,
      [userId, roleId],
    );
  }
}
