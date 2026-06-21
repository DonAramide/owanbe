/** Canonical permission codes — Phase 8 RBAC. */
export const PERMISSIONS = [
  'event.create',
  'event.publish',
  'event.close',
  'vendor.apply',
  'vendor.approve',
  'finance.view',
  'finance.refund',
  'finance.payout',
  'tenant.manage',
  'tenant.suspend',
] as const;

export type OwanbePermission = (typeof PERMISSIONS)[number];

/** Maps legacy DB role codes to Phase 8 role labels for reporting. */
export const ROLE_LABELS: Record<string, string> = {
  client: 'attendee',
  guest: 'attendee',
  vendor: 'vendor',
  vendor_pending: 'vendor',
  organizer: 'organizer',
  admin_super: 'platform_admin',
  admin_ops: 'platform_admin',
  admin_support: 'platform_admin',
  platform_admin: 'platform_admin',
  super_admin: 'super_admin',
};
