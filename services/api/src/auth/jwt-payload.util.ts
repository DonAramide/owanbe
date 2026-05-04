import type { OwanbeRole } from '../common/types/jwt-user';

function getByPath(obj: Record<string, unknown>, path: string): unknown {
  const parts = path.split('.');
  let cur: unknown = obj;
  for (const p of parts) {
    if (cur === null || cur === undefined) return undefined;
    if (typeof cur !== 'object') return undefined;
    cur = (cur as Record<string, unknown>)[p];
  }
  return cur;
}

/** Map legacy JWT / metadata codes to DB role codes. */
export function normalizeJwtRoleCode(raw: string): OwanbeRole | null {
  const r = raw.trim().toLowerCase();
  if (r === 'admin') return 'admin_super';
  const allowed: ReadonlySet<string> = new Set([
    'admin_super',
    'admin_ops',
    'admin_support',
    'client',
    'vendor',
    'vendor_pending',
    'guest',
  ]);
  if (allowed.has(r)) return r as OwanbeRole;
  return null;
}

export function extractTenantId(
  payload: Record<string, unknown>,
  claimPath: string,
): string | undefined {
  const v = getByPath(payload, claimPath);
  if (typeof v === 'string' && v.length > 0) return v;
  const top = payload.tenant_id;
  if (typeof top === 'string') return top;
  return undefined;
}

export function extractJwtRoleHints(
  payload: Record<string, unknown>,
  claimPath: string,
): OwanbeRole[] {
  const raw = getByPath(payload, claimPath);
  if (!Array.isArray(raw)) return [];
  const out: OwanbeRole[] = [];
  for (const item of raw) {
    if (typeof item !== 'string') continue;
    const n = normalizeJwtRoleCode(item);
    if (n) out.push(n);
  }
  return out;
}
