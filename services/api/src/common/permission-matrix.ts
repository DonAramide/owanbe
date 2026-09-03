import type { OwanbeRole } from './types/jwt-user';

/** Owanbe control tower — cross-tenant platform operator. */
export const SUPER_ADMIN_ROLES: OwanbeRole[] = ['super_admin'];

/** Any admin tier (queue / read-heavy endpoints). */
export const ADMIN_TIERS: OwanbeRole[] = ['admin_super', 'admin_ops', 'admin_support'];

/** Destructive / approval onboarding actions — super only for now. */
export const ADMIN_APPROVERS: OwanbeRole[] = ['admin_super'];

/** Vendor profile creation (pre-approval). */
export const VENDOR_CREATE_ROLES: OwanbeRole[] = [
  'admin_super',
  'admin_ops',
  'admin_support',
  'client',
  'vendor',
  'vendor_pending',
];

/** Vendor onboarding write paths (owner while pending or active). */
export const VENDOR_ONBOARDING_WRITE: OwanbeRole[] = [
  'vendor',
  'vendor_pending',
  ...ADMIN_TIERS,
];

export const BOOKING_READ_ROLES: OwanbeRole[] = [
  ...ADMIN_TIERS,
  'client',
  'vendor',
  'vendor_pending',
];

/** Create payment intent for a booking (client owner only at controller). */
export const CLIENT_PAYMENT_CREATE_ROLES: OwanbeRole[] = ['client'];

/** List payments / payouts, run finance jobs. */
export const ADMIN_FINANCE_ROLES: OwanbeRole[] = [...ADMIN_TIERS];
/** Strict finance control surface (power actions + dashboards). */
export const ADMIN_FINANCE_CONTROL_ROLES: OwanbeRole[] = ['admin_super', 'admin_ops'];

/**
 * Vendor pricing rules CRUD — Control Tower operators + finance admins.
 * Includes `super_admin` so Control Tower can manage its own commerce config
 * without broadening all ADMIN_FINANCE_CONTROL_ROLES endpoints.
 */
export const VENDOR_PRICING_ADMIN_ROLES: OwanbeRole[] = [
  'super_admin',
  'admin_super',
  'admin_ops',
];

/**
 * Vendor service-category capability catalogue (Control Tower Service Categories).
 * Adds `super_admin` without dropping existing ADMIN_TIERS (includes admin_support).
 * Does not broaden pricing, finance, or public catalog access.
 */
export const VENDOR_CATEGORY_ADMIN_ROLES: OwanbeRole[] = ['super_admin', ...ADMIN_TIERS];

export const VENDOR_FINANCE_VIEW_ROLES: OwanbeRole[] = ['vendor', 'vendor_pending', ...ADMIN_TIERS];

export const DISPUTE_CREATE_ROLES: OwanbeRole[] = ['client'];
export const DISPUTE_PARTICIPANT_ROLES: OwanbeRole[] = ['client', 'vendor', ...ADMIN_TIERS];
export const ADMIN_DISPUTE_ROLES: OwanbeRole[] = ['admin_super', 'admin_ops'];
