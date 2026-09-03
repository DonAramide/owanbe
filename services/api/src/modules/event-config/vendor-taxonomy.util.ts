export const VENDOR_BUSINESS_CAPABILITY_KEYS = ['SERVICE_PROVIDER', 'RENTAL_PROVIDER'] as const;
export type VendorBusinessCapabilityKey = (typeof VENDOR_BUSINESS_CAPABILITY_KEYS)[number];

export const OFFERING_KINDS = ['service', 'rental', 'unclassified'] as const;
export type OfferingKind = (typeof OFFERING_KINDS)[number];

export function parseOfferingKind(raw: unknown): OfferingKind | null {
  const v = String(raw ?? '').trim().toLowerCase();
  if (v === 'service' || v === 'rental' || v === 'unclassified') return v;
  return null;
}

export function parseBusinessCapabilityKey(raw: unknown): VendorBusinessCapabilityKey | null {
  const v = String(raw ?? '').trim().toUpperCase();
  if (v === 'SERVICE_PROVIDER' || v === 'RENTAL_PROVIDER') return v;
  return null;
}

export function normalizeTaxonomySlug(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
}

export const KNOWN_RENTAL_CATEGORY_SLUGS = [
  'rentals-equipment',
  'chairs',
  'tables',
  'canopies',
  'tents',
  'stage-platforms',
  'led-screens',
  'sound-systems',
  'lighting-systems',
  'generators',
  'mobile-toilets',
  'cooling-fans',
  'air-conditioners',
  'dance-floors',
  'cutlery-crockery',
  'thrones-vip-seating',
  'backdrops',
  'photo-booths',
  'event-equipment',
] as const;

export const DEFAULT_RESOURCE_SEEDS: Array<{ slug: string; label: string; description: string; sortOrder: number }> =
  [
    { slug: 'microphone', label: 'Microphone', description: 'Handheld or wireless microphone', sortOrder: 0 },
    { slug: 'speaker', label: 'Speaker', description: 'PA / event speaker', sortOrder: 1 },
    { slug: 'mixer', label: 'Mixer', description: 'Audio mixer', sortOrder: 2 },
    { slug: 'dj-controller', label: 'DJ Controller', description: 'DJ performance controller', sortOrder: 3 },
    { slug: 'keyboard', label: 'Keyboard', description: 'Musical keyboard', sortOrder: 4 },
    { slug: 'drum-set', label: 'Drum Set', description: 'Drum kit', sortOrder: 5 },
    { slug: 'lighting', label: 'Lighting', description: 'Event lighting fixture or kit', sortOrder: 6 },
    { slug: 'cable-kit', label: 'Cable Kit', description: 'Audio/power cable set', sortOrder: 7 },
  ];
