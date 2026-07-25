import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { UpsertOrganizerProfileDto } from './dto/upsert-organizer-profile.dto';

export interface OrganizerVerificationDocumentView {
  url: string;
  name: string | null;
  uploadedAt: string | null;
}

/** Full organizer workspace profile — `organizer_profiles` only. */
export interface OrganizerWorkspaceProfileView {
  userId: string;
  organizerId: string | null;
  organizerName: string;
  businessName: string;
  businessType: string | null;
  yearsOfExperience: number | null;
  bio: string | null;
  supportEmail: string | null;
  supportPhone: string | null;
  website: string | null;
  socialLinks: Record<string, string>;
  businessAddress: string | null;
  city: string | null;
  state: string | null;
  country: string | null;
  registrationNumber: string | null;
  registrationAuthority: string | null;
  registrationCountry: string | null;
  taxId: string | null;
  taxAuthority: string | null;
  verificationStatus: string;
  verificationDocuments: OrganizerVerificationDocumentView[];
  logoUrl: string | null;
  coverImageUrl: string | null;
  /** Onboarding compatibility fields */
  displayName: string;
  organizationName: string;
  phoneE164: string | null;
  onboardingStep: string;
  emailVerifiedAt: string | null;
  phoneVerifiedAt: string | null;
}

