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

export class VendorVerificationDocumentDto {
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

/** Per-service vendor/base payout (minor units) — authoritative commercial price. */
export class VendorServicePriceDto {
  @IsString()
  @MaxLength(80)
  name!: string;

  @IsInt()
  @Min(0)
  basePayoutMinor!: number;
}

/** Vendor workspace profile only — never writes `users` global profile columns. */
export class UpsertVendorProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  businessName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  category?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  subcategory?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(80)
  yearsOfExperience?: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  bio?: string;

  /** Alias accepted by clients for business description → bio. */
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  businessDescription?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(48)
  @IsString({ each: true })
  @MaxLength(80, { each: true })
  servicesOffered?: string[];

  /** Authoritative per-service base payouts (synced onto vendor_services.base_payout_minor). */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(48)
  @ValidateNested({ each: true })
  @Type(() => VendorServicePriceDto)
  servicePrices?: VendorServicePriceDto[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(48)
  @IsString({ each: true })
  @MaxLength(120, { each: true })
  serviceAreas?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(40)
  @IsString({ each: true })
  @MaxLength(2048, { each: true })
  portfolioImages?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(2048, { each: true })
  portfolioVideos?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  portfolioWebsite?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  startingPrice?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  priceRange?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000)
  teamSize?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1000000)
  maxEventCapacity?: number;

  @IsOptional()
  @IsBoolean()
  availableForBookings?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  advanceBookingNotice?: string;

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
  @MaxLength(32)
  contactPhone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(254)
  contactEmail?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => VendorVerificationDocumentDto)
  verificationDocuments?: VendorVerificationDocumentDto[];

  @IsOptional()
  @IsString()
  @MaxLength(120)
  businessRegistrationNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  taxId?: string;

  @IsOptional()
  @IsObject()
  socialLinks?: Record<string, string>;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  logoUrl?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  coverImageUrl?: string | null;
}
