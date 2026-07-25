import type { OwanbeRole } from '../../common/types/jwt-user';

export type SignupPortal = 'client' | 'organizer' | 'vendor' | 'admin';

const SIGNUP_PORTAL_VALUES: ReadonlySet<SignupPortal> = new Set([
  'client',
  'organizer',
  'vendor',
  'admin',
]);

/** Validates a DB/JWT string as a legacy signup portal code. */
export function parseSignupPortal(value: string | null | undefined): SignupPortal | null {
  if (value == null) return null;
  const normalized = value.trim().toLowerCase();
  return SIGNUP_PORTAL_VALUES.has(normalized as SignupPortal)
    ? (normalized as SignupPortal)
    : null;
}

/** Authoritative portal for metadata sync: stored value, else derived from roles. */
export function resolveSignupPortalForMetadata(
  storedPortal: string | null | undefined,
  roles: OwanbeRole[],
): SignupPortal | null {
  return parseSignupPortal(storedPortal) ?? portalFromRoles(roles);
}

const ADMIN_ROLE_CODES: ReadonlySet<OwanbeRole> = new Set([
  'super_admin',
  'admin_super',
  'admin_ops',
  'admin_support',
  'platform_admin',
]);

export function portalToPrimaryRole(portal: SignupPortal): OwanbeRole {
  switch (portal) {
    case 'client':
      return 'client';
    case 'organizer':
      return 'organizer';
    case 'vendor':
      return 'vendor';
    case 'admin':
      return 'platform_admin';
    default:
      return 'client';
  }
}

export function portalFromRoles(roles: OwanbeRole[]): SignupPortal | null {
  if (roles.some((r) => ADMIN_ROLE_CODES.has(r))) return 'admin';
  if (roles.includes('organizer')) return 'organizer';
  if (roles.includes('vendor') || roles.includes('vendor_pending')) return 'vendor';
  if (roles.includes('client')) return 'client';
  return null;
}

export function rolesMatchPortal(roles: OwanbeRole[], portal: SignupPortal): boolean {
  const derived = portalFromRoles(roles);
  if (derived == null) return false;
  return derived === portal;
}

export function isAdminPortalRole(role: OwanbeRole): boolean {
  return ADMIN_ROLE_CODES.has(role);
}

export function onboardingCompleteForPortal(portal: SignupPortal): boolean {
  return portal === 'admin';
}
