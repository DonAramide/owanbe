import {
  ArrayMaxSize,
  IsArray,
  IsObject,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  ValidateIf,
} from 'class-validator';

/** Additive Hub global profile update — never writes workspace profile tables. */
export class UpdateGlobalProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  firstName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  lastName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  displayName?: string;

  @IsOptional()
  @ValidateIf((_, v) => v !== null && v !== '')
  @IsString()
  @MaxLength(2048)
  avatarUrl?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  bio?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  occupation?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  company?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(24)
  @IsString({ each: true })
  @MaxLength(48, { each: true })
  interests?: string[];

  @IsOptional()
  @IsObject()
  socialLinks?: Record<string, string>;
}

export const GLOBAL_SOCIAL_LINK_KEYS = [
  'instagram',
  'twitter',
  'linkedin',
  'facebook',
  'tiktok',
  'youtube',
  'website',
] as const;

export type GlobalSocialLinkKey = (typeof GLOBAL_SOCIAL_LINK_KEYS)[number];

/** Soft URL check — empty strings allowed (clear field). */
export function sanitizeSocialLinks(
  input: Record<string, string> | undefined,
): Record<string, string> | undefined {
  if (!input) return undefined;
  const out: Record<string, string> = {};
  for (const key of GLOBAL_SOCIAL_LINK_KEYS) {
    const raw = input[key];
    if (raw == null) continue;
    const trimmed = String(raw).trim();
    out[key] = trimmed;
  }
  return out;
}

export function assertSocialLinkUrls(links: Record<string, string>): void {
  for (const [key, value] of Object.entries(links)) {
    if (!value) continue;
    try {
      const u = new URL(value.includes('://') ? value : `https://${value}`);
      if (u.protocol !== 'http:' && u.protocol !== 'https:') {
        throw new Error('invalid');
      }
    } catch {
      throw Object.assign(new Error(`Invalid URL for ${key}`), {
        code: 'INVALID_SOCIAL_URL',
        key,
      });
    }
  }
}

/** Re-export for validators that prefer class-validator IsUrl on nested maps elsewhere. */
export { IsUrl };
