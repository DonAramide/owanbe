import {
  IsBoolean,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';
import type { EmailEncryptionMode, EmailProviderType } from '../email.types';

const PROVIDER_TYPES = [
  'generic_smtp',
  'zoho_smtp',
  'microsoft_365',
  'google_workspace',
  'amazon_ses',
  'sendgrid',
  'mailgun',
  'postmark',
  'custom_smtp',
  'resend',
] as const;

const ENCRYPTION_MODES = ['starttls', 'ssl', 'none'] as const;

export class CreateEmailProviderDto {
  @IsString()
  name!: string;

  @IsIn(PROVIDER_TYPES)
  providerType!: EmailProviderType;

  @IsOptional()
  @IsString()
  smtpHost?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(65535)
  smtpPort?: number;

  @IsOptional()
  @IsIn(ENCRYPTION_MODES)
  encryptionMode?: EmailEncryptionMode;

  @IsOptional()
  @IsString()
  username?: string;

  /** Write-only — never returned after save. */
  @IsOptional()
  @IsString()
  password?: string;

  /** Write-only API key for SendGrid/Resend/Mailgun/Postmark. */
  @IsOptional()
  @IsString()
  apiKey?: string;

  @IsString()
  senderName!: string;

  @IsString()
  senderEmail!: string;

  @IsOptional()
  @IsString()
  replyTo?: string;

  @IsOptional()
  @IsInt()
  @Min(1000)
  @Max(120_000)
  connectionTimeoutMs?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10)
  retryAttempts?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(60_000)
  retryDelayMs?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  dailySendingLimit?: number;

  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;

  @IsOptional()
  @IsInt()
  priority?: number;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

export class UpdateEmailProviderDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsIn(PROVIDER_TYPES)
  providerType?: EmailProviderType;

  @IsOptional()
  @IsString()
  smtpHost?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(65535)
  smtpPort?: number;

  @IsOptional()
  @IsIn(ENCRYPTION_MODES)
  encryptionMode?: EmailEncryptionMode;

  @IsOptional()
  @IsString()
  username?: string;

  @IsOptional()
  @IsString()
  password?: string;

  @IsOptional()
  @IsString()
  apiKey?: string;

  @IsOptional()
  @IsString()
  senderName?: string;

  @IsOptional()
  @IsString()
  senderEmail?: string;

  @IsOptional()
  @IsString()
  replyTo?: string;

  @IsOptional()
  @IsInt()
  connectionTimeoutMs?: number;

  @IsOptional()
  @IsInt()
  retryAttempts?: number;

  @IsOptional()
  @IsInt()
  retryDelayMs?: number;

  @IsOptional()
  @IsInt()
  dailySendingLimit?: number | null;

  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;

  @IsOptional()
  @IsInt()
  priority?: number;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

export class SendTestEmailDto {
  @IsString()
  to!: string;
}
