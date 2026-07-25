import {
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
import {
  deriveWorkspaceStatus,
  hasWorkspaceRole,
  workspacePrimaryRole,
  type WorkspaceCode,
  type WorkspaceStateDto,
} from './workspace.util';
import { resolveSignupPortalForMetadata } from './portal.util';

export interface EnsureUserResult {
  userId: string;
  email: string;
  isNewUser: boolean;
}

export interface ActivateWorkspaceResult {
  workspace: WorkspaceCode;
  status: WorkspaceStateDto['status'];
  roles: OwanbeRole[];
}

@Injectable()
export class WorkspaceService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly rolesService: RolesService,
    private readonly supabaseAdmin: SupabaseAdminService,
  ) {}

  /** Create universal user row if missing — no portal lock, no role assignment. */
  async ensureUser(user: JwtUser, displayNameHint?: string): Promise<EnsureUserResult> {
    const email = user.email?.trim();
    if (!email) {
      throw new UnprocessableEntityException({
        code: 'EMAIL_REQUIRED',
        message: 'Authenticated user must have an email',
      });
    }

    const displayName = this.resolveDisplayName(email, displayNameHint);
    let existing = await this.findUserById(user.tenantId, user.userId);

    if (existing) {
      await this.syncDisplayNameIfNeeded(user.tenantId, user.userId, email, displayName);
      return { userId: existing.id, email: existing.email, isNewUser: false };
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `INSERT INTO users (id, tenant_id, email, display_name, status, onboarding_complete)
         VALUES ($1, $2, $3, $4, 'active', false)
         ON CONFLICT (id) DO NOTHING`,
        [user.userId, user.tenantId, email, displayName],
      );
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    existing = await this.findUserById(user.tenantId, user.userId);
    if (!existing) {
      throw new UnprocessableEntityException({
        code: 'USER_PERSIST_FAILED',
        message: 'Account was authenticated but could not be saved. Please try again.',
      });
    }

    return { userId: existing.id, email: existing.email, isNewUser: true };
  }

  private resolveDisplayName(email: string, displayNameHint?: string): string {
    const hint = displayNameHint?.trim();
    if (hint && hint.length > 0) return hint;
    return email.split('@')[0] ?? email;
  }

  /** Backfill display_name when Supabase metadata is ahead of the users row. */
  private async syncDisplayNameIfNeeded(
    tenantId: string,
    userId: string,
    email: string,
    displayName: string,
  ): Promise<void> {
    const emailLocal = email.split('@')[0] ?? email;
    await this.pool.query(
      `UPDATE users
       SET display_name = $4, updated_at = now()
       WHERE id = $1 AND tenant_id = $2
         AND (
           display_name IS NULL
           OR trim(display_name) = ''
           OR display_name = $3
         )`,
      [userId, tenantId, emailLocal, displayName],
    );
  }

  async listWorkspaces(tenantId: string, userId: string): Promise<WorkspaceStateDto[]> {
    const ctx = await this.loadUserContext(tenantId, userId);
    const workspaces: WorkspaceCode[] = ['client', 'organizer', 'vendor'];
    return workspaces.map((ws) =>
      deriveWorkspaceStatus({
        workspace: ws,
        roles: ctx.roles,
        userStatus: ctx.status,
        onboardingStep: ctx.steps[ws],
        profileCompletionPct: ctx.completion[ws],
        activatedAt: ctx.activatedAt[ws],
        userOnboardingComplete: ctx.onboardingComplete,
      }),
    );
  }

  async activateWorkspace(
    user: JwtUser,
    workspace: WorkspaceCode,
    draft?: Record<string, unknown>,
  ): Promise<ActivateWorkspaceResult> {
    await this.ensureUser(user);
    const roleCode = workspacePrimaryRole(workspace);

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await this.addRole(client, user.userId, roleCode);

      switch (workspace) {
        case 'client':
          await this.upsertAttendeeProfile(client, user, draft);
          break;
        case 'organizer':
          await this.upsertOrganizerProfileStart(client, user, draft);
          break;
        case 'vendor':
          await this.upsertVendorProfileStart(client, user, draft);
          break;
      }

      // RC Phase 5: stop writing deprecated portal column; track workspace via last_active_workspace
      await client.query(
        `UPDATE users
         SET last_active_workspace = $3,
             updated_at = now()
         WHERE id = $1 AND tenant_id = $2`,
        [user.userId, user.tenantId, workspace],
      );

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    this.rolesService.invalidate(user.tenantId, user.userId);
    const roles = await this.loadRoleCodes(user.userId);
    const row = await this.findUserById(user.tenantId, user.userId);

    await this.supabaseAdmin.syncUserAppMetadata({
      userId: user.userId,
      tenantId: user.tenantId,
      roles,
      signupPortal: resolveSignupPortalForMetadata(row?.signup_portal_deprecated, roles),
      onboardingComplete: row?.onboarding_complete ?? false,
    });

    const states = await this.listWorkspaces(user.tenantId, user.userId);
    const state = states.find((s) => s.workspace === workspace)!;

    return {
      workspace,
      status: state.status,
      roles,
    };
  }

  async saveOnboardingDraft(
    user: JwtUser,
    workspace: WorkspaceCode,
    draft: Record<string, unknown>,
    step?: string,
    completionPct?: number,
  ): Promise<WorkspaceStateDto> {
    await this.ensureUser(user);

    switch (workspace) {
      case 'client':
        await this.pool.query(
          `INSERT INTO attendee_profiles (tenant_id, user_id, onboarding_draft, onboarding_step, updated_at)
           VALUES ($1, $2, $3::jsonb, COALESCE($4, 'in_progress'), now())
           ON CONFLICT (tenant_id, user_id) DO UPDATE SET
             onboarding_draft = EXCLUDED.onboarding_draft,
             onboarding_step = COALESCE($4, attendee_profiles.onboarding_step),
             updated_at = now()`,
          [user.tenantId, user.userId, JSON.stringify(draft), step ?? null],
        );
        break;
      case 'organizer':
        await this.pool.query(
          `INSERT INTO organizer_profiles (tenant_id, user_id, onboarding_draft, onboarding_step, profile_completion_pct, updated_at)
           VALUES ($1, $2, $3::jsonb, COALESCE($4, 'profile'), COALESCE($5, 0), now())
           ON CONFLICT (tenant_id, user_id) DO UPDATE SET
             onboarding_draft = EXCLUDED.onboarding_draft,
             onboarding_step = COALESCE($4, organizer_profiles.onboarding_step),
             profile_completion_pct = COALESCE($5, organizer_profiles.profile_completion_pct),
             updated_at = now()`,
          [user.tenantId, user.userId, JSON.stringify(draft), step ?? null, completionPct ?? null],
        );
        break;
      case 'vendor':
        await this.pool.query(
          `INSERT INTO vendor_profiles (tenant_id, user_id, onboarding_draft, onboarding_step, profile_completion_pct, updated_at)
           VALUES ($1, $2, $3::jsonb, COALESCE($4, 'personal'), COALESCE($5, 0), now())
           ON CONFLICT (tenant_id, user_id) DO UPDATE SET
             onboarding_draft = EXCLUDED.onboarding_draft,
             onboarding_step = COALESCE($4, vendor_profiles.onboarding_step),
             profile_completion_pct = COALESCE($5, vendor_profiles.profile_completion_pct),
             updated_at = now()`,
          [user.tenantId, user.userId, JSON.stringify(draft), step ?? null, completionPct ?? null],
        );
        break;
    }

    const states = await this.listWorkspaces(user.tenantId, user.userId);
    return states.find((s) => s.workspace === workspace)!;
  }

  async setActiveWorkspace(user: JwtUser, workspace: WorkspaceCode): Promise<void> {
    const ctx = await this.loadUserContext(user.tenantId, user.userId);
    if (!hasWorkspaceRole(ctx.roles, workspace)) {
      throw new NotFoundException({
        code: 'WORKSPACE_NOT_ACTIVE',
        message: `Workspace "${workspace}" is not activated for this account`,
      });
    }
    await this.pool.query(
      `UPDATE users SET last_active_workspace = $3, updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [user.userId, user.tenantId, workspace],
    );
  }

  private async loadUserContext(tenantId: string, userId: string) {
    const user = await this.findUserById(tenantId, userId);
    if (!user) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'User not found' });
    }

    const roles = await this.loadRoleCodes(userId);

    const attendee = await this.pool.query<{ onboarding_step: string; profile_completion_pct: number; activated_at: Date | null }>(
      `SELECT onboarding_step, 0 AS profile_completion_pct, activated_at
       FROM attendee_profiles WHERE tenant_id = $1 AND user_id = $2`,
      [tenantId, userId],
    );
    const organizer = await this.pool.query<{ onboarding_step: string; profile_completion_pct: number; activated_at: Date | null }>(
      `SELECT onboarding_step, profile_completion_pct, activated_at
       FROM organizer_profiles WHERE tenant_id = $1 AND user_id = $2`,
      [tenantId, userId],
    );
    const vendor = await this.pool.query<{ onboarding_step: string; profile_completion_pct: number; activated_at: Date | null }>(
      `SELECT onboarding_step, profile_completion_pct, activated_at
       FROM vendor_profiles WHERE tenant_id = $1 AND user_id = $2`,
      [tenantId, userId],
    );

    const a = attendee.rows[0];
    const o = organizer.rows[0];
    const v = vendor.rows[0];

    return {
      status: user.status ?? 'active',
      roles,
      onboardingComplete: user.onboarding_complete,
      steps: {
        client: a?.onboarding_step ?? (roles.includes('client') ? 'complete' : null),
        organizer: o?.onboarding_step ?? null,
        vendor: v?.onboarding_step ?? null,
      } as Record<WorkspaceCode, string | null>,
      completion: {
        client: roles.includes('client') && user.onboarding_complete ? 100 : 0,
        organizer: o?.profile_completion_pct ?? 0,
        vendor: v?.profile_completion_pct ?? 0,
      } as Record<WorkspaceCode, number>,
      activatedAt: {
        client: a?.activated_at ?? (roles.includes('client') && user.onboarding_complete ? new Date() : null),
        organizer: o?.activated_at ?? (o?.onboarding_step === 'complete' ? new Date() : null),
        vendor: v?.activated_at ?? null,
      } as Record<WorkspaceCode, Date | null>,
    };
  }

  private async findUserById(tenantId: string, userId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      email: string;
      display_name: string | null;
      signup_portal_deprecated: string | null;
      onboarding_complete: boolean;
      status: string;
      last_active_workspace: string | null;
    }>(
      `SELECT id, email, display_name, signup_portal_deprecated, onboarding_complete, status, last_active_workspace
       FROM users WHERE id = $1 AND tenant_id = $2`,
      [userId, tenantId],
    );
    return rows[0] ?? null;
  }

  private async loadRoleCodes(userId: string): Promise<OwanbeRole[]> {
    const { rows } = await this.pool.query<{ code: string }>(
      `SELECT r.code FROM user_roles ur
       INNER JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = $1`,
      [userId],
    );
    return rows.map((r) => r.code as OwanbeRole);
  }

  private async addRole(client: PoolClient, userId: string, roleCode: OwanbeRole): Promise<void> {
    const { rows } = await client.query<{ id: number }>(
      `SELECT id FROM roles WHERE code = $1`,
      [roleCode],
    );
    const roleId = rows[0]?.id;
    if (!roleId) {
      throw new UnprocessableEntityException({
        code: 'ROLE_NOT_CONFIGURED',
        message: `Role "${roleCode}" is not configured`,
      });
    }
    await client.query(
      `INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)
       ON CONFLICT (user_id, role_id) DO NOTHING`,
      [userId, roleId],
    );
  }

  private async upsertAttendeeProfile(
    client: PoolClient,
    user: JwtUser,
    draft?: Record<string, unknown>,
  ): Promise<void> {
    await client.query(
      `INSERT INTO attendee_profiles (tenant_id, user_id, onboarding_step, onboarding_draft, updated_at)
       VALUES ($1, $2, 'in_progress', $3::jsonb, now())
       ON CONFLICT (tenant_id, user_id) DO UPDATE SET
         onboarding_step = CASE WHEN attendee_profiles.onboarding_step = 'complete'
           THEN attendee_profiles.onboarding_step ELSE 'in_progress' END,
         onboarding_draft = COALESCE($3::jsonb, attendee_profiles.onboarding_draft),
         updated_at = now()`,
      [user.tenantId, user.userId, JSON.stringify(draft ?? {})],
    );
  }

  private async upsertOrganizerProfileStart(
    client: PoolClient,
    user: JwtUser,
    draft?: Record<string, unknown>,
  ): Promise<void> {
    const displayName = user.email?.split('@')[0] ?? 'Organizer';
    const organizerId = await this.ensureOrganizerBusinessRow(client, user, displayName);
    await client.query(
      `INSERT INTO organizer_profiles (tenant_id, user_id, organizer_id, display_name, onboarding_step, onboarding_draft, updated_at)
       VALUES ($1, $2, $3, $4, 'profile', $5::jsonb, now())
       ON CONFLICT (tenant_id, user_id) DO UPDATE SET
         organizer_id = COALESCE(organizer_profiles.organizer_id, EXCLUDED.organizer_id),
         onboarding_draft = COALESCE($5::jsonb, organizer_profiles.onboarding_draft),
         updated_at = now()`,
      [user.tenantId, user.userId, organizerId, displayName, JSON.stringify(draft ?? {})],
    );
  }

  private async upsertVendorProfileStart(
    client: PoolClient,
    user: JwtUser,
    draft?: Record<string, unknown>,
  ): Promise<void> {
    const businessName = user.email?.split('@')[0] ?? 'Vendor';
    const vendorId = await this.ensureVendorBusinessRow(client, user, businessName);
    await client.query(
      `INSERT INTO vendor_profiles (tenant_id, user_id, vendor_id, business_name, onboarding_step, onboarding_draft, updated_at)
       VALUES ($1, $2, $3, $4, 'personal', $5::jsonb, now())
       ON CONFLICT (tenant_id, user_id) DO UPDATE SET
         vendor_id = COALESCE(vendor_profiles.vendor_id, EXCLUDED.vendor_id),
         business_name = COALESCE(NULLIF(EXCLUDED.business_name, ''), vendor_profiles.business_name),
         onboarding_draft = COALESCE($5::jsonb, vendor_profiles.onboarding_draft),
         updated_at = now()`,
      [user.tenantId, user.userId, vendorId, businessName, JSON.stringify(draft ?? {})],
    );
  }

  /** Ensures organizers row exists for unified identity (one user, many workspaces). */
  async ensureOrganizerBusiness(user: JwtUser, displayName?: string): Promise<string> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const id = await this.ensureOrganizerBusinessRow(
        client,
        user,
        displayName ?? user.email?.split('@')[0] ?? 'Organizer',
      );
      await client.query('COMMIT');
      return id;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /** Ensures vendors row exists for unified identity (one user, many workspaces). */
  async ensureVendorBusiness(user: JwtUser, businessName?: string): Promise<string> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const id = await this.ensureVendorBusinessRow(
        client,
        user,
        businessName ?? user.email?.split('@')[0] ?? 'Vendor',
      );
      await client.query('COMMIT');
      return id;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  private async ensureOrganizerBusinessRow(
    client: PoolClient,
    user: JwtUser,
    displayName: string,
  ): Promise<string> {
    const { rows } = await client.query<{ id: string }>(
      `SELECT id FROM organizers WHERE tenant_id = $1 AND owner_user_id = $2 LIMIT 1`,
      [user.tenantId, user.userId],
    );
    if (rows[0]?.id) return rows[0].id;

    const slug =
      displayName
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '')
        .slice(0, 48) || `org-${user.userId.slice(0, 8)}`;
    const ins = await client.query<{ id: string }>(
      `INSERT INTO organizers (tenant_id, owner_user_id, display_name, slug, status)
       VALUES ($1, $2, $3, $4, 'active')
       RETURNING id`,
      [user.tenantId, user.userId, displayName, slug],
    );
    return ins.rows[0]!.id;
  }

  private async ensureVendorBusinessRow(
    client: PoolClient,
    user: JwtUser,
    businessName: string,
  ): Promise<string> {
    const { rows } = await client.query<{ id: string }>(
      `SELECT id FROM vendors WHERE tenant_id = $1 AND owner_user_id = $2 LIMIT 1`,
      [user.tenantId, user.userId],
    );
    if (rows[0]?.id) return rows[0].id;

    const slug =
      businessName
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '')
        .slice(0, 48) || `vendor-${user.userId.slice(0, 8)}`;
    const ins = await client.query<{ id: string }>(
      `INSERT INTO vendors (tenant_id, owner_user_id, business_name, slug, status, country_code, city)
       VALUES ($1, $2, $3, $4, 'active', 'NG', '')
       RETURNING id`,
      [user.tenantId, user.userId, businessName, slug],
    );
    return ins.rows[0]!.id;
  }
}
