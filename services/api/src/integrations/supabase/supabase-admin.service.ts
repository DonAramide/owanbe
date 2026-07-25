import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';
import type { OwanbeRole } from '../../common/types/jwt-user';
import type { SignupPortal } from '../../modules/users/portal.util';

export interface SupabaseMetadataSyncInput {
  userId: string;
  tenantId: string;
  roles: OwanbeRole[];
  signupPortal?: SignupPortal | null;
  onboardingComplete?: boolean;
}

@Injectable()
export class SupabaseAdminService {
  private readonly logger = new Logger(SupabaseAdminService.name);

  constructor(private readonly config: ConfigService<EnvVars, true>) {}

  isConfigured(): boolean {
    return Boolean(
      this.config.get('SUPABASE_URL', { infer: true }).trim() &&
        this.config.get('SUPABASE_SERVICE_ROLE_KEY', { infer: true }).trim(),
    );
  }

  async syncUserAppMetadata(input: SupabaseMetadataSyncInput): Promise<void> {
    if (!this.isConfigured()) {
      this.logger.warn(
        'Supabase service role not configured — skipping app_metadata sync (DB remains authoritative)',
      );
      return;
    }

    const baseUrl = this.config.get('SUPABASE_URL', { infer: true }).replace(/\/$/, '');
    const serviceKey = this.config.get('SUPABASE_SERVICE_ROLE_KEY', { infer: true }).trim();
    const url = `${baseUrl}/auth/v1/admin/users/${encodeURIComponent(input.userId)}`;

    const appMetadata: Record<string, unknown> = {
      tenant_id: input.tenantId,
      roles: input.roles,
    };
    if (input.signupPortal != null) {
      appMetadata.signup_portal = input.signupPortal;
    }
    if (input.onboardingComplete != null) {
      appMetadata.onboarding_complete = input.onboardingComplete;
    }

    const res = await fetch(url, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${serviceKey}`,
        apikey: serviceKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ app_metadata: appMetadata }),
    });

    if (!res.ok) {
      const body = await res.text();
      this.logger.error(`Supabase app_metadata sync failed (${res.status}): ${body}`);
      throw new Error(`Supabase metadata sync failed: HTTP ${res.status}`);
    }
  }
}
