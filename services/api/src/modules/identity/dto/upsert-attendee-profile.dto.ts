import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

/** Attendee workspace profile only — never writes `users` global profile columns. */
export class UpsertAttendeeProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  preferredDisplayName?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(24)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  preferredEventCategories?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(24)
  @IsString({ each: true })
  @MaxLength(48, { each: true })
  interests?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  accessibilityRequirements?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  dietaryPreferences?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  emergencyContactName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  emergencyContactRelationship?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  emergencyContactPhone?: string;

  @IsOptional()
  @IsBoolean()
  notifyEmail?: boolean;

  @IsOptional()
  @IsBoolean()
  notifySms?: boolean;

  @IsOptional()
  @IsBoolean()
  notifyPush?: boolean;

  @IsOptional()
  @IsBoolean()
  privacyShowToOrganizers?: boolean;

  @IsOptional()
  @IsBoolean()
  privacyShowToAttendees?: boolean;
}
