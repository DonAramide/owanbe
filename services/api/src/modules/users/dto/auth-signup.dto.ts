import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import type { SignupPortal } from '../portal.util';

export class CompleteSignupDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(['client', 'organizer', 'vendor', 'admin'])
  portal!: SignupPortal;
}

export class ValidatePortalDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(['client', 'organizer', 'vendor', 'admin'])
  portal!: SignupPortal;
}

export class PortalLookupDto {
  @IsString()
  @IsNotEmpty()
  email!: string;
}

export class MigrateUserPortalDto {
  @IsString()
  @IsNotEmpty()
  email!: string;

  @IsString()
  @IsNotEmpty()
  @IsIn(['client', 'organizer', 'vendor', 'admin'])
  targetPortal!: SignupPortal;

  @IsString()
  @IsNotEmpty()
  reason!: string;
}

export class CompleteOnboardingDto {
  @IsOptional()
  @IsString()
  displayName?: string;

  @IsOptional()
  @IsString()
  phoneE164?: string;

  /** Owanbe 2.0 — mark a workspace profile complete (client | organizer | vendor). */
  @IsOptional()
  @IsString()
  @IsIn(['client', 'organizer', 'vendor'])
  workspace?: 'client' | 'organizer' | 'vendor';
}
