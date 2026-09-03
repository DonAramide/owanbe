export type DateAvailabilityStatus = 'AVAILABLE' | 'BOOKED' | 'CONFLICTING' | 'UNAVAILABLE';

export type BookedRange = {
  start: Date;
  end: Date;
};

/** Inclusive event window. Null/equal ends_at → 24h single-day window (existing timestamptz, no TZ rewrite). */
export function resolveEventWindow(startsAt: Date, endsAt: Date | null | undefined): { start: Date; end: Date } {
  const start = startsAt;
  if (endsAt && endsAt.getTime() > start.getTime()) {
    return { start, end: endsAt };
  }
  return { start, end: new Date(start.getTime() + 24 * 60 * 60 * 1000) };
}

export function rangesOverlap(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date): boolean {
  return aStart.getTime() < bEnd.getTime() && bStart.getTime() < aEnd.getTime();
}

/** Booking completely covers the organizer window. */
export function rangeFullyCovers(booked: BookedRange, window: BookedRange): boolean {
  return booked.start.getTime() <= window.start.getTime() && booked.end.getTime() >= window.end.getTime();
}

export function classifyDateAvailability(
  window: BookedRange,
  bookedRanges: BookedRange[],
): Exclude<DateAvailabilityStatus, 'UNAVAILABLE'> {
  const overlapping = bookedRanges.filter((b) => rangesOverlap(window.start, window.end, b.start, b.end));
  if (overlapping.length === 0) return 'AVAILABLE';
  if (overlapping.some((b) => rangeFullyCovers(b, window))) return 'BOOKED';
  return 'CONFLICTING';
}

/** Intersection of two half-open-style intervals; null if they do not overlap. */
export function clipRange(range: BookedRange, window: BookedRange): BookedRange | null {
  const startMs = Math.max(range.start.getTime(), window.start.getTime());
  const endMs = Math.min(range.end.getTime(), window.end.getTime());
  if (startMs >= endMs) return null;
  return { start: new Date(startMs), end: new Date(endMs) };
}
