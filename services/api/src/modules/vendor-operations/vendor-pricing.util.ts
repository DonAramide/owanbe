/**
 * Owanbe-controlled vendor commerce pricing.
 * Vendor base payout → customer-facing price via configurable markup_bps.
 * Default markup: 4000 bps (40%). Never expose margin to organizer/vendor clients.
 *
 * Resolution hierarchy (deterministic — never reverse):
 * 1. vendor + service override
 * 2. vendor override
 * 3. service category rule
 * 4. platform default
 * 5. hardcoded fallback 4000 bps
 */

export function normalizeServiceKey(label: string | null | undefined): string {
  const raw = (label ?? '').trim().toLowerCase();
  if (!raw) return 'general';
  const key = raw.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  return key || 'general';
}

export type PricingRuleRow = {
  vendor_id: string | null;
  service_key: string | null;
  markup_bps: number;
  is_default: boolean;
};

export type MarkupResolvedFrom =
  | 'vendor_service_override'
  | 'vendor_override'
  | 'service_category_rule'
  | 'platform_default_rule'
  | 'hardcoded_fallback_4000_bps';

export type MarkupResolution = {
  markupBps: number;
  resolvedFrom: MarkupResolvedFrom;
};

export const PRICING_RESOLUTION_ORDER: MarkupResolvedFrom[] = [
  'vendor_service_override',
  'vendor_override',
  'service_category_rule',
  'platform_default_rule',
  'hardcoded_fallback_4000_bps',
];

/** Pure deterministic markup resolution used by CRM, marketplace, and admin preview. */
export function resolveMarkupFromRules(
  rules: PricingRuleRow[],
  serviceKey: string | null | undefined,
  vendorId: string | null | undefined,
): MarkupResolution {
  const key = serviceKey ? normalizeServiceKey(serviceKey) : null;
  const usableKey = key && key !== 'general' ? key : null;
  const vid = vendorId?.trim() || null;

  if (vid && usableKey) {
    const hit = rules.find(
      (r) =>
        !r.is_default &&
        r.vendor_id === vid &&
        r.service_key === usableKey,
    );
    if (hit) {
      return {
        markupBps: hit.markup_bps,
        resolvedFrom: 'vendor_service_override',
      };
    }
  }

  if (vid) {
    const hit = rules.find(
      (r) =>
        !r.is_default &&
        r.vendor_id === vid &&
        (r.service_key == null || r.service_key === ''),
    );
    if (hit) {
      return { markupBps: hit.markup_bps, resolvedFrom: 'vendor_override' };
    }
  }

  if (usableKey) {
    const hit = rules.find(
      (r) =>
        !r.is_default &&
        (r.vendor_id == null || r.vendor_id === '') &&
        r.service_key === usableKey,
    );
    if (hit) {
      return {
        markupBps: hit.markup_bps,
        resolvedFrom: 'service_category_rule',
      };
    }
  }

  const def = rules.find((r) => r.is_default);
  if (def) {
    return {
      markupBps: def.markup_bps,
      resolvedFrom: 'platform_default_rule',
    };
  }

  return {
    markupBps: 4000,
    resolvedFrom: 'hardcoded_fallback_4000_bps',
  };
}

export function customerPriceFromVendorPayout(vendorPayoutMinor: bigint, markupBps: number): {
  customerPriceMinor: bigint;
  platformMarginMinor: bigint;
} {
  const bps = BigInt(Math.max(0, Math.min(9000, markupBps)));
  const customer = (vendorPayoutMinor * (10000n + bps)) / 10000n;
  return {
    customerPriceMinor: customer,
    platformMarginMinor: customer - vendorPayoutMinor,
  };
}

export function vendorPayoutFromCustomerPrice(customerPriceMinor: bigint, markupBps: number): {
  vendorPayoutMinor: bigint;
  platformMarginMinor: bigint;
} {
  const bps = BigInt(Math.max(0, Math.min(9000, markupBps)));
  const denom = 10000n + bps;
  const payout = (customerPriceMinor * 10000n) / denom;
  return {
    vendorPayoutMinor: payout,
    platformMarginMinor: customerPriceMinor - payout,
  };
}
