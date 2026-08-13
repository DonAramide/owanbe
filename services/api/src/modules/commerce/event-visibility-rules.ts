/**
 * Event-level discovery & purchase eligibility (Phase 14).
 * Complements tier rules in ticket-tier-rules.ts.
 */

export type ListingVisibility = 'public' | 'invite_only' | 'hidden' | 'private';

export type EventVisibilityFailure = {
  code: string;
  message: string;
};

export function normalizeListingVisibility(raw: unknown): ListingVisibility {
  const v = String(raw ?? 'invite_only')
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, '_');
  if (v === 'public' || v === 'public_listing' || v === 'open') return 'public';
  if (v === 'hidden') return 'hidden';
  if (v === 'private') return 'private';
  return 'invite_only';
}

export function normalizeAccessMode(raw: unknown): 'PUBLIC_TICKETED' | 'PRIVATE_INVITATION' {
  const v = String(raw ?? 'PRIVATE_INVITATION').trim().toUpperCase();
  return v === 'PUBLIC_TICKETED' ? 'PUBLIC_TICKETED' : 'PRIVATE_INVITATION';
}

/** Draft / cancelled / unpublished never appear in Discover. */
export function isPublishedStatus(status: string): boolean {
  return ['published', 'live', 'completed'].includes(String(status ?? '').toLowerCase());
}

/**
 * Scheduled publish: if metadata has a future publishAt / scheduledPublishAt
 * and status is still draft, treat as not yet public.
 * (Immediate publish path stamps publishedAt on publish — no job yet.)
 */
export function isScheduledNotYetLive(
  status: string,
  metadata: Record<string, unknown> | null | undefined,
  now: Date = new Date(),
): boolean {
  if (isPublishedStatus(status)) return false;
  const m = metadata ?? {};
  const raw = m.publishAt ?? m.scheduledPublishAt ?? m.scheduledAt;
  if (raw == null) return false;
  const at = new Date(String(raw));
  if (Number.isNaN(at.getTime())) return false;
  return at.getTime() > now.getTime();
}

/**
 * Eligible for Discover / featured / trending / search catalogs.
 * Requires published-family status, PUBLIC_TICKETED access, listingVisibility=public.
 */
export function isPubliclyDiscoverable(opts: {
  status: string;
  metadata: Record<string, unknown> | null | undefined;
  now?: Date;
}): boolean {
  const now = opts.now ?? new Date();
  if (!isPublishedStatus(opts.status)) return false;
  if (isScheduledNotYetLive(opts.status, opts.metadata, now)) return false;
  const access = normalizeAccessMode(opts.metadata?.eventAccessMode);
  if (access !== 'PUBLIC_TICKETED') return false;
  const listing = normalizeListingVisibility(opts.metadata?.listingVisibility);
  return listing === 'public';
}

/**
 * Direct public event page: published + not hidden + not private-invitation mode.
 * Invite-only pages may be opened via deep link; purchase still checks invitation.
 *
 * Legacy/seed rows often omit `eventAccessMode`. Only block when PRIVATE_INVITATION
 * is set explicitly — missing mode must not 404 ticketed seed events.
 */
export function isPublicEventPageAllowed(opts: {
  status: string;
  metadata: Record<string, unknown> | null | undefined;
  now?: Date;
}): boolean {
  const now = opts.now ?? new Date();
  if (!isPublishedStatus(opts.status)) return false;
  if (isScheduledNotYetLive(opts.status, opts.metadata, now)) return false;
  const rawAccess = opts.metadata?.eventAccessMode;
  const accessExplicit = rawAccess != null && String(rawAccess).trim() !== '';
  if (accessExplicit && normalizeAccessMode(rawAccess) === 'PRIVATE_INVITATION') {
    return false;
  }
  const listing = normalizeListingVisibility(opts.metadata?.listingVisibility);
  if (listing === 'hidden' || listing === 'private') return false;
  return listing === 'public' || listing === 'invite_only';
}

/**
 * Open ticket purchase eligibility (before tier rules).
 * Returns null when purchase may proceed (invite check may still be required).
 */
export function assertEventPurchaseEligible(opts: {
  status: string;
  metadata: Record<string, unknown> | null | undefined;
  now?: Date;
}): EventVisibilityFailure | null {
  const now = opts.now ?? new Date();
  const status = String(opts.status ?? '').toLowerCase();

  if (status === 'draft') {
    return { code: 'EVENT_DRAFT', message: 'Event is still a draft and is not open for purchase' };
  }
  if (status === 'cancelled') {
    return { code: 'EVENT_CANCELLED', message: 'Event is not available for purchase' };
  }
  if (status === 'completed') {
    return { code: 'EVENT_COMPLETED', message: 'Event sales are closed' };
  }
  if (!['published', 'live'].includes(status)) {
    return { code: 'EVENT_NOT_SALEABLE', message: 'Event not open for ticket sales' };
  }
  if (isScheduledNotYetLive(opts.status, opts.metadata, now)) {
    return { code: 'EVENT_SCHEDULED', message: 'Event is scheduled and not yet open for purchase' };
  }

  const access = normalizeAccessMode(opts.metadata?.eventAccessMode);
  if (access === 'PRIVATE_INVITATION') {
    return {
      code: 'EVENT_PRIVATE',
      message: 'Private invitation events are not available for open ticket purchase',
    };
  }

  const listing = normalizeListingVisibility(opts.metadata?.listingVisibility);
  if (listing === 'hidden') {
    return {
      code: 'PURCHASE_NOT_ELIGIBLE',
      message: 'This event is not available for ticket purchase',
    };
  }
  if (listing === 'private') {
    return {
      code: 'EVENT_PRIVATE',
      message: 'This event is private and not available for ticket purchase',
    };
  }

  return null;
}

export function requiresInvitationForPurchase(
  metadata: Record<string, unknown> | null | undefined,
): boolean {
  return normalizeListingVisibility(metadata?.listingVisibility) === 'invite_only';
}
