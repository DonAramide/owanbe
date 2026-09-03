import { randomUUID } from 'crypto';
import { normalizeServiceKey } from './vendor-pricing.util';

/** Vendor-owned extras — never merge into Admin capability catalogue keys. */
export type VendorCustomExtra = {
  id: string;
  name: string;
  description: string | null;
  priceMinor: number | null;
  currency: string;
  active: boolean;
  isPublic: boolean;
};

const MAX_EXTRAS_PER_SERVICE = 24;
const MAX_NAME_LEN = 80;
const MAX_DESC_LEN = 500;

export function parseVendorCustomExtras(raw: unknown): VendorCustomExtra[] {
  const list = Array.isArray(raw)
    ? raw
    : raw && typeof raw === 'object' && Array.isArray((raw as { customExtras?: unknown }).customExtras)
      ? ((raw as { customExtras: unknown[] }).customExtras)
      : [];
  const seen = new Set<string>();
  const out: VendorCustomExtra[] = [];
  for (const entry of list) {
    if (!entry || typeof entry !== 'object') continue;
    const e = entry as Record<string, unknown>;
    const name = String(e.name ?? e.label ?? '').trim().slice(0, MAX_NAME_LEN);
    if (!name) continue;
    let id = String(e.id ?? '').trim();
    if (!id) {
      const slug = normalizeServiceKey(name);
      id = slug ? `extra_${slug}` : randomUUID();
    }
    if (seen.has(id)) continue;
    seen.add(id);
    const priceRaw = e.priceMinor ?? e.price_minor;
    let priceMinor: number | null = null;
    if (priceRaw != null && String(priceRaw).trim() !== '') {
      const n = Math.floor(Number(priceRaw));
      if (Number.isFinite(n) && n >= 0) priceMinor = n;
    }
    const descRaw = e.description != null ? String(e.description).trim() : '';
    out.push({
      id,
      name,
      description: descRaw ? descRaw.slice(0, MAX_DESC_LEN) : null,
      priceMinor,
      currency: String(e.currency ?? 'NGN').trim().toUpperCase() || 'NGN',
      active: e.active !== false && e.active !== 'false',
      isPublic: e.isPublic !== false && e.isPublic !== 'false' && e.is_public !== false,
    });
    if (out.length >= MAX_EXTRAS_PER_SERVICE) break;
  }
  return out;
}

/** Public marketplace: active + public only. */
export function publicVendorCustomExtras(extras: VendorCustomExtra[]): VendorCustomExtra[] {
  return extras.filter((e) => e.active && e.isPublic);
}

export function normalizeVendorCustomExtrasInput(raw: unknown): VendorCustomExtra[] {
  return parseVendorCustomExtras(raw);
}
