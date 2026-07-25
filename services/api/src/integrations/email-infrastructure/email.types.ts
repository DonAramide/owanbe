export type EmailProviderType =
  | 'generic_smtp'
  | 'zoho_smtp'
  | 'microsoft_365'
  | 'google_workspace'
  | 'amazon_ses'
  | 'sendgrid'
  | 'mailgun'
  | 'postmark'
  | 'custom_smtp'
  | 'resend';

export type EmailEncryptionMode = 'starttls' | 'ssl' | 'none';

export type EmailHealthStatus = 'unknown' | 'healthy' | 'degraded' | 'unhealthy';

export interface EmailProviderRow {
  id: string;
  tenant_id: string | null;
  name: string;
  provider_type: EmailProviderType;
  smtp_host: string | null;
  smtp_port: number | null;
  encryption_mode: EmailEncryptionMode;
  username: string | null;
  password_ciphertext: string | null;
  api_key_ciphertext: string | null;
  sender_name: string;
  sender_email: string;
  reply_to: string | null;
  connection_timeout_ms: number;
  retry_attempts: number;
  retry_delay_ms: number;
  daily_sending_limit: number | null;
  enabled: boolean;
  is_default: boolean;
  priority: number;
  health_status: EmailHealthStatus;
  last_success_at: Date | null;
  last_failure_at: Date | null;
  last_error_message: string | null;
  metadata: Record<string, unknown>;
  created_at: Date;
  updated_at: Date;
}

/** Public DTO — never includes secrets. */
export interface EmailProviderPublicView {
  id: string;
  tenantId: string | null;
  name: string;
  providerType: EmailProviderType;
  smtpHost: string | null;
  smtpPort: number | null;
  encryptionMode: EmailEncryptionMode;
  username: string | null;
  hasPassword: boolean;
  hasApiKey: boolean;
  senderName: string;
  senderEmail: string;
  replyTo: string | null;
  connectionTimeoutMs: number;
  retryAttempts: number;
  retryDelayMs: number;
  dailySendingLimit: number | null;
  enabled: boolean;
  isDefault: boolean;
  priority: number;
  healthStatus: EmailHealthStatus;
  lastSuccessAt: string | null;
  lastFailureAt: string | null;
  lastErrorMessage: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface SendEmailCommand {
  to: string;
  subject: string;
  html: string;
  text?: string;
  template?: string;
  tenantId?: string;
  replyTo?: string;
  metadata?: Record<string, unknown>;
}

export interface SendEmailResult {
  ok: boolean;
  providerId?: string;
  providerName?: string;
  providerType?: EmailProviderType;
  externalId?: string;
  reason?: string;
}

export const SMTP_STYLE_PROVIDERS: EmailProviderType[] = [
  'generic_smtp',
  'zoho_smtp',
  'microsoft_365',
  'google_workspace',
  'custom_smtp',
  'amazon_ses',
];

export const API_KEY_PROVIDERS: EmailProviderType[] = [
  'sendgrid',
  'mailgun',
  'postmark',
  'resend',
];

/** Default connection presets (no credentials). */
export function providerTypeDefaults(type: EmailProviderType): {
  smtpHost?: string;
  smtpPort?: number;
  encryptionMode?: EmailEncryptionMode;
} {
  switch (type) {
    case 'zoho_smtp':
      return { smtpHost: 'smtp.zoho.com', smtpPort: 587, encryptionMode: 'starttls' };
    case 'microsoft_365':
      return { smtpHost: 'smtp.office365.com', smtpPort: 587, encryptionMode: 'starttls' };
    case 'google_workspace':
      return { smtpHost: 'smtp.gmail.com', smtpPort: 587, encryptionMode: 'starttls' };
    case 'amazon_ses':
      return { smtpHost: 'email-smtp.us-east-1.amazonaws.com', smtpPort: 587, encryptionMode: 'starttls' };
    default:
      return { encryptionMode: 'starttls', smtpPort: 587 };
  }
}
