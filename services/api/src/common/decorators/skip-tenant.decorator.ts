import { SetMetadata } from '@nestjs/common';

export const SKIP_TENANT_KEY = 'skipTenant';

/** Skip `X-Tenant-Id` requirement (use only for infra health checks). */
export const SkipTenant = () => SetMetadata(SKIP_TENANT_KEY, true);
