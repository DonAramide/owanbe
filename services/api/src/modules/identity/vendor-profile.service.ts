import { Injectable, Inject } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { UpsertVendorProfileDto } from './dto/upsert-vendor-profile.dto';

export interface VendorVerificationDocumentView {
  url: string;
  name: string | null;
  uploadedAt: string | null;
}

/** Full vendor workspace profile — `vendor_profiles` only. */
export interface VendorWorkspaceProfileView {
  userId: string;
  vendorId: string | null;
  businessName: string;
  category: string;
  subcategory: string | null;
  yearsOfExperience: number | null;
  bio: string | null;
  businessDescription: string | null;
  servicesOffered: string[];
  serviceAreas: string[];
  portfolioImages: string[];
  portfolioVideos: string[];
  portfolioWebsite: string | null;
  startingPrice: string | null;
  priceRange: string | null;
  teamSize: number | null;
  maxEventCapacity: number | null;
  availableForBookings: boolean;
  advanceBookingNotice: string | null;
  businessAddress: string | null;
  city: string | null;
  state: string | null;
  country: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  verificationDocuments: VendorVerificationDocumentView[];
  businessRegistrationNumber: string | null;
  taxId: string | null;
  socialLinks: Record<string, string>;
  logoUrl: string | null;
  coverImageUrl: string | null;
  onboardingStep: string;
  activatedAt: string | null;
}

