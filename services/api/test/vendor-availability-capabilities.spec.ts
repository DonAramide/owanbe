import {
  classifyDateAvailability,
  clipRange,
  rangeFullyCovers,
  rangesOverlap,
  resolveEventWindow,
} from '../src/modules/vendor-operations/vendor-availability.util';
import {
  allowedCapabilitySet,
  categoryMatchesService,
  parseAdminCapabilities,
  parseSelectedCapabilities,
  parseVendorCapabilities,
  publicMarketplaceCapabilities,
  validateSelectedCapabilities,
} from '../src/modules/vendor-operations/vendor-capability.util';
import {
  parseVendorCustomExtras,
  publicVendorCustomExtras,
} from '../src/modules/vendor-operations/vendor-custom-extras.util';
import { VENDOR_CATEGORY_ADMIN_ROLES } from '../src/common/permission-matrix';

describe('vendor availability windows', () => {
  const d = (iso: string) => new Date(iso);

  it('treats null ends_at as a 24h single-day window', () => {
    const w = resolveEventWindow(d('2026-08-22T10:00:00.000Z'), null);
    expect(w.end.getTime() - w.start.getTime()).toBe(24 * 60 * 60 * 1000);
  });

  it('detects overlap with standard range logic', () => {
    expect(
      rangesOverlap(
        d('2026-08-22T00:00:00.000Z'),
        d('2026-08-23T00:00:00.000Z'),
        d('2026-08-21T00:00:00.000Z'),
        d('2026-08-24T00:00:00.000Z'),
      ),
    ).toBe(true);
    expect(
      rangesOverlap(
        d('2026-08-25T00:00:00.000Z'),
        d('2026-08-26T00:00:00.000Z'),
        d('2026-08-21T00:00:00.000Z'),
        d('2026-08-24T00:00:00.000Z'),
      ),
    ).toBe(false);
  });

  it('classifies full cover as BOOKED and partial as CONFLICTING', () => {
    const organizer = {
      start: d('2026-08-22T00:00:00.000Z'),
      end: d('2026-08-23T00:00:00.000Z'),
    };
    expect(
      classifyDateAvailability(organizer, [
        { start: d('2026-08-21T00:00:00.000Z'), end: d('2026-08-24T00:00:00.000Z') },
      ]),
    ).toBe('BOOKED');
    expect(
      classifyDateAvailability(organizer, [
        { start: d('2026-08-22T12:00:00.000Z'), end: d('2026-08-24T00:00:00.000Z') },
      ]),
    ).toBe('CONFLICTING');
    expect(classifyDateAvailability(organizer, [])).toBe('AVAILABLE');
  });

  it('clips overlay windows to the query range without expanding them', () => {
    const clipped = clipRange(
      { start: d('2026-08-19T00:00:00.000Z'), end: d('2026-08-19T23:00:00.000Z') },
      { start: d('2026-08-01T00:00:00.000Z'), end: d('2026-11-01T00:00:00.000Z') },
    );
    expect(clipped?.start.toISOString()).toBe('2026-08-19T00:00:00.000Z');
    expect(clipped?.end.toISOString()).toBe('2026-08-19T23:00:00.000Z');
    expect(
      clipRange(
        { start: d('2026-07-01T00:00:00.000Z'), end: d('2026-07-02T00:00:00.000Z') },
        { start: d('2026-08-01T00:00:00.000Z'), end: d('2026-09-01T00:00:00.000Z') },
      ),
    ).toBeNull();
  });

  it('does not treat adjacent ranges as overlap', () => {
    expect(
      rangeFullyCovers(
        { start: d('2026-08-21T00:00:00.000Z'), end: d('2026-08-22T00:00:00.000Z') },
        { start: d('2026-08-22T00:00:00.000Z'), end: d('2026-08-23T00:00:00.000Z') },
      ),
    ).toBe(false);
  });
});

describe('vendor capabilities', () => {
  it('parses admin catalogue and ignores disabled keys in allowed set', () => {
    const admin = parseAdminCapabilities({
      capabilities: [
        { key: 'Sound System', label: 'Sound System', enabled: true },
        { key: 'lighting', label: 'Lighting', enabled: false },
      ],
    });
    const vendor = parseVendorCapabilities([
      { key: 'sound_system', label: 'Sound System', provided: true },
      { key: 'lighting', label: 'Lighting', provided: true },
    ]);
    const allowed = allowedCapabilitySet(admin, vendor);
    expect([...allowed.keys()]).toEqual(['sound_system']);
  });

  it('rejects organizer selections the vendor does not provide', () => {
    const allowed = new Map([['sound_system', 'Sound System']]);
    const result = validateSelectedCapabilities(
      parseSelectedCapabilities([{ key: 'lighting', label: 'Lighting' }]),
      allowed,
    );
    expect(result.ok).toBe(false);
  });

  it('matches photographer category to photography service names', () => {
    expect(categoryMatchesService('photographer', 'Photographer', 'photography', 'Photography')).toBe(
      true,
    );
    expect(categoryMatchesService('dj', 'DJ', 'dj', 'DJ')).toBe(true);
    expect(categoryMatchesService('dj', 'DJ', 'catering', 'Catering')).toBe(false);
  });
  it('builds public marketplace capabilities as admin-enabled ∩ vendor-provided', () => {
    const admin = parseAdminCapabilities({
      capabilities: [
        { key: 'sound_system', label: 'Sound System', enabled: true, tier: 'core' },
        { key: 'lighting', label: 'Lighting', enabled: false, tier: 'optional' },
      ],
    });
    const vendor = parseVendorCapabilities([
      { key: 'sound_system', label: 'Sound System', provided: true },
      { key: 'lighting', label: 'Lighting', provided: true },
    ]);
    expect(publicMarketplaceCapabilities(admin, vendor)).toEqual([
      { key: 'sound_system', label: 'Sound System' },
    ]);
  });

  it('parses admin tier core vs optional (defaults to core)', () => {
    const admin = parseAdminCapabilities({
      capabilities: [
        { key: 'sound_system', label: 'Sound System', enabled: true },
        { key: 'stage', label: 'Stage', enabled: true, tier: 'optional' },
      ],
    });
    expect(admin.find((c) => c.key === 'sound_system')?.tier).toBe('core');
    expect(admin.find((c) => c.key === 'stage')?.tier).toBe('optional');
  });
});

describe('vendor custom extras (deprecated path)', () => {
  it('parser still exists for unused column but is not part of marketplace model', () => {
    const all = parseVendorCustomExtras([
      { id: 'e1', name: 'Karaoke', active: true, isPublic: true, priceMinor: 5000000 },
    ]);
    expect(all).toHaveLength(1);
    expect(publicVendorCustomExtras(all)).toHaveLength(1);
  });
});

describe('vendor category admin RBAC', () => {
  it('allows Control Tower super_admin and existing admin tiers only', () => {
    expect(VENDOR_CATEGORY_ADMIN_ROLES).toEqual(
      expect.arrayContaining(['super_admin', 'admin_super', 'admin_ops', 'admin_support']),
    );
    expect(VENDOR_CATEGORY_ADMIN_ROLES).not.toContain('vendor');
    expect(VENDOR_CATEGORY_ADMIN_ROLES).not.toContain('client');
    expect(VENDOR_CATEGORY_ADMIN_ROLES).not.toContain('organizer');
  });
});
