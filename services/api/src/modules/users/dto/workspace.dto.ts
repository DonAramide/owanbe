import { IsIn, IsObject, IsOptional, IsString, MaxLength } from 'class-validator';

export class EnsureUserDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  displayName?: string;
}

export class ActivateWorkspaceDto {
  @IsIn(['client', 'organizer', 'vendor'])
  workspace!: 'client' | 'organizer' | 'vendor';

  @IsOptional()
  @IsObject()
  draft?: Record<string, unknown>;
}

export class SaveWorkspaceOnboardingDto {
  @IsOptional()
  @IsObject()
  draft?: Record<string, unknown>;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  step?: string;

  @IsOptional()
  completionPct?: number;
}

export class SetActiveWorkspaceDto {
  @IsIn(['client', 'organizer', 'vendor'])
  workspace!: 'client' | 'organizer' | 'vendor';
}
