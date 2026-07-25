import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { UpsertAttendeeProfileDto } from './dto/upsert-attendee-profile.dto';

export interface AttendeeProfileView {
  userId: string;
  preferredDisplayName: string | null;
  preferredEventCategories: string[];
  interests: string[];
  accessibilityRequirements: string | null;
  dietaryPreferences: string | null;
  emergencyContactName: string | null;
  emergencyContactRelationship: string | null;
  emergencyContactPhone: string | null;
  notifyEmail: boolean;
  notifySms: boolean;
  notifyPush: boolean;
  privacyShowToOrganizers: boolean;
  privacyShowToAttendees: boolean;
  onboardingStep: string;
  activatedAt: string | null;
}

@Injectable()
export class AttendeeProfileService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getProfile(tenantId: string, userId: string): Promise<AttendeeProfileView> {
    await this.ensureRow(tenantId, userId);
    const row = await this.loadRow(tenantId, userId);
    if (!row) {
      throw new NotFoundException({ code: 'ATTENDEE_PROFILE_NOT_FOUND', message: 'Attendee profile not found' });
    }
    return this.toView(row);
  }

  async upsertProfile(
    tenantId: string,
    userId: string,
    dto: UpsertAttendeeProfileDto,
  ): Promise<AttendeeProfileView> {
    await this.ensureRow(tenantId, userId);

    const sets: string[] = [];
    const params: unknown[] = [userId, tenantId];

    const push = (column: string, value: unknown, cast?: string) => {
      params.push(value);
      sets.push(`${column} = $${params.length}${cast ?? ''}`);
    };

    if (dto.preferredDisplayName !== undefined) {
      push('preferred_display_name', this.trimOrNull(dto.preferredDisplayName));
    }
    if (dto.preferredEventCategories !== undefined) {
      push(
        'preferred_event_categories',
        JSON.stringify(this.cleanStringList(dto.preferredEventCategories, 24)),
        '::jsonb',
      );
    }
    if (dto.interests !== undefined) {
      push('interests', JSON.stringify(this.cleanStringList(dto.interests, 24)), '::jsonb');
    }
    if (dto.accessibilityRequirements !== undefined) {
      push('accessibility_requirements', this.trimOrNull(dto.accessibilityRequirements));
    }
    if (dto.dietaryPreferences !== undefined) {
      push('dietary_preferences', this.trimOrNull(dto.dietaryPreferences));
    }
    if (dto.emergencyContactName !== undefined) {
      push('emergency_contact_name', this.trimOrNull(dto.emergencyContactName));
    }
    if (dto.emergencyContactRelationship !== undefined) {
      push('emergency_contact_relationship', this.trimOrNull(dto.emergencyContactRelationship));
    }
    if (dto.emergencyContactPhone !== undefined) {
      push('emergency_contact_phone', this.trimOrNull(dto.emergencyContactPhone));
    }
    if (dto.notifyEmail !== undefined) push('notify_email', dto.notifyEmail);
    if (dto.notifySms !== undefined) push('notify_sms', dto.notifySms);
    if (dto.notifyPush !== undefined) push('notify_push', dto.notifyPush);
    if (dto.privacyShowToOrganizers !== undefined) {
      push('privacy_show_to_organizers', dto.privacyShowToOrganizers);
    }
    if (dto.privacyShowToAttendees !== undefined) {
      push('privacy_show_to_attendees', dto.privacyShowToAttendees);
    }

    if (sets.length > 0) {
      sets.push('updated_at = now()');
      await this.pool.query(
        `UPDATE attendee_profiles SET ${sets.join(', ')} WHERE user_id = $1 AND tenant_id = $2`,
        params,
      );
    }

    return this.getProfile(tenantId, userId);
  }

  private async ensureRow(tenantId: string, userId: string): Promise<void> {
    await this.pool.query(
      `INSERT INTO attendee_profiles (tenant_id, user_id, onboarding_step, updated_at)
       VALUES ($1, $2, 'in_progress', now())
       ON CONFLICT (tenant_id, user_id) DO NOTHING`,
      [tenantId, userId],
    );
  }

  private async loadRow(tenantId: string, userId: string) {
    const { rows } = await this.pool.query<{
      user_id: string;
      preferred_display_name: string | null;
      preferred_event_categories: unknown;
      interests: unknown;
      accessibility_requirements: string | null;
      dietary_preferences: string | null;
      emergency_contact_name: string | null;
      emergency_contact_relationship: string | null;
      emergency_contact_phone: string | null;
      notify_email: boolean;
      notify_sms: boolean;
      notify_push: boolean;
      privacy_show_to_organizers: boolean;
      privacy_show_to_attendees: boolean;
      onboarding_step: string;
      activated_at: Date | null;
    }>(
      `SELECT user_id, preferred_display_name, preferred_event_categories, interests,
              accessibility_requirements, dietary_preferences,
              emergency_contact_name, emergency_contact_relationship, emergency_contact_phone,
              notify_email, notify_sms, notify_push,
              privacy_show_to_organizers, privacy_show_to_attendees,
              onboarding_step, activated_at
       FROM attendee_profiles
       WHERE tenant_id = $1 AND user_id = $2`,
      [tenantId, userId],
    );
    return rows[0] ?? null;
  }

  private toView(row: NonNullable<Awaited<ReturnType<AttendeeProfileService['loadRow']>>>): AttendeeProfileView {
    return {
      userId: row.user_id,
      preferredDisplayName: row.preferred_display_name,
      preferredEventCategories: this.parseStringList(row.preferred_event_categories),
      interests: this.parseStringList(row.interests),
      accessibilityRequirements: row.accessibility_requirements,
      dietaryPreferences: row.dietary_preferences,
      emergencyContactName: row.emergency_contact_name,
      emergencyContactRelationship: row.emergency_contact_relationship,
      emergencyContactPhone: row.emergency_contact_phone,
      notifyEmail: row.notify_email ?? true,
      notifySms: row.notify_sms ?? false,
      notifyPush: row.notify_push ?? true,
      privacyShowToOrganizers: row.privacy_show_to_organizers ?? true,
      privacyShowToAttendees: row.privacy_show_to_attendees ?? false,
      onboardingStep: row.onboarding_step,
      activatedAt: row.activated_at?.toISOString() ?? null,
    };
  }

  private trimOrNull(value: string): string | null {
    const t = value.trim();
    return t.length > 0 ? t : null;
  }

  private cleanStringList(items: string[], max: number): string[] {
    return items
      .map((i) => String(i).trim())
      .filter((i) => i.length > 0)
      .slice(0, max);
  }

  private parseStringList(raw: unknown): string[] {
    if (Array.isArray(raw)) {
      return raw.map((e) => String(e)).filter((e) => e.trim().length > 0);
    }
    if (typeof raw === 'string') {
      try {
        return this.parseStringList(JSON.parse(raw));
      } catch {
        return [];
      }
    }
    return [];
  }
}
