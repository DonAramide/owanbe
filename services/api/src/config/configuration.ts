import type { EnvVars } from './env.schema';

export default (): EnvVars => ({
  NODE_ENV: process.env.NODE_ENV ?? 'development',
  PORT: parseInt(process.env.PORT ?? '8080', 10),
  DATABASE_URL: process.env.DATABASE_URL ?? '',
  SUPABASE_JWT_SECRET: process.env.SUPABASE_JWT_SECRET ?? '',
  JWT_ROLES_CLAIM_PATH: process.env.JWT_ROLES_CLAIM_PATH ?? 'app_metadata.roles',
  JWT_TENANT_CLAIM_PATH: process.env.JWT_TENANT_CLAIM_PATH ?? 'app_metadata.tenant_id',
  ROLES_CACHE_TTL_MS: parseInt(process.env.ROLES_CACHE_TTL_MS ?? '45000', 10),
  QUASER_ROUTER_BASE_URL: process.env.QUASER_ROUTER_BASE_URL ?? '',
  QUASER_ROUTER_API_KEY: process.env.QUASER_ROUTER_API_KEY ?? '',
  QUASER_WEBHOOK_SECRET: process.env.QUASER_WEBHOOK_SECRET ?? '',
  PAYMENT_S2S_VERIFY_THRESHOLD_MINOR: parseInt(
    process.env.PAYMENT_S2S_VERIFY_THRESHOLD_MINOR ?? '500000',
    10,
  ),
  PAYOUT_COOLDOWN_FALLBACK_HOURS: parseInt(
    process.env.PAYOUT_COOLDOWN_FALLBACK_HOURS ?? '36',
    10,
  ),
  PUBLIC_API_BASE_URL: process.env.PUBLIC_API_BASE_URL ?? '',
  ALERT_WEBHOOK_URL: process.env.ALERT_WEBHOOK_URL ?? '',
  ALERT_EMAIL_TO: process.env.ALERT_EMAIL_TO ?? '',
  ALERT_DEDUPE_WINDOW_MS: parseInt(process.env.ALERT_DEDUPE_WINDOW_MS ?? '120000', 10),
  PAYMENT_TIMEOUT_MINUTES: parseInt(process.env.PAYMENT_TIMEOUT_MINUTES ?? '30', 10),
  PAYOUT_TIMEOUT_MINUTES: parseInt(process.env.PAYOUT_TIMEOUT_MINUTES ?? '240', 10),
  FINANCE_TIMEOUT_SWEEP_MS: parseInt(process.env.FINANCE_TIMEOUT_SWEEP_MS ?? '60000', 10),
});
