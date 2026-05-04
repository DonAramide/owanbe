import type { OwanbeRole } from '../types/jwt-user';

const ADMIN_CODES: ReadonlySet<OwanbeRole> = new Set([
  'admin_super',
  'admin_ops',
  'admin_support',
]);

export function isAdminRole(code: string): code is OwanbeRole {
  return ADMIN_CODES.has(code as OwanbeRole);
}

export function hasAnyAdminRole(roles: readonly string[]): boolean {
  return roles.some((r) => isAdminRole(r));
}

/** Vendor marketplace role (excludes vendor_pending). */
export function isFullVendorRole(code: string): boolean {
  return code === 'vendor';
}

export function canActAsVendorStaff(roles: readonly string[]): boolean {
  return roles.some((r) => r === 'vendor' || r === 'vendor_pending');
}
