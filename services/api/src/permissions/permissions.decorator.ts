import { SetMetadata } from '@nestjs/common';
import type { OwanbePermission } from './permissions.constants';

export const PERMISSIONS_KEY = 'permissions';

/** Require all listed permissions (AND). Super_admin bypasses in PermissionsGuard. */
export const RequirePermissions = (...permissions: OwanbePermission[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);
