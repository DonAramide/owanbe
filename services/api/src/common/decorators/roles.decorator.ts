import { SetMetadata } from '@nestjs/common';
import type { OwanbeRole } from '../types/jwt-user';

export const ROLES_KEY = 'roles';

/** At least one of these roles required (admin bypasses in RolesGuard). */
export const Roles = (...roles: OwanbeRole[]) => SetMetadata(ROLES_KEY, roles);
