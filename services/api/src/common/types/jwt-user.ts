import type { UserLifecycleStatus } from './user-status';

/** Canonical role codes stored in `roles.code` (JWT hints are normalized to these). */
export type OwanbeRole =
  | 'super_admin'
  | 'admin_super'
  | 'admin_ops'
  | 'admin_support'
  | 'platform_admin'
  | 'organizer'
  | 'client'
  | 'vendor'
  | 'vendor_pending'
  | 'guest';

export interface JwtUser {
  /** Supabase `sub` — must match `users.id` in Postgres (provisioning contract). */
  userId: string;
  email?: string;
  /** Always from JWT claim (never from `X-Tenant-Id` alone). */
  tenantId: string;
  /** Normalized JWT role hints (coarse); authoritative list is `roles` after RolesGuard. */
  jwtRoleHints: OwanbeRole[];
  /** Populated by RolesGuard from DB after JWT∩DB validation. */
  roles: OwanbeRole[];
  /** Populated by PermissionsGuard when @RequirePermissions is used. */
  permissions?: string[];
  /** Populated by RolesGuard from `users.status`. */
  userStatus?: UserLifecycleStatus;
}
