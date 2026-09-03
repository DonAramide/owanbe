import {
  normalizeTaxonomySlug,
  parseBusinessCapabilityKey,
  parseOfferingKind,
} from '../src/modules/event-config/vendor-taxonomy.util';
import { VENDOR_CATEGORY_ADMIN_ROLES } from '../src/common/permission-matrix';

describe('vendor taxonomy utils', () => {
  it('normalizes slugs for admin-created categories and resources', () => {
    expect(normalizeTaxonomySlug('DJ Equipment')).toBe('dj-equipment');
    expect(normalizeTaxonomySlug('  Cable Kit!! ')).toBe('cable-kit');
    expect(normalizeTaxonomySlug('Microphone')).toBe('microphone');
  });

  it('accepts only SERVICE_PROVIDER and RENTAL_PROVIDER keys', () => {
    expect(parseBusinessCapabilityKey('SERVICE_PROVIDER')).toBe('SERVICE_PROVIDER');
    expect(parseBusinessCapabilityKey('rental_provider')).toBe('RENTAL_PROVIDER');
    expect(parseBusinessCapabilityKey('VENDOR_BUYER')).toBeNull();
  });

  it('parses offering kinds without inventing a unified booking type', () => {
    expect(parseOfferingKind('service')).toBe('service');
    expect(parseOfferingKind('RENTAL')).toBe('rental');
    expect(parseOfferingKind('product')).toBeNull();
  });

  it('keeps vendor category admin roles on existing Control Tower roles', () => {
    expect(VENDOR_CATEGORY_ADMIN_ROLES).toContain('super_admin');
    expect(VENDOR_CATEGORY_ADMIN_ROLES).toContain('admin_super');
  });
});
