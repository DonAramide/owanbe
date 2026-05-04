import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/** Skip JWT auth (still may require `X-Tenant-Id` for catalog scoping). */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
