import { BadRequestException, Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';

export interface TicketInvitationSummary {
  id: string;
  ticketCode: string;
  tierName: string;
  eventId: string;
  eventTitle: string;
  eventCity: string;
  eventVenue: string;
  startsAt: string;
  status: string;
}

export interface OrganizerProfileView {
  userId: string;
  organizerId: string | null;
  displayName: string;
  organizationName: string;
  phoneE164: string | null;
  onboardingStep: string;
  emailVerifiedAt: string | null;
  phoneVerifiedAt: string | null;
}

@Injectable()
export class IdentityService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  normalizeEmail(email?: string): string | null {
    const v = email?.trim().toLowerCase();
    return v && v.includes('@') ? v : null;
  }

  normalizePhone(phone?: string): string | null {
    const raw = phone?.trim();
    if (!raw) return null;
    const digits = raw.replace(/[^\d+]/g, '');
    if (digits.startsWith('+')) return digits;
    if (digits.startsWith('0') && digits.length >= 10) {
      return `+234${digits.slice(1)}`;
    }
    if (digits.length >= 10) return `+${digits}`;
    return null;
  }

  async lookupTicketInvitations(
    tenantId: string,
    email?: string,
    phone?: string,
  ): Promise<TicketInvitationSummary[]> {
    const normEmail = this.normalizeEmail(email);
    const normPhone = this.normalizePhone(phone);
    if (!normEmail && !normPhone) {
      throw new BadRequestException({
        code: 'CONTACT_REQUIRED',
        message: 'Enter an email address or phone number',
      });
    }

    const { rows } = await this.pool.query<{
      id: string;
      ticket_code: string;
      metadata: { tier_name?: string };
      event_id: string;
      status: string;
      title: string;
      city: string;
      venue: string;
      starts_at: Date;
    }>(
      `SELECT te.id, te.ticket_code, te.metadata, te.event_id, te.status::text,
              e.title, e.metadata->>'city' AS city, e.metadata->>'venue' AS venue, e.starts_at
       FROM ticket_entitlements te
       INNER JOIN events e ON e.id = te.event_id
       WHERE te.tenant_id = $1
         AND te.status = 'issued'
         AND (
           ($2::text IS NOT NULL AND lower(te.guest_email) = $2)
           OR ($3::text IS NOT NULL AND te.guest_phone_e164 = $3)
           OR te.holder_user_id IN (
             SELECT u.id FROM users u
             WHERE u.tenant_id = $1
               AND (
                 ($2::text IS NOT NULL AND lower(u.email) = $2)
                 OR ($3::text IS NOT NULL AND u.phone_e164 = $3)
               )
           )
         )
       ORDER BY e.starts_at ASC`,
      [tenantId, normEmail, normPhone],
    );

    return rows.map((r) => ({
      id: r.id,
      ticketCode: r.ticket_code,
      tierName: r.metadata?.tier_name ?? 'Ticket',
      eventId: r.event_id,
      eventTitle: r.title,
      eventCity: r.city ?? '',
      eventVenue: r.venue ?? '',
      startsAt: r.starts_at.toISOString(),
      status: r.status,
    }));
  }

  async linkTicketEntitlements(
    tenantId: string,
    userId: string,
    email?: string,
    phone?: string,
  ): Promise<{ linkedCount: number; entitlementIds: string[] }> {
    const normEmail = this.normalizeEmail(email);
    const normPhone = this.normalizePhone(phone);

    const { rows: userRows } = await this.pool.query<{ email: string; phone_e164: string | null }>(
      `SELECT email, phone_e164 FROM users WHERE id = $1 AND tenant_id = $2`,
      [userId, tenantId],
    );
    const user = userRows[0];
    const matchEmail = normEmail ?? user?.email?.toLowerCase() ?? null;
    const matchPhone = normPhone ?? user?.phone_e164 ?? null;

    const { rows } = await this.pool.query<{ id: string }>(
      `UPDATE ticket_entitlements te
       SET holder_user_id = $2,
           linked_at = COALESCE(te.linked_at, now()),
           guest_email = NULL,
           guest_phone_e164 = NULL
       WHERE te.tenant_id = $1
         AND te.status = 'issued'
         AND (te.holder_user_id IS NULL OR te.holder_user_id = $2)
         AND (
           ($3::text IS NOT NULL AND lower(te.guest_email) = $3)
           OR ($4::text IS NOT NULL AND te.guest_phone_e164 = $4)
           OR (
             te.holder_user_id IS NULL
             AND EXISTS (
               SELECT 1 FROM users u
               WHERE u.id = $2 AND u.tenant_id = $1
                 AND (
                   ($3::text IS NOT NULL AND lower(u.email) = $3 AND lower(te.guest_email) = $3)
                   OR ($4::text IS NOT NULL AND u.phone_e164 = $4 AND te.guest_phone_e164 = $4)
                 )
             )
           )
         )
       RETURNING te.id`,
      [tenantId, userId, matchEmail, matchPhone],
    );

    return { linkedCount: rows.length, entitlementIds: rows.map((r) => r.id) };
  }

  async getOrganizerProfile(tenantId: string, userId: string): Promise<OrganizerProfileView> {
    const { rows } = await this.pool.query<{
      organizer_id: string | null;
      display_name: string;
      organization_name: string;
      phone_e164: string | null;
      onboarding_step: string;
      email_verified_at: Date | null;
      phone_verified_at: Date | null;
    }>(
      `SELECT op.organizer_id, op.display_name, op.organization_name, op.phone_e164,
              op.onboarding_step, op.email_verified_at, op.phone_verified_at
       FROM organizer_profiles op
       WHERE op.tenant_id = $1 AND op.user_id = $2`,
      [tenantId, userId],
    );
    const row = rows[0];
    if (!row) {
      return {
        userId,
        organizerId: null,
        displayName: '',
        organizationName: '',
        phoneE164: null,
        onboardingStep: 'profile',
        emailVerifiedAt: null,
        phoneVerifiedAt: null,
      };
    }
    return {
      userId,
      organizerId: row.organizer_id,
      displayName: row.display_name,
      organizationName: row.organization_name,
      phoneE164: row.phone_e164,
      onboardingStep: row.onboarding_step,
      emailVerifiedAt: row.email_verified_at?.toISOString() ?? null,
      phoneVerifiedAt: row.phone_verified_at?.toISOString() ?? null,
    };
  }

  async upsertOrganizerProfile(
    tenantId: string,
    userId: string,
    dto: {
      displayName?: string;
      organizationName?: string;
      phoneE164?: string;
      onboardingStep?: string;
      markEmailVerified?: boolean;
      markPhoneVerified?: boolean;
    },
  ): Promise<OrganizerProfileView> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      let organizerId: string | null = null;
      const { rows: orgRows } = await client.query<{ id: string }>(
        `SELECT id FROM organizers WHERE tenant_id = $1 AND owner_user_id = $2 LIMIT 1`,
        [tenantId, userId],
      );
      organizerId = orgRows[0]?.id ?? null;

      if (dto.organizationName && !organizerId) {
        const slug = dto.organizationName
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/^-|-$/g, '')
          .slice(0, 48);
        const ins = await client.query<{ id: string }>(
          `INSERT INTO organizers (tenant_id, owner_user_id, display_name, slug, status)
           VALUES ($1, $2, $3, $4, 'active')
           ON CONFLICT DO NOTHING
           RETURNING id`,
          [tenantId, userId, dto.organizationName, slug || `org-${userId.slice(0, 8)}`],
        );
        organizerId = ins.rows[0]?.id ?? organizerId;
        if (!organizerId) {
          const again = await client.query<{ id: string }>(
            `SELECT id FROM organizers WHERE tenant_id = $1 AND owner_user_id = $2 LIMIT 1`,
            [tenantId, userId],
          );
          organizerId = again.rows[0]?.id ?? null;
        }
      }

      await client.query(
        `INSERT INTO organizer_profiles (
           tenant_id, user_id, organizer_id, display_name, organization_name,
           phone_e164, onboarding_step, email_verified_at, phone_verified_at
         )
         VALUES ($1, $2, $3, $4, $5, $6, $7,
           CASE WHEN $8 THEN now() ELSE NULL END,
           CASE WHEN $9 THEN now() ELSE NULL END)
         ON CONFLICT (tenant_id, user_id) DO UPDATE SET
           organizer_id = COALESCE(EXCLUDED.organizer_id, organizer_profiles.organizer_id),
           display_name = COALESCE(NULLIF(EXCLUDED.display_name, ''), organizer_profiles.display_name),
           organization_name = COALESCE(NULLIF(EXCLUDED.organization_name, ''), organizer_profiles.organization_name),
           phone_e164 = COALESCE(EXCLUDED.phone_e164, organizer_profiles.phone_e164),
           onboarding_step = COALESCE(EXCLUDED.onboarding_step, organizer_profiles.onboarding_step),
           email_verified_at = COALESCE(organizer_profiles.email_verified_at,
             CASE WHEN $8 THEN now() ELSE NULL END),
           phone_verified_at = COALESCE(organizer_profiles.phone_verified_at,
             CASE WHEN $9 THEN now() ELSE NULL END),
           updated_at = now()`,
        [
          tenantId,
          userId,
          organizerId,
          dto.displayName ?? '',
          dto.organizationName ?? '',
          dto.phoneE164 ?? null,
          dto.onboardingStep ?? 'profile',
          dto.markEmailVerified ?? false,
          dto.markPhoneVerified ?? false,
        ],
      );

      if (dto.displayName) {
        await client.query(
          `UPDATE users SET display_name = $3 WHERE id = $1 AND tenant_id = $2`,
          [userId, tenantId, dto.displayName],
        );
      }

      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }

    return this.getOrganizerProfile(tenantId, userId);
  }

  async resolveVendorId(tenantId: string, userId: string): Promise<string | null> {
    const { rows } = await this.pool.query<{ id: string }>(
      `SELECT id FROM vendors WHERE tenant_id = $1 AND owner_user_id = $2 LIMIT 1`,
      [tenantId, userId],
    );
    return rows[0]?.id ?? null;
  }
}
