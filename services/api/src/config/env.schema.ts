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
  ALERT_WEBHOOK_URL: Joi.string().uri().optional().allow(''),
  ALERT_EMAIL_TO: Joi.string().optional().allow(''),
  ALERT_DEDUPE_WINDOW_MS: Joi.number().integer().min(0).max(3_600_000).default(120_000),
  PAYMENT_TIMEOUT_MINUTES: Joi.number().integer().min(1).max(1440).default(30),
  PAYOUT_TIMEOUT_MINUTES: Joi.number().integer().min(1).max(10_080).default(240),
  FINANCE_TIMEOUT_SWEEP_MS: Joi.number().integer().min(10_000).max(3_600_000).default(60_000),
  /** S5: mirror treasury settlement journals into financial_transactions + postings. */
  QFE_DUAL_WRITE_TREASURY: Joi.boolean().truthy('true', '1', 'yes').falsy('false', '0', 'no').default(false),
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
  ALERT_WEBHOOK_URL: string;
  ALERT_EMAIL_TO: string;
  ALERT_DEDUPE_WINDOW_MS: number;
  PAYMENT_TIMEOUT_MINUTES: number;
  PAYOUT_TIMEOUT_MINUTES: number;
  FINANCE_TIMEOUT_SWEEP_MS: number;
  QFE_DUAL_WRITE_TREASURY: boolean;
};
