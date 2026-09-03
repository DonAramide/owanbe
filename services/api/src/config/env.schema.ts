import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),
  PORT: Joi.number().port().default(8080),
  DATABASE_URL: Joi.string().required(),
  SUPABASE_JWT_SECRET: Joi.string().min(16).required(),
  /** Optional: comma-separated allowed role codes from JWT (default: admin,client,vendor,guest) */
  JWT_ROLES_CLAIM_PATH: Joi.string().default('app_metadata.roles'),
  JWT_TENANT_CLAIM_PATH: Joi.string().default('app_metadata.tenant_id'),
  ROLES_CACHE_TTL_MS: Joi.number().integer().min(1000).max(300_000).default(45_000),

  QUASER_ROUTER_BASE_URL: Joi.string().uri().optional().allow(''),
  QUASER_ROUTER_API_KEY: Joi.string().optional().allow(''),
  QUASER_WEBHOOK_SECRET: Joi.string().allow('').default(''),
  /** S2S verify + stricter checks when captured amount >= this (minor units). 0 = always verify if URL+key set. */
  PAYMENT_S2S_VERIFY_THRESHOLD_MINOR: Joi.number().integer().min(0).default(500_000),
  /** Fallback hours when booking.escrow_release_not_before is null (must align with tenant_finance_settings when possible). */
  PAYOUT_COOLDOWN_FALLBACK_HOURS: Joi.number().integer().min(0).max(168).default(36),
  PUBLIC_API_BASE_URL: Joi.string().uri().optional().allow(''),
  /**
   * User-facing web/app origin for invitation RSVP deep links (not the API host).
   * Example: https://app.example.com — never use PUBLIC_API_BASE_URL here.
   */
  PUBLIC_APP_BASE_URL: Joi.string().uri().optional().allow(''),
  /** @deprecated Prefer PUBLIC_APP_BASE_URL. Kept as alias for invitation links. */
  APP_PUBLIC_URL: Joi.string().uri().optional().allow(''),
  ALERT_WEBHOOK_URL: Joi.string().uri().optional().allow(''),
  ALERT_EMAIL_TO: Joi.string().optional().allow(''),
  ALERT_DEDUPE_WINDOW_MS: Joi.number().integer().min(0).max(3_600_000).default(120_000),
  PAYMENT_TIMEOUT_MINUTES: Joi.number().integer().min(1).max(1440).default(30),
  PAYOUT_TIMEOUT_MINUTES: Joi.number().integer().min(1).max(10_080).default(240),
  FINANCE_TIMEOUT_SWEEP_MS: Joi.number().integer().min(10_000).max(3_600_000).default(60_000),
  /** S5: mirror treasury settlement journals into financial_transactions + postings. */
  QFE_DUAL_WRITE_TREASURY: Joi.boolean().truthy('true', '1', 'yes').falsy('false', '0', 'no').default(false),

  /** Phase 9: production disables payment auto-stub; development allows Quaser-less stubs. */
  INTEGRATIONS_MODE: Joi.string().valid('development', 'production').default('development'),

  /**
   * @deprecated Business email SMTP/API credentials live in Enterprise Email Infrastructure (DB).
   * RESEND_API_KEY is no longer used for outbound mail. Kept optional for backward compatibility only.
   */
  RESEND_API_KEY: Joi.string().optional().allow(''),
  /** @deprecated Use Super Admin sender_email on the default provider. */
  NOTIFICATION_FROM_EMAIL: Joi.string().optional().allow(''),
  /** Fallback delivery webhook for SMS/email when no enterprise provider configured. */
  NOTIFICATION_WEBHOOK_URL: Joi.string().uri().optional().allow(''),

  /**
   * REQUIRED — AES key material for encrypting email provider secrets at rest.
   * Not an SMTP password. Use a long random string (32+ chars) or 64-char hex.
   * API refuses to start if missing.
   */
  EMAIL_SECRETS_ENCRYPTION_KEY: Joi.string().min(32).required().messages({
    'any.required':
      'EMAIL_SECRETS_ENCRYPTION_KEY is required. Set a 32+ character secret (or 64-char hex) so email provider passwords are encrypted at rest. Without it the API will not start.',
    'string.min':
      'EMAIL_SECRETS_ENCRYPTION_KEY must be at least 32 characters (or a 64-character hex key).',
    'string.empty':
      'EMAIL_SECRETS_ENCRYPTION_KEY cannot be empty. Set a production encryption secret before starting the API.',
  }),

  /**
   * Optional: sync default SMTP provider → Supabase Auth via Management API.
   * Personal access token must be Owner/Administrator. Never commit the token.
   */
  SUPABASE_ACCESS_TOKEN: Joi.string().optional().allow(''),
  SUPABASE_PROJECT_REF: Joi.string().optional().allow(''),

  /** SMS — Twilio */
  TWILIO_ACCOUNT_SID: Joi.string().optional().allow(''),
  TWILIO_AUTH_TOKEN: Joi.string().optional().allow(''),
  TWILIO_FROM_NUMBER: Joi.string().optional().allow(''),

  /** Storage — Supabase Storage */
  SUPABASE_URL: Joi.string().uri().optional().allow(''),
  SUPABASE_SERVICE_ROLE_KEY: Joi.string().optional().allow(''),
  STORAGE_BUCKET: Joi.string().default('owanbe-media'),

  /**
   * Phase 3A — CRM realtime SSE (hybrid with existing REST + 5s polling).
   * When false, API rejects GET /me/crm/stream and does not publish CRM SSE events.
   * Polling/REST continue unchanged.
   */
  CRM_REALTIME_SSE: Joi.boolean().truthy('true', '1', 'yes').falsy('false', '0', 'no').default(true),
  /**
   * Fan-out across API instances. `pg_notify` uses PostgreSQL LISTEN/NOTIFY
   * (preferred — Redis is not in this stack). `local` = in-process only (dev).
   */
  CRM_REALTIME_FANOUT: Joi.string().valid('pg_notify', 'local').default('pg_notify'),
}).unknown(true);

