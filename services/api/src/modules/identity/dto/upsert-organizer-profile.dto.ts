import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

/** Optional verification document ref — display/storage only (no workflow). */
export class OrganizerVerificationDocumentDto {
  @IsString()
  @MaxLength(2048)
  url!: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  uploadedAt?: string;
}

/**
 * Organizer profile upsert — onboarding fields + workspace profile fields.
 * Workspace fields persist only on `organizer_profiles` (never `users`).
 */
export class UpsertOrganizerProfileDto {
  // —— Existing onboarding fields (IdentityService) ——
  @IsOptional()
  @IsString()
  @MaxLength(120)
  displayName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  organizationName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  phoneE164?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  onboardingStep?: string;

  @IsOptional()
  @IsBoolean()
  markEmailVerified?: boolean;

  @IsOptional()
  @IsBoolean()
  markPhoneVerified?: boolean;

  // —— Workspace profile (OrganizerProfileService) ——
  /** Alias for organizer name → display_name when preferred by clients. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  organizerName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  businessName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  businessType?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(80)
  yearsOfExperience?: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  bio?: string;

  @IsOptional()
  @IsString()
  @MaxLength(254)
  supportEmail?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  supportPhone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  website?: string;

  @IsOptional()
  @IsObject()
  socialLinks?: Record<string, string>;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  businessAddress?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  state?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  country?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  registrationNumber?: string;

  /** Free-text local authority (CAC, Companies House, State SOS, …). */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  registrationAuthority?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  registrationCountry?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  taxId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  taxAuthority?: string;

  /** Extensible: pending | submitted | verified | rejected | custom. */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  verificationStatus?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => OrganizerVerificationDocumentDto)
  verificationDocuments?: OrganizerVerificationDocumentDto[];

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  logoUrl?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  coverImageUrl?: string | null;
}
