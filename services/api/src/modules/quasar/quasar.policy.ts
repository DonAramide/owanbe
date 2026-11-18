const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const SENSITIVE_KEYS = new Set([
  'secretkey',
  'secret_key',
  'clientsecret',
  'client_secret',
  'servicesecret',
  'service_secret',
  'signingsecret',
  'signing_secret',
  'webhooksigningsecret',
  'webhook_signing_secret',
  'apikey',
  'api_key',
  'authorization',
  'password',
  'quasarapikeysecret',
  'qpc_secret',
]);

export type QuasarKeyEnvironment = 'test';

export type QuasarPaymentAction = 'capture_ticket' | 'complete_payout' | 'fail_payout' | 'ignore';

/**
 * Sandbox phase accepts QUASAR_ENVIRONMENT=test only.
 * A live environment or QUASAR_LIVE_ENABLED=true fails closed.
 */
export function quasarKeyEnvironment(
  environment?: string,
  liveEnabled?: boolean,
): QuasarKeyEnvironment {
  const selected = (environment ?? 'test').trim().toLowerCase();
  if (liveEnabled === true || selected === 'live' || selected === 'production') {
    throw new Error(
      'Quasar live is disabled. Set QUASAR_ENVIRONMENT=test and QUASAR_LIVE_ENABLED=false',
    );
  }
  if (selected !== 'test') {
    throw new Error('QUASAR_ENVIRONMENT must be test');
  }
  return 'test';
}

export function assertTenantApiKey(secretKey: string): void {
  if (!secretKey.startsWith('sk_test_') || secretKey.startsWith('sk_live_')) {
    throw new Error('This phase accepts sk_test_ keys only');
  }
}

export function isQuasarSecret(value: string): boolean {
  const v = value.trim();
  return (
    v.startsWith('sk_') ||
    v.startsWith('qps_') ||
    v.startsWith('qpc_')
  );
}

export function redactQuasarSecrets<T>(value: T): T {
  return walk(value) as T;
}

function redactString(value: string): string {
  return value.replace(/\b(?:sk_live_|sk_test_|qps_sec_|qps_|qpc_)[A-Za-z0-9_-]*/g, '[redacted]');
}

function walk(value: unknown): unknown {
  if (typeof value === 'string') {
    return redactString(value);
  }
  if (Array.isArray(value)) return value.map(walk);
  if (value && typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [key, nested] of Object.entries(value as Record<string, unknown>)) {
      if (SENSITIVE_KEYS.has(key.toLowerCase())) continue;
      out[key] = walk(nested);
    }
    return out;
  }
  return value;
}

export function assertQuasarPathAllowed(path: string): void {
  if (path.toLowerCase().includes('admin/auth/login')) {
    throw new Error('Owanbe does not call Quasar admin login');
  }
}

export function normalizeQuasarBaseUrl(raw: string): string {
  let base = raw.trim().replace(/\/$/, '');
  if (!base) return '';
  if (!/\/api\/v1$/i.test(base)) base = `${base}/api/v1`;
  return base;
}

export function quasarTenantSlug(ownerKind: string, slug: string, ownerId: string): string {
  const raw = `owanbe-${ownerKind}-${slug}`
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  const suffix = ownerId.replace(/-/g, '').slice(0, 8);
  return `${raw.slice(0, 48)}-${suffix}`.replace(/-+/g, '-').slice(0, 63);
}

export function apiKeyHint(secretKey: string): string {
  const prefix = secretKey.startsWith('sk_test_')
    ? 'sk_test_'
    : secretKey.startsWith('sk_live_')
      ? 'sk_live_'
      : 'sk_';
  return `${prefix}…${secretKey.slice(-4)}`;
}

export function majorAmountFromMinor(minor: string): string {
  if (!/^\d+$/.test(minor)) {
    throw new Error('Amount must be a non-negative integer in minor units');
  }
  const value = BigInt(minor);
  const whole = value / 100n;
  const frac = (value % 100n).toString().padStart(2, '0');
  return `${whole.toString()}.${frac}`;
}

export function minorUnitsFromQuasarAmount(data: Record<string, unknown>): string | null {
  const explicit = data.amountMinor ?? data.amount_minor;
  if (typeof explicit === 'string' && /^\d+$/.test(explicit)) return explicit;
  if (typeof explicit === 'number' && Number.isInteger(explicit) && explicit >= 0) {
    return String(explicit);
  }

  const amount = data.amount ?? data.fundedAmount ?? data.funded_amount;
  if (typeof amount === 'string') {
    return minorFromMajorString(amount.trim());
  }
  if (typeof amount === 'number' && Number.isFinite(amount) && amount >= 0) {
    return minorFromMajorString(amount.toFixed(2));
  }
  return null;
}

