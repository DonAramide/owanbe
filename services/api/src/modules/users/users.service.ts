import { BadRequestException, Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { OwanbeRole } from '../../common/types/jwt-user';
import type { WorkspaceStateDto } from './workspace.util';
import { WorkspaceService } from './workspace.service';
import {
  assertSocialLinkUrls,
  sanitizeSocialLinks,
  type UpdateGlobalProfileDto,
} from './dto/update-global-profile.dto';

export interface GlobalSocialLinksDto {
  instagram?: string;
  twitter?: string;
  linkedin?: string;
  facebook?: string;
  tiktok?: string;
  youtube?: string;
  website?: string;
}

export interface MeResponseDto {
  userId: string;
  email: string;
  displayName: string | null;
  firstName: string | null;
  lastName: string | null;
  avatarUrl: string | null;
  bio: string | null;
  occupation: string | null;
  company: string | null;
  interests: string[];
  socialLinks: GlobalSocialLinksDto;
  tenantId: string;
  roles: OwanbeRole[];
  signupPortal: string | null;
  onboardingComplete: boolean;
  lastActiveWorkspace: string | null;
  workspaces: WorkspaceStateDto[];
  identityVersion: '2.0';
}

/** Public / peer-visible attendee profile card (privacy-filtered). */
export interface PublicAttendeeProfileDto {
  userId: string;
  visible: boolean;
  isSelf: boolean;
  displayName: string;
  preferredDisplayName: string | null;
  avatarUrl: string | null;
  bio: string | null;
  occupation: string | null;
  company: string | null;
  interests: string[];
  preferredEventCategories: string[];
  accessibilityRequirements: string | null;
  dietaryPreferences: string | null;
  socialLinks: GlobalSocialLinksDto;
  privacyShowToOrganizers: boolean;
  privacyShowToAttendees: boolean;
  visibilityReason?: string;
}

@Injectable()
export class UsersService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly workspaces: WorkspaceService,
  ) {}

  async getMe(tenantId: string, userId: string): Promise<MeResponseDto> {
    const { rows } = await this.pool.query<{
      id: string;
      email: string;
      display_name: string | null;
      first_name: string | null;
      last_name: string | null;
      avatar_url: string | null;
      bio: string | null;
      occupation: string | null;
      company: string | null;
      interests: unknown;
      social_links: unknown;
      tenant_id: string;
      signup_portal_deprecated: string | null;
      onboarding_complete: boolean;
      last_active_workspace: string | null;
      roles: string[] | null;
    }>(
      `SELECT u.id, u.email, u.display_name, u.first_name, u.last_name, u.avatar_url, u.bio,
        u.occupation, u.company, u.interests, u.social_links,
        u.tenant_id, u.signup_portal_deprecated, u.onboarding_complete,
        u.last_active_workspace,
        COALESCE(array_agg(r.code ORDER BY r.code) FILTER (WHERE r.code IS NOT NULL), '{}') AS roles
       FROM users u
       LEFT JOIN user_roles ur ON ur.user_id = u.id
       LEFT JOIN roles r ON r.id = ur.role_id
       WHERE u.id = $1 AND u.tenant_id = $2
       GROUP BY u.id, u.email, u.display_name, u.first_name, u.last_name, u.avatar_url, u.bio,
         u.occupation, u.company, u.interests, u.social_links,
         u.tenant_id, u.signup_portal_deprecated, u.onboarding_complete, u.last_active_workspace`,
      [userId, tenantId],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'User not found in tenant' });
    }

    let workspaceStates: WorkspaceStateDto[] = [];
    try {
      workspaceStates = await this.workspaces.listWorkspaces(tenantId, userId);
    } catch {
      workspaceStates = [];
    }

    return this.toMeDto(row, workspaceStates);
  }

  /**
   * Updates global Hub profile fields on `users` only.
   * Never writes attendee_profiles / organizer_profiles / vendor_profiles.
   */
  async updateGlobalProfile(
    tenantId: string,
    userId: string,
    dto: UpdateGlobalProfileDto,
  ): Promise<MeResponseDto> {
    const existing = await this.findUserRow(tenantId, userId);
    if (!existing) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'User not found in tenant' });
    }

    const sets: string[] = [];
    const params: unknown[] = [userId, tenantId];

    const push = (column: string, value: unknown) => {
      params.push(value);
      sets.push(`${column} = $${params.length}`);
    };

    if (dto.firstName !== undefined) push('first_name', this.trimOrNull(dto.firstName));
    if (dto.lastName !== undefined) push('last_name', this.trimOrNull(dto.lastName));
    if (dto.displayName !== undefined) push('display_name', this.trimOrNull(dto.displayName));
    if (dto.avatarUrl !== undefined) {
      const url = dto.avatarUrl == null ? null : String(dto.avatarUrl).trim();
      push('avatar_url', url && url.length > 0 ? url : null);
    }
    if (dto.bio !== undefined) push('bio', this.trimOrNull(dto.bio));
    if (dto.occupation !== undefined) push('occupation', this.trimOrNull(dto.occupation));
    if (dto.company !== undefined) push('company', this.trimOrNull(dto.company));

    if (dto.interests !== undefined) {
      const interests = dto.interests
        .map((i) => String(i).trim())
        .filter((i) => i.length > 0)
        .slice(0, 24);
      params.push(JSON.stringify(interests));
      sets.push(`interests = $${params.length}::jsonb`);
    }

    if (dto.socialLinks !== undefined) {
      const sanitized = sanitizeSocialLinks(dto.socialLinks) ?? {};
      try {
        assertSocialLinkUrls(sanitized);
      } catch (err) {
        const e = err as Error & { code?: string; key?: string };
        throw new BadRequestException({
          code: e.code ?? 'INVALID_SOCIAL_URL',
          message: e.message,
          key: e.key,
        });
      }
      params.push(JSON.stringify(sanitized));
      sets.push(`social_links = $${params.length}::jsonb`);
    }

    // Derive display_name from first/last when displayName omitted but names change.
    if (dto.displayName === undefined && (dto.firstName !== undefined || dto.lastName !== undefined)) {
      const first = dto.firstName !== undefined ? this.trimOrNull(dto.firstName) : existing.first_name;
      const last = dto.lastName !== undefined ? this.trimOrNull(dto.lastName) : existing.last_name;
      const derived = [first, last].filter(Boolean).join(' ').trim();
      if (derived) push('display_name', derived);
    }

    if (sets.length === 0) {
      return this.getMe(tenantId, userId);
    }

    sets.push('updated_at = now()');
    await this.pool.query(
      `UPDATE users SET ${sets.join(', ')} WHERE id = $1 AND tenant_id = $2`,
      params,
    );

    return this.getMe(tenantId, userId);
  }

  /**
   * Privacy-aware attendee profile card for self or other users.
   * Does not expose emergency contact / notification prefs.
   */
  async getPublicAttendeeProfile(
    tenantId: string,
    viewerUserId: string,
    targetUserId: string,
  ): Promise<PublicAttendeeProfileDto> {
    const { rows } = await this.pool.query<{
      id: string;
      display_name: string | null;
      first_name: string | null;
      last_name: string | null;
      avatar_url: string | null;
      bio: string | null;
      occupation: string | null;
      company: string | null;
      interests: unknown;
      preferred_display_name: string | null;
      preferred_event_categories: unknown;
      attendee_interests: unknown;
      accessibility_requirements: string | null;
      dietary_preferences: string | null;
      privacy_show_to_organizers: boolean | null;
      privacy_show_to_attendees: boolean | null;
      social_links: unknown;
      viewer_roles: string[] | null;
    }>(
      `SELECT u.id, u.display_name, u.first_name, u.last_name, u.avatar_url, u.bio,
              u.occupation, u.company, u.interests, u.social_links,
              ap.preferred_display_name, ap.preferred_event_categories,
              ap.interests AS attendee_interests,
              ap.accessibility_requirements, ap.dietary_preferences,
              ap.privacy_show_to_organizers, ap.privacy_show_to_attendees,
              COALESCE(
                (SELECT array_agg(r.code)
                 FROM user_roles ur
                 JOIN roles r ON r.id = ur.role_id
                 WHERE ur.user_id = $3),
                '{}'
              ) AS viewer_roles
       FROM users u
       LEFT JOIN attendee_profiles ap ON ap.user_id = u.id AND ap.tenant_id = u.tenant_id
       WHERE u.id = $1 AND u.tenant_id = $2`,
      [targetUserId, tenantId, viewerUserId],
    );

    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'NOT_FOUND', message: 'User not found' });
    }

    const isSelf = viewerUserId === targetUserId;
    const showToOrganizers = row.privacy_show_to_organizers ?? true;
    const showToAttendees = row.privacy_show_to_attendees ?? false;
    const viewerRoles = new Set((row.viewer_roles ?? []).map((r) => String(r)));
    const viewerIsOrganizer = viewerRoles.has('organizer') || viewerRoles.has('admin') || viewerRoles.has('super_admin');
    const viewerIsAttendee = viewerRoles.has('client') || viewerRoles.has('attendee') || isSelf;

    let visible = isSelf;
    let visibilityReason: string | undefined;
    if (!isSelf) {
      if (viewerIsOrganizer && showToOrganizers) {
        visible = true;
      } else if (viewerIsAttendee && showToAttendees) {
        visible = true;
      } else if (viewerIsOrganizer && !showToOrganizers) {
        visibilityReason = 'This attendee hides their profile from organizers.';
      } else if (!showToAttendees) {
        visibilityReason = 'This attendee hides their profile from other attendees.';
      } else {
        visibilityReason = 'Profile is not visible to you.';
      }
    }

    const displayName =
      row.preferred_display_name?.trim() ||
      row.display_name?.trim() ||
      [row.first_name, row.last_name].filter(Boolean).join(' ').trim() ||
      'Attendee';

    if (!visible) {
      return {
        userId: row.id,
        visible: false,
        isSelf,
        displayName: isSelf ? displayName : 'Attendee',
        preferredDisplayName: null,
        avatarUrl: null,
        bio: null,
        occupation: null,
        company: null,
        interests: [],
        preferredEventCategories: [],
        accessibilityRequirements: null,
        dietaryPreferences: null,
        socialLinks: {},
        privacyShowToOrganizers: showToOrganizers,
        privacyShowToAttendees: showToAttendees,
        visibilityReason,
      };
    }

    const attendeeInterests = this.parseInterests(row.attendee_interests);
    const globalInterests = this.parseInterests(row.interests);

    return {
      userId: row.id,
      visible: true,
      isSelf,
      displayName,
      preferredDisplayName: row.preferred_display_name,
      avatarUrl: row.avatar_url,
      bio: row.bio,
      occupation: row.occupation,
      company: row.company,
      interests: attendeeInterests.length > 0 ? attendeeInterests : globalInterests,
      preferredEventCategories: this.parseInterests(row.preferred_event_categories),
      accessibilityRequirements: isSelf || showToOrganizers ? row.accessibility_requirements : null,
      dietaryPreferences: isSelf || showToOrganizers ? row.dietary_preferences : null,
      socialLinks: this.parseSocialLinks(row.social_links),
      privacyShowToOrganizers: showToOrganizers,
      privacyShowToAttendees: showToAttendees,
    };
  }

  private trimOrNull(value: string): string | null {
    const t = value.trim();
    return t.length > 0 ? t : null;
  }

  private parseInterests(raw: unknown): string[] {
    if (Array.isArray(raw)) {
      return raw.map((e) => String(e)).filter((e) => e.trim().length > 0);
    }
    if (typeof raw === 'string') {
      try {
        const parsed = JSON.parse(raw) as unknown;
        return this.parseInterests(parsed);
      } catch {
        return [];
      }
    }
    return [];
  }

  private parseSocialLinks(raw: unknown): GlobalSocialLinksDto {
    if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
      const o = raw as Record<string, unknown>;
      return {
        instagram: o.instagram != null ? String(o.instagram) : undefined,
        twitter: o.twitter != null ? String(o.twitter) : undefined,
        linkedin: o.linkedin != null ? String(o.linkedin) : undefined,
        facebook: o.facebook != null ? String(o.facebook) : undefined,
        tiktok: o.tiktok != null ? String(o.tiktok) : undefined,
        youtube: o.youtube != null ? String(o.youtube) : undefined,
        website: o.website != null ? String(o.website) : undefined,
      };
    }
    if (typeof raw === 'string') {
      try {
        return this.parseSocialLinks(JSON.parse(raw));
      } catch {
        return {};
      }
    }
    return {};
  }

  private toMeDto(
    row: {
      id: string;
      email: string;
      display_name: string | null;
      first_name: string | null;
      last_name: string | null;
      avatar_url: string | null;
      bio: string | null;
      occupation: string | null;
      company: string | null;
      interests: unknown;
      social_links: unknown;
      tenant_id: string;
      signup_portal_deprecated: string | null;
      onboarding_complete: boolean;
      last_active_workspace: string | null;
      roles: string[] | null;
    },
    workspaceStates: WorkspaceStateDto[],
  ): MeResponseDto {
    return {
      userId: row.id,
      email: row.email,
      displayName: row.display_name,
      firstName: row.first_name,
      lastName: row.last_name,
      avatarUrl: row.avatar_url,
      bio: row.bio,
      occupation: row.occupation,
      company: row.company,
      interests: this.parseInterests(row.interests),
      socialLinks: this.parseSocialLinks(row.social_links),
      tenantId: row.tenant_id,
      roles: (row.roles ?? []) as OwanbeRole[],
      signupPortal: row.signup_portal_deprecated,
      onboardingComplete: row.onboarding_complete,
      lastActiveWorkspace: row.last_active_workspace,
      workspaces: workspaceStates,
      identityVersion: '2.0',
    };
  }

  private async findUserRow(tenantId: string, userId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      first_name: string | null;
      last_name: string | null;
      display_name: string | null;
    }>(
      `SELECT id, first_name, last_name, display_name FROM users WHERE id = $1 AND tenant_id = $2`,
      [userId, tenantId],
    );
    return rows[0] ?? null;
  }
}
