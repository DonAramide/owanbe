/**
 * Shared ticket-tier purchase eligibility rules (Phase 13).
 * Metadata-driven — no schema migration required for MVP.
 */

export type TierSaleMeta = {
  visibility?: string;
  salesStartAt?: string | null;
  salesEndAt?: string | null;
  archived?: boolean;
  unlimitedCapacity?: boolean;
  minQuantity?: number;
  maxQuantity?: number | null;
  maxPerUser?: number | null;
  sortOrder?: number;
};

export function parseTierMeta(metadata: Record<string, unknown> | null | undefined): TierSaleMeta {
  const m = metadata ?? {};
  return {
    visibility: m.visibility != null ? String(m.visibility) : 'publicListing',
    salesStartAt: m.salesStartAt != null ? String(m.salesStartAt) : null,
    salesEndAt: m.salesEndAt != null ? String(m.salesEndAt) : null,
    archived: m.archived === true,
    unlimitedCapacity: m.unlimitedCapacity === true,
    minQuantity: m.minQuantity != null ? Number(m.minQuantity) : 1,
    maxQuantity: m.maxQuantity != null ? Number(m.maxQuantity) : null,
    maxPerUser: m.maxPerUser != null ? Number(m.maxPerUser) : null,
    sortOrder: m.sortOrder != null ? Number(m.sortOrder) : 0,
  };
}

export type TierEligibilityFailure = {
  code: string;
  message: string;
};

/**
 * Returns null if purchasable; otherwise a structured failure.
 * @param forPublicListing when true, also rejects hidden tiers (storefront filter).
 */
export function assertTierPurchasable(opts: {
  name: string;
  salesPaused: boolean;
  metadata: Record<string, unknown> | null | undefined;
  now?: Date;
  forPublicListing?: boolean;
}): TierEligibilityFailure | null {
  const now = opts.now ?? new Date();
  const meta = parseTierMeta(opts.metadata);

  if (meta.archived) {
    return { code: 'TIER_ARCHIVED', message: `${opts.name} is no longer available` };
  }
  if (opts.salesPaused) {
    return { code: 'TIER_PAUSED', message: `${opts.name} is not on sale` };
  }
  if (opts.forPublicListing !== false && (meta.visibility === 'hidden' || meta.visibility === 'Hidden')) {
    return { code: 'TIER_HIDDEN', message: `${opts.name} is not publicly available` };
  }
  if (meta.salesStartAt) {
    const start = new Date(meta.salesStartAt);
    if (!Number.isNaN(start.getTime()) && now < start) {
      return { code: 'SALES_NOT_STARTED', message: `${opts.name} sales have not started yet` };
    }
  }
  if (meta.salesEndAt) {
    const end = new Date(meta.salesEndAt);
    if (!Number.isNaN(end.getTime()) && now > end) {
      return { code: 'SALES_ENDED', message: `${opts.name} sales have ended` };
    }
  }
  return null;
}

export function assertQuantityRules(opts: {
  name: string;
  quantity: number;
  remaining: number;
  unlimited: boolean;
  minQuantity: number;
  maxQuantity: number | null;
}): TierEligibilityFailure | null {
  const minQ = Math.max(1, opts.minQuantity || 1);
  if (opts.quantity < minQ) {
    return {
      code: 'MIN_QUANTITY',
      message: `${opts.name} requires at least ${minQ} ticket(s)`,
    };
  }
  if (opts.maxQuantity != null && opts.maxQuantity > 0 && opts.quantity > opts.maxQuantity) {
    return {
      code: 'MAX_QUANTITY',
      message: `${opts.name} allows at most ${opts.maxQuantity} ticket(s) per order`,
    };
  }
  if (!opts.unlimited && opts.remaining < opts.quantity) {
    return {
      code: 'INSUFFICIENT_INVENTORY',
      message: `Only ${opts.remaining} remaining for ${opts.name}`,
    };
  }
  return null;
}

/** True when tier should appear on public storefront. */
export function isPubliclyListable(opts: {
  salesPaused: boolean;
  metadata: Record<string, unknown> | null | undefined;
  now?: Date;
}): boolean {
  return (
    assertTierPurchasable({
      name: 'Tier',
      salesPaused: opts.salesPaused,
      metadata: opts.metadata,
      now: opts.now,
      forPublicListing: true,
    }) == null
  );
}
