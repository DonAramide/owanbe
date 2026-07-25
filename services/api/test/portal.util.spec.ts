import {
  parseSignupPortal,
  portalFromRoles,
  resolveSignupPortalForMetadata,
} from '../src/modules/users/portal.util';

describe('portal.util', () => {
  describe('parseSignupPortal', () => {
    it('accepts valid portal codes', () => {
      expect(parseSignupPortal('organizer')).toBe('organizer');
      expect(parseSignupPortal('CLIENT')).toBe('client');
    });

    it('rejects invalid values', () => {
      expect(parseSignupPortal('sponsor')).toBeNull();
      expect(parseSignupPortal('')).toBeNull();
      expect(parseSignupPortal(null)).toBeNull();
    });
  });

  describe('resolveSignupPortalForMetadata', () => {
    it('prefers stored portal over role derivation', () => {
      expect(resolveSignupPortalForMetadata('vendor', ['client'])).toBe('vendor');
    });

    it('derives from roles when stored portal is null', () => {
      expect(resolveSignupPortalForMetadata(null, ['organizer'])).toBe('organizer');
      expect(portalFromRoles(['organizer'])).toBe('organizer');
    });
  });
});
