import { normalizeServiceKey } from './vendor-pricing.util';

export type AdminCapabilityTier = 'core' | 'optional';

export type AdminCapabilityDef = {
  key: string;
  label: string;
  enabled: boolean;
  /** Admin-owned classification. Default core when missing (legacy rows). */
  tier: AdminCapabilityTier;
};

export type VendorCapabilityDecl = {
  key: string;
  label: string;
  provided: boolean;
};

export type SelectedCapability = {
  key: string;
  label: string;
};

export function normalizeCapabilityKey(raw: string | null | undefined): string {
  return normalizeServiceKey(raw);
}

export function parseCapabilityTier(raw: unknown): AdminCapabilityTier {
  const v = String(raw ?? 'core').trim().toLowerCase();
  if (v === 'optional' || v === 'additional' || v === 'extra') return 'optional';
  return 'core';
}

export function parseAdminCapabilities(metadata: unknown): AdminCapabilityDef[] {
  const root =
    metadata && typeof metadata === 'object' && !Array.isArray(metadata)
      ? (metadata as Record<string, unknown>)
      : {};
  const raw = root.capabilities;
  if (!Array.isArray(raw)) return [];
  const seen = new Set<string>();
  const out: AdminCapabilityDef[] = [];
  for (const entry of raw) {
    if (!entry || typeof entry !== 'object') continue;
    const e = entry as Record<string, unknown>;
    const key = normalizeCapabilityKey(String(e.key ?? e.id ?? ''));
    if (!key || key === 'general' || seen.has(key)) continue;
    seen.add(key);
    const label = String(e.label ?? e.name ?? key).trim() || key;
    out.push({
      key,
      label,
      enabled: e.enabled !== false && e.enabled !== 'false',
      tier: parseCapabilityTier(e.tier ?? e.kind),
    });
  }
  return out;
}

export function parseVendorCapabilities(raw: unknown): VendorCapabilityDecl[] {
  const list = Array.isArray(raw)
    ? raw
    : raw && typeof raw === 'object' && Array.isArray((raw as { capabilities?: unknown }).capabilities)
      ? ((raw as { capabilities: unknown[] }).capabilities)
      : [];
  const seen = new Set<string>();
  const out: VendorCapabilityDecl[] = [];
  for (const entry of list) {
    if (!entry || typeof entry !== 'object') continue;
    const e = entry as Record<string, unknown>;
    const key = normalizeCapabilityKey(String(e.key ?? e.id ?? ''));
    if (!key || key === 'general' || seen.has(key)) continue;
    seen.add(key);
    const label = String(e.label ?? e.name ?? key).trim() || key;
    const provided = e.provided === true || e.provided === 'true';
    out.push({ key, label, provided });
  }
  return out;
}

export function parseSelectedCapabilities(raw: unknown): SelectedCapability[] {
  if (!Array.isArray(raw)) return [];
  const seen = new Set<string>();
  const out: SelectedCapability[] = [];
  for (const entry of raw) {
    if (!entry || typeof entry !== 'object') continue;
    const e = entry as Record<string, unknown>;
    const key = normalizeCapabilityKey(String(e.key ?? e.id ?? ''));
    if (!key || key === 'general' || seen.has(key)) continue;
    seen.add(key);
    out.push({
      key,
      label: String(e.label ?? e.name ?? key).trim() || key,
    });
  }
  return out;
}

export function enabledAdminCapabilities(defs: AdminCapabilityDef[]): AdminCapabilityDef[] {
  return defs.filter((d) => d.enabled);
}

export function providedVendorCapabilities(decls: VendorCapabilityDecl[]): VendorCapabilityDecl[] {
  return decls.filter((d) => d.provided);
}

/** Public marketplace presentation: admin-enabled ∩ vendor-provided. */
export function publicMarketplaceCapabilities(
  adminDefs: AdminCapabilityDef[],
  vendorDecls: VendorCapabilityDecl[],
): Array<{ key: string; label: string }> {
  return Array.from(allowedCapabilitySet(adminDefs, vendorDecls).entries()).map(([key, label]) => ({
    key,
    label,
  }));
}

/** Keys the organizer may select: admin-enabled ∩ vendor-provided. */
export function allowedCapabilitySet(
  adminEnabled: AdminCapabilityDef[],
  vendorProvided: VendorCapabilityDecl[],
): Map<string, string> {
  const vendorKeys = new Map(
    providedVendorCapabilities(vendorProvided).map((d) => [d.key, d.label] as const),
  );
  const allowed = new Map<string, string>();
  for (const d of enabledAdminCapabilities(adminEnabled)) {
    const vendorLabel = vendorKeys.get(d.key);
    if (vendorLabel != null) allowed.set(d.key, vendorLabel || d.label);
  }
  return allowed;
}

export function validateSelectedCapabilities(
  selected: SelectedCapability[],
  allowed: Map<string, string>,
): { ok: true; snapshot: SelectedCapability[] } | { ok: false; invalidKeys: string[] } {
  const invalid: string[] = [];
  const snapshot: SelectedCapability[] = [];
  const seen = new Set<string>();
  for (const s of selected) {
    const key = normalizeCapabilityKey(s.key);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    const label = allowed.get(key);
    if (!label) {
      invalid.push(key);
      continue;
    }
    snapshot.push({ key, label: s.label?.trim() || label });
  }
  if (invalid.length) return { ok: false, invalidKeys: invalid };
  return { ok: true, snapshot };
}

export function categoryMatchesService(
  slug: string,
  label: string,
  serviceKey: string,
  serviceName: string,
): boolean {
  const slugKey = normalizeServiceKey(slug);
  const labelKey = normalizeServiceKey(label);
  const nameKey = normalizeServiceKey(serviceName);
  if (slugKey && slugKey !== 'general' && slugKey === serviceKey) return true;
  if (labelKey && labelKey !== 'general' && labelKey === serviceKey) return true;
  if (nameKey && nameKey !== 'general' && (nameKey === slugKey || nameKey === labelKey)) return true;
  const name = serviceName.trim().toLowerCase();
  const cat = label.trim().toLowerCase();
  if (name && cat && (name.includes(cat) || cat.includes(name))) return true;
  return stemsMatch(slugKey, serviceKey) || stemsMatch(labelKey, serviceKey) || stemsMatch(slugKey, nameKey);
}

function stemsMatch(a: string, b: string): boolean {
  if (!a || !b || a === 'general' || b === 'general') return false;
  if (a === b) return true;
  const min = Math.min(a.length, b.length);
  if (min < 4) return false;
  const stem = Math.min(6, min);
  return a.startsWith(b.slice(0, stem)) || b.startsWith(a.slice(0, stem));
}
