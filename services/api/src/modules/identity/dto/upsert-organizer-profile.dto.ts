import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class UpsertOrganizerProfileDto {
  @IsOptional()
  @IsString()
  displayName?: string;

  @IsOptional()
  @IsString()
  organizationName?: string;

  @IsOptional()
  @IsString()
  phoneE164?: string;

  @IsOptional()
  @IsString()
  onboardingStep?: string;

  @IsOptional()
  @IsBoolean()
  markEmailVerified?: boolean;

  @IsOptional()
  @IsBoolean()
  markPhoneVerified?: boolean;
}
