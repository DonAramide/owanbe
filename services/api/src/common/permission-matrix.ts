import type { OwanbeRole } from './types/jwt-user';

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

export const VENDOR_FINANCE_VIEW_ROLES: OwanbeRole[] = ['vendor', 'vendor_pending', ...ADMIN_TIERS];

export const DISPUTE_CREATE_ROLES: OwanbeRole[] = ['client'];
export const DISPUTE_PARTICIPANT_ROLES: OwanbeRole[] = ['client', 'vendor', ...ADMIN_TIERS];
export const ADMIN_DISPUTE_ROLES: OwanbeRole[] = ['admin_super', 'admin_ops'];