@Injectable()
export class VendorProfileService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getProfile(tenantId: string, userId: string): Promise<VendorWorkspaceProfileView> {
    await this.ensureRow(tenantId, userId);
    const row = await this.loadRow(tenantId, userId);
    return this.toView(userId, row);
  }

  /**
   * Upsert workspace fields on `vendor_profiles` only.
   * Never writes `users`, `attendee_profiles`, or `organizer_profiles`.
   */
  async upsertProfile(
    tenantId: string,
    userId: string,
    dto: UpsertVendorProfileDto,
  ): Promise<VendorWorkspaceProfileView> {
    await this.ensureRow(tenantId, userId);

    const sets: string[] = [];
    const params: unknown[] = [userId, tenantId];

    const push = (column: string, value: unknown, cast?: string) => {
      params.push(value);
      sets.push(`${column} = $${params.length}${cast ?? ''}`);
    };

    if (dto.businessName !== undefined) {
      push('business_name', dto.businessName.trim());
    }
    if (dto.category !== undefined) {
      push('category', dto.category.trim());
    }
    if (dto.subcategory !== undefined) {
      push('subcategory', this.trimOrNull(dto.subcategory));
    }
    if (dto.yearsOfExperience !== undefined) {
      push('years_of_experience', dto.yearsOfExperience);
    }

    const bio = dto.businessDescription ?? dto.bio;
    if (bio !== undefined) {
      push('bio', this.trimOrNull(bio));
    }

    if (dto.servicesOffered !== undefined) {
      push('services_offered', JSON.stringify(this.cleanStringList(dto.servicesOffered, 48)), '::jsonb');
    }
    if (dto.serviceAreas !== undefined) {
      push('service_areas', JSON.stringify(this.cleanStringList(dto.serviceAreas, 48)), '::jsonb');
    }
    if (dto.portfolioImages !== undefined) {
      push('portfolio_images', JSON.stringify(this.cleanStringList(dto.portfolioImages, 40)), '::jsonb');
    }
    if (dto.portfolioVideos !== undefined) {
      push('portfolio_videos', JSON.stringify(this.cleanStringList(dto.portfolioVideos, 20)), '::jsonb');
    }
    if (dto.portfolioWebsite !== undefined) {
      push('portfolio_website', this.trimOrNull(dto.portfolioWebsite));
    }
    if (dto.startingPrice !== undefined) {
      push('starting_price', this.trimOrNull(dto.startingPrice));
    }
    if (dto.priceRange !== undefined) {
      push('price_range', this.trimOrNull(dto.priceRange));
    }
    if (dto.teamSize !== undefined) {
      push('team_size', dto.teamSize);
    }
    if (dto.maxEventCapacity !== undefined) {
      push('max_event_capacity', dto.maxEventCapacity);
    }
    if (dto.availableForBookings !== undefined) {
      push('available_for_bookings', dto.availableForBookings);
    }
    if (dto.advanceBookingNotice !== undefined) {
      push('advance_booking_notice', this.trimOrNull(dto.advanceBookingNotice));
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
    if (dto.contactPhone !== undefined) {
      push('contact_phone', this.trimOrNull(dto.contactPhone));
    }
    if (dto.contactEmail !== undefined) {
      push('contact_email', this.trimOrNull(dto.contactEmail)?.toLowerCase() ?? null);
    }
    if (dto.verificationDocuments !== undefined) {
      push(
        'verification_documents',
        JSON.stringify(this.cleanDocuments(dto.verificationDocuments)),
        '::jsonb',
      );
    }
    if (dto.businessRegistrationNumber !== undefined) {
      push('business_registration_number', this.trimOrNull(dto.businessRegistrationNumber));
    }
    if (dto.taxId !== undefined) {
      push('tax_id', this.trimOrNull(dto.taxId));
    }
    if (dto.socialLinks !== undefined) {
      push('social_links', JSON.stringify(this.cleanSocialLinks(dto.socialLinks)), '::jsonb');
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
        `UPDATE vendor_profiles SET ${sets.join(', ')} WHERE user_id = $1 AND tenant_id = $2`,
        params,
      );
    }

    return this.getProfile(tenantId, userId);
  }

  private async ensureRow(tenantId: string, userId: string): Promise<void> {
    let vendorId: string | null = null;
    const { rows: vendorRows } = await this.pool.query<{ id: string }>(
      `SELECT id FROM vendors WHERE tenant_id = $1 AND owner_user_id = $2 LIMIT 1`,
      [tenantId, userId],
    );
    vendorId = vendorRows[0]?.id ?? null;

    await this.pool.query(
      `INSERT INTO vendor_profiles (tenant_id, user_id, vendor_id, onboarding_step, updated_at)
       VALUES ($1, $2, $3, 'in_progress', now())
       ON CONFLICT (tenant_id, user_id) DO UPDATE SET
         vendor_id = COALESCE(vendor_profiles.vendor_id, EXCLUDED.vendor_id)`,
      [tenantId, userId, vendorId],
    );
  }

  private async loadRow(tenantId: string, userId: string) {
    const { rows } = await this.pool.query<{
      vendor_id: string | null;
      business_name: string;
      category: string;
      subcategory: string | null;
      years_of_experience: number | null;
      bio: string | null;
      services_offered: unknown;
      service_areas: unknown;
      portfolio_images: unknown;
      portfolio_videos: unknown;
      portfolio_website: string | null;
      starting_price: string | null;
      price_range: string | null;
      team_size: number | null;
      max_event_capacity: number | null;
      available_for_bookings: boolean;
      advance_booking_notice: string | null;
      business_address: string | null;
      city: string | null;
      state: string | null;
      country: string | null;
      contact_phone: string | null;
      contact_email: string | null;
      verification_documents: unknown;
      business_registration_number: string | null;
      tax_id: string | null;
      social_links: unknown;
      logo_url: string | null;
      cover_image_url: string | null;
      onboarding_step: string;
      activated_at: Date | null;
    }>(
      `SELECT vendor_id, business_name, category, subcategory, years_of_experience, bio,
              services_offered, service_areas, portfolio_images, portfolio_videos, portfolio_website,
              starting_price, price_range, team_size, max_event_capacity,
              available_for_bookings, advance_booking_notice,
              business_address, city, state, country, contact_phone, contact_email,
              verification_documents, business_registration_number, tax_id, social_links,
              logo_url, cover_image_url, onboarding_step, activated_at
       FROM vendor_profiles
       WHERE tenant_id = $1 AND user_id = $2`,
      [tenantId, userId],
    );
    return rows[0] ?? null;
  }

  private toView(
    userId: string,
    row: NonNullable<Awaited<ReturnType<VendorProfileService['loadRow']>>> | null,
  ): VendorWorkspaceProfileView {
    if (!row) {
      return {
        userId,
        vendorId: null,
        businessName: '',
        category: '',
        subcategory: null,
        yearsOfExperience: null,
        bio: null,
        businessDescription: null,
        servicesOffered: [],
        serviceAreas: [],
        portfolioImages: [],
        portfolioVideos: [],
        portfolioWebsite: null,
        startingPrice: null,
        priceRange: null,
        teamSize: null,
        maxEventCapacity: null,
        availableForBookings: true,
        advanceBookingNotice: null,
        businessAddress: null,
        city: null,
        state: null,
        country: null,
        contactPhone: null,
        contactEmail: null,
        verificationDocuments: [],
        businessRegistrationNumber: null,
        taxId: null,
        socialLinks: {},
        logoUrl: null,
        coverImageUrl: null,
        onboardingStep: 'not_started',
        activatedAt: null,
      };
    }

    const bio = row.bio;
    return {
      userId,
      vendorId: row.vendor_id,
      businessName: row.business_name ?? '',
      category: row.category ?? '',
      subcategory: row.subcategory,
      yearsOfExperience: row.years_of_experience,
      bio,
      businessDescription: bio,
      servicesOffered: this.parseStringList(row.services_offered),
      serviceAreas: this.parseStringList(row.service_areas),
      portfolioImages: this.parseStringList(row.portfolio_images),
      portfolioVideos: this.parseStringList(row.portfolio_videos),
      portfolioWebsite: row.portfolio_website,
      startingPrice: row.starting_price,
      priceRange: row.price_range,
      teamSize: row.team_size,
      maxEventCapacity: row.max_event_capacity,
      availableForBookings: row.available_for_bookings ?? true,
      advanceBookingNotice: row.advance_booking_notice,
      businessAddress: row.business_address,
      city: row.city,
      state: row.state,
      country: row.country,
      contactPhone: row.contact_phone,
      contactEmail: row.contact_email,
      verificationDocuments: this.parseDocuments(row.verification_documents),
      businessRegistrationNumber: row.business_registration_number,
      taxId: row.tax_id,
      socialLinks: this.parseSocialLinks(row.social_links),
      logoUrl: row.logo_url,
      coverImageUrl: row.cover_image_url,
      onboardingStep: row.onboarding_step || 'not_started',
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
  ): VendorVerificationDocumentView[] {
    return docs
      .map((d) => ({
        url: String(d.url ?? '').trim().slice(0, 2048),
        name: d.name ? String(d.name).trim().slice(0, 240) : null,
        uploadedAt: d.uploadedAt ? String(d.uploadedAt).trim().slice(0, 64) : null,
      }))
      .filter((d) => d.url.length > 0)
      .slice(0, 20);
  }

  private parseDocuments(raw: unknown): VendorVerificationDocumentView[] {
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