export type EnvVars = {
  NODE_ENV: string;
  PORT: number;
  DATABASE_URL: string;
  SUPABASE_JWT_SECRET: string;
  JWT_ROLES_CLAIM_PATH: string;
  JWT_TENANT_CLAIM_PATH: string;
  ROLES_CACHE_TTL_MS: number;
  QUASER_ROUTER_BASE_URL: string;
  QUASER_ROUTER_API_KEY: string;
  QUASER_WEBHOOK_SECRET: string;
  PAYMENT_S2S_VERIFY_THRESHOLD_MINOR: number;
  PAYOUT_COOLDOWN_FALLBACK_HOURS: number;
  PUBLIC_API_BASE_URL: string;
  PUBLIC_APP_BASE_URL: string;
  APP_PUBLIC_URL: string;
  ALERT_WEBHOOK_URL: string;
  ALERT_EMAIL_TO: string;
  ALERT_DEDUPE_WINDOW_MS: number;
  PAYMENT_TIMEOUT_MINUTES: number;
  PAYOUT_TIMEOUT_MINUTES: number;
  FINANCE_TIMEOUT_SWEEP_MS: number;
  QFE_DUAL_WRITE_TREASURY: boolean;
  INTEGRATIONS_MODE: string;
  RESEND_API_KEY: string;
  NOTIFICATION_FROM_EMAIL: string;
  NOTIFICATION_WEBHOOK_URL: string;
  EMAIL_SECRETS_ENCRYPTION_KEY: string;
  SUPABASE_ACCESS_TOKEN: string;
  SUPABASE_PROJECT_REF: string;
  TWILIO_ACCOUNT_SID: string;
  TWILIO_AUTH_TOKEN: string;
  TWILIO_FROM_NUMBER: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  STORAGE_BUCKET: string;
  CRM_REALTIME_SSE: boolean;
  CRM_REALTIME_FANOUT: 'pg_notify' | 'local' | string;
};