function minorFromMajorString(amount: string): string | null {
  const match = amount.match(/^(\d+)\.(\d{2})(\d{2})?$/);
  if (!match) return null;
  return (BigInt(match[1]) * 100n + BigInt(match[2])).toString();
}

export function actionForQuasarEvent(event: string): QuasarPaymentAction {
  switch (event) {
    case 'virtual_account.funded':
      return 'capture_ticket';
    case 'transfer.success':
      return 'complete_payout';
    case 'transfer.failed':
      return 'fail_payout';
    default:
      return 'ignore';
  }
}

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function pickString(source: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const value = source[key];
    if (typeof value === 'string' && value.trim()) return value.trim();
  }
  return null;
}

export function unwrapQuasarData(body: unknown): Record<string, unknown> {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new Error('Quasar response was empty');
  }
  const root = body as Record<string, unknown>;
  if (typeof root.responseCode === 'string' && root.responseCode !== '00') {
    const message = typeof root.message === 'string' ? root.message : `Quasar responseCode ${root.responseCode}`;
    throw new Error(message);
  }
  let data: unknown = root.data ?? root;
  for (let depth = 0; depth < 4; depth += 1) {
    if (!data || typeof data !== 'object' || Array.isArray(data)) break;
    const inner = data as Record<string, unknown>;
    if (inner.id != null || inner.secretKey != null || inner.secret_key != null) break;
    const nested = inner.data;
    if (!nested || typeof nested !== 'object' || Array.isArray(nested)) break;
    data = nested;
  }
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    throw new Error('Quasar response missing data');
  }
  return data as Record<string, unknown>;
}

export function readSecretKey(data: Record<string, unknown>): string {
  const direct = pickString(data, ['secretKey', 'secret_key']);
  if (direct && !isQuasarSecretPlaceholder(direct)) return direct;
  const nested = data.data;
  if (nested && typeof nested === 'object' && !Array.isArray(nested)) {
    const inner = pickString(nested as Record<string, unknown>, ['secretKey', 'secret_key']);
    if (inner) return inner;
  }
  throw new Error('Quasar API key response did not include secretKey');
}

function isQuasarSecretPlaceholder(value: string): boolean {
  return value === '[redacted]';
}

export function payerNames(input: {
  firstName?: string | null;
  lastName?: string | null;
  displayName?: string | null;
}): { firstName: string; lastName: string } {
  const first = input.firstName?.trim();
  const last = input.lastName?.trim();
  if (first && last) return { firstName: first, lastName: last };
  const parts = (input.displayName ?? '').trim().split(/\s+/).filter(Boolean);
  return {
    firstName: first || parts[0] || 'Payer',
    lastName: last || parts.slice(1).join(' ') || 'Attendee',
  };
}

export function ticketPaymentIdFromFundedData(data: Record<string, unknown>): string | null {
  const meta = data.metadata;
  if (!meta || typeof meta !== 'object' || Array.isArray(meta)) return null;
  const id = pickString(meta as Record<string, unknown>, ['ticketPaymentId', 'ticketId']);
  if (id && isUuid(id)) return id;
  const reason = pickString(data, ['reason']);
  return reason && isUuid(reason) ? reason : null;
}

export function payerIdFromFundedData(data: Record<string, unknown>): string | null {
  const direct = pickString(data, ['payerId', 'studentId', 'walletOwnerId']);
  if (direct && isUuid(direct)) return direct;
  const meta = data.metadata;
  if (meta && typeof meta === 'object' && !Array.isArray(meta)) {
    const id = pickString(meta as Record<string, unknown>, ['payerId']);
    if (id && isUuid(id)) return id;
  }
  return null;
}

export function transferReferenceFromData(data: Record<string, unknown>): string | null {
  return pickString(data, ['reference']);
}

export function readVirtualAccount(data: Record<string, unknown>): {
  accountNumber: string;
  bankName: string;
  reference: string | null;
} {
  const accountNumber = pickString(data, ['account_number', 'accountNumber']);
  let bankName = pickString(data, ['bankName', 'bank_name']);
  const bank = data.bank;
  if (!bankName && bank && typeof bank === 'object' && !Array.isArray(bank)) {
    bankName = pickString(bank as Record<string, unknown>, ['name', 'bankName', 'bank_name']);
  }
  if (!accountNumber || !bankName) {
    throw new Error('Quasar virtual account response missing account number or bank name');
  }
  return {
    accountNumber,
    bankName,
    reference: pickString(data, ['reference']),
  };
}

export function readTransferStatus(data: Record<string, unknown>, fallbackReference: string): {
  reference: string;
  status: string;
} {
  const reference = pickString(data, ['reference']) ?? fallbackReference;
  const status = (pickString(data, ['status']) ?? 'AWAITING_APPROVAL').toUpperCase();
  return { reference, status };
}