@Injectable()
export class OrganizerProfileService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /** True when the DTO carries organizer workspace profile columns (not onboarding-only). */
  hasWorkspaceFields(dto: UpsertOrganizerProfileDto): boolean {
    return (
      dto.organizerName !== undefined ||
      dto.businessName !== undefined ||
      dto.businessType !== undefined ||
      dto.yearsOfExperience !== undefined ||
      dto.bio !== undefined ||
      dto.supportEmail !== undefined ||
      dto.supportPhone !== undefined ||
      dto.website !== undefined ||
      dto.socialLinks !== undefined ||
      dto.businessAddress !== undefined ||
      dto.city !== undefined ||
      dto.state !== undefined ||
      dto.country !== undefined ||
      dto.registrationNumber !== undefined ||
      dto.registrationAuthority !== undefined ||
      dto.registrationCountry !== undefined ||
      dto.taxId !== undefined ||
      dto.taxAuthority !== undefined ||
      dto.verificationStatus !== undefined ||
      dto.verificationDocuments !== undefined ||
      dto.logoUrl !== undefined ||
      dto.coverImageUrl !== undefined
    );
  }

  /** Onboarding / activation fields handled by IdentityService. */
  hasOnboardingFields(dto: UpsertOrganizerProfileDto): boolean {
    return (
      dto.displayName !== undefined ||
      dto.organizationName !== undefined ||
      dto.phoneE164 !== undefined ||
      dto.onboardingStep !== undefined ||
      dto.markEmailVerified === true ||
      dto.markPhoneVerified === true
    );
  }

  async getProfile(tenantId: string, userId: string): Promise<OrganizerWorkspaceProfileView> {
    await this.ensureRow(tenantId, userId);
    const row = await this.loadRow(tenantId, userId);
    return this.toView(userId, row);
  }

  /**
   * Upsert workspace fields on `organizer_profiles` only.
   * Never writes `users`, `attendee_profiles`, or `vendor_profiles`.
   */
  async upsertProfile(
    tenantId: string,
    userId: string,
    dto: UpsertOrganizerProfileDto,
  ): Promise<OrganizerWorkspaceProfileView> {
    await this.ensureRow(tenantId, userId);

    const sets: string[] = [];
    const params: unknown[] = [userId, tenantId];

    const push = (column: string, value: unknown, cast?: string) => {
      params.push(value);
      sets.push(`${column} = $${params.length}${cast ?? ''}`);
    };

    const organizerName = dto.organizerName ?? dto.displayName;
    if (organizerName !== undefined) {
      push('display_name', organizerName.trim());
    }

    const businessName = dto.businessName ?? dto.organizationName;
    if (businessName !== undefined) {
      push('organization_name', businessName.trim());
    }

    if (dto.businessType !== undefined) {
      push('business_type', this.trimOrNull(dto.businessType));
    }
    if (dto.yearsOfExperience !== undefined) {
      push('years_of_experience', dto.yearsOfExperience);
    }
    if (dto.bio !== undefined) {
      push('bio', this.trimOrNull(dto.bio));
    }
    if (dto.supportEmail !== undefined) {
      push('support_email', this.trimOrNull(dto.supportEmail)?.toLowerCase() ?? null);
    }
    if (dto.supportPhone !== undefined) {
      push('support_phone', this.trimOrNull(dto.supportPhone));
    }
    if (dto.website !== undefined) {
      push('website', this.trimOrNull(dto.website));
    }
    if (dto.socialLinks !== undefined) {
      push('social_links', JSON.stringify(this.cleanSocialLinks(dto.socialLinks)), '::jsonb');
    }
    if (dto.businessAddress !== undefined) {
      push('business_address', this.trimOrNull(dto.businessAddress));
    }
    if (dto.city !== undefined) {
      push('city', this.trimOrNull(dto.city));
    }
    if (dto.state !== undefined) {
      push('state', this.trimOrNull(dto.state));
    }
    if (dto.country !== undefined) {
      push('country', this.trimOrNull(dto.country));
    }
    if (dto.registrationNumber !== undefined) {
      push('registration_number', this.trimOrNull(dto.registrationNumber));
    }
    if (dto.registrationAuthority !== undefined) {
      push('registration_authority', this.trimOrNull(dto.registrationAuthority));
    }
    if (dto.registrationCountry !== undefined) {
      push('registration_country', this.trimOrNull(dto.registrationCountry));
    }
    if (dto.taxId !== undefined) {
      push('tax_id', this.trimOrNull(dto.taxId));
    }
    if (dto.taxAuthority !== undefined) {
      push('tax_authority', this.trimOrNull(dto.taxAuthority));
    }
    if (dto.verificationStatus !== undefined) {
      const status = this.trimOrNull(dto.verificationStatus)?.toLowerCase() ?? 'pending';
      push('verification_status', status);
    }
    if (dto.verificationDocuments !== undefined) {
      push(
        'verification_documents',
        JSON.stringify(this.cleanDocuments(dto.verificationDocuments)),
        '::jsonb',
      );
    }
    if (dto.logoUrl !== undefined) {
      push('logo_url', dto.logoUrl === null ? null : this.trimOrNull(dto.logoUrl));
    }
    if (dto.coverImageUrl !== undefined) {
      push('cover_image_url', dto.coverImageUrl === null ? null : this.trimOrNull(dto.coverImageUrl));
    }

    if (sets.length > 0) {
      sets.push('updated_at = now()');
      await this.pool.query(
        `UPDATE organizer_profiles SET ${sets.join(', ')} WHERE user_id = $1 AND tenant_id = $2`,
        params,
      );
    }

    return this.getProfile(tenantId, userId);
  }

  private async ensureRow(tenantId: string, userId: string): Promise<void> {
    await this.pool.query(
      `INSERT INTO organizer_profiles (tenant_id, user_id, onboarding_step, updated_at)
       VALUES ($1, $2, 'profile', now())
       ON CONFLICT (tenant_id, user_id) DO NOTHING`,
      [tenantId, userId],
    );
  }

  private async loadRow(tenantId: string, userId: string) {
    const { rows } = await this.pool.query<{
      organizer_id: string | null;
      display_name: string;
      organization_name: string;
      phone_e164: string | null;
      onboarding_step: string;
      email_verified_at: Date | null;
      phone_verified_at: Date | null;
      business_type: string | null;
      years_of_experience: number | null;
      bio: string | null;
      support_email: string | null;
      support_phone: string | null;
      website: string | null;
      social_links: unknown;
      business_address: string | null;
      city: string | null;
      state: string | null;
      country: string | null;
      registration_number: string | null;
      registration_authority: string | null;
      registration_country: string | null;
      tax_id: string | null;
      tax_authority: string | null;
      verification_status: string;
      verification_documents: unknown;
      logo_url: string | null;
      cover_image_url: string | null;
    }>(
      `SELECT organizer_id, display_name, organization_name, phone_e164, onboarding_step,
              email_verified_at, phone_verified_at,
              business_type, years_of_experience, bio, support_email, support_phone,
              website, social_links, business_address, city, state, country,
              registration_number, registration_authority, registration_country,
              tax_id, tax_authority, verification_status, verification_documents,
              logo_url, cover_image_url
       FROM organizer_profiles
       WHERE tenant_id = $1 AND user_id = $2`,
      [tenantId, userId],
    );
    return rows[0] ?? null;
  }

  private toView(
    userId: string,
    row: NonNullable<Awaited<ReturnType<OrganizerProfileService['loadRow']>>> | null,
  ): OrganizerWorkspaceProfileView {
    if (!row) {
      return {
        userId,
        organizerId: null,
        organizerName: '',
        businessName: '',
        businessType: null,
        yearsOfExperience: null,
        bio: null,
        supportEmail: null,
        supportPhone: null,
        website: null,
        socialLinks: {},
        businessAddress: null,
        city: null,
        state: null,
        country: null,
        registrationNumber: null,
        registrationAuthority: null,
        registrationCountry: null,
        taxId: null,
        taxAuthority: null,
        verificationStatus: 'pending',
        verificationDocuments: [],
        logoUrl: null,
        coverImageUrl: null,
        displayName: '',
        organizationName: '',
        phoneE164: null,
        onboardingStep: 'profile',
        emailVerifiedAt: null,
        phoneVerifiedAt: null,
      };
    }

    const displayName = row.display_name ?? '';
    const organizationName = row.organization_name ?? '';

    return {
      userId,
      organizerId: row.organizer_id,
      organizerName: displayName,
      businessName: organizationName,
      businessType: row.business_type,
      yearsOfExperience: row.years_of_experience,
      bio: row.bio,
      supportEmail: row.support_email,
      supportPhone: row.support_phone,
      website: row.website,
      socialLinks: this.parseSocialLinks(row.social_links),
      businessAddress: row.business_address,
      city: row.city,
      state: row.state,
      country: row.country,
      registrationNumber: row.registration_number,
      registrationAuthority: row.registration_authority,
      registrationCountry: row.registration_country,
      taxId: row.tax_id,
      taxAuthority: row.tax_authority,
      verificationStatus: row.verification_status || 'pending',
      verificationDocuments: this.parseDocuments(row.verification_documents),
      logoUrl: row.logo_url,
      coverImageUrl: row.cover_image_url,
      displayName,
      organizationName,
      phoneE164: row.phone_e164,
      onboardingStep: row.onboarding_step || 'profile',
      emailVerifiedAt: row.email_verified_at?.toISOString() ?? null,
      phoneVerifiedAt: row.phone_verified_at?.toISOString() ?? null,
    };
  }

  private trimOrNull(value: string): string | null {
    const t = value.trim();
    return t.length > 0 ? t : null;
  }

  private cleanSocialLinks(raw: Record<string, string>): Record<string, string> {
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(raw ?? {})) {
      const key = String(k).trim().toLowerCase().slice(0, 40);
      const val = String(v ?? '').trim().slice(0, 2048);
      if (key && val) out[key] = val;
    }
    return out;
  }

  private parseSocialLinks(raw: unknown): Record<string, string> {
    if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
      return this.cleanSocialLinks(raw as Record<string, string>);
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

  private cleanDocuments(
    docs: Array<{ url: string; name?: string; uploadedAt?: string }>,
  ): OrganizerVerificationDocumentView[] {
    return docs
      .map((d) => ({
        url: String(d.url ?? '').trim().slice(0, 2048),
        name: d.name ? String(d.name).trim().slice(0, 240) : null,
        uploadedAt: d.uploadedAt ? String(d.uploadedAt).trim().slice(0, 64) : null,
      }))
      .filter((d) => d.url.length > 0)
      .slice(0, 20);
  }

  private parseDocuments(raw: unknown): OrganizerVerificationDocumentView[] {
    let list: unknown[] = [];
    if (Array.isArray(raw)) list = raw;
    else if (typeof raw === 'string') {
      try {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) list = parsed;
      } catch {
        return [];
      }
    }
    return this.cleanDocuments(
      list.map((item) => {
        if (typeof item === 'string') return { url: item };
        const o = (item ?? {}) as Record<string, unknown>;
        return {
          url: String(o.url ?? ''),
          name: o.name != null ? String(o.name) : undefined,
          uploadedAt: o.uploadedAt != null ? String(o.uploadedAt) : undefined,
        };
      }),
    );
  }
}
