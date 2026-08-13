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

export type SupabaseMfaFactor = {
  id: string;
  factorType: string;
  status: string;
  friendlyName?: string | null;
  createdAt?: string | null;
};

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

  private baseUrl(): string {
    return this.config.get('SUPABASE_URL', { infer: true }).replace(/\/$/, '');
  }

  private serviceKey(): string {
    return this.config.get('SUPABASE_SERVICE_ROLE_KEY', { infer: true }).trim();
  }

  private adminHeaders(): Record<string, string> {
    const key = this.serviceKey();
    return {
      Authorization: `Bearer ${key}`,
      apikey: key,
      'Content-Type': 'application/json',
    };
  }

  async syncUserAppMetadata(input: SupabaseMetadataSyncInput): Promise<void> {
    if (!this.isConfigured()) {
      this.logger.warn(
        'Supabase service role not configured — skipping app_metadata sync (DB remains authoritative)',
      );
      return;
    }

    const url = `${this.baseUrl()}/auth/v1/admin/users/${encodeURIComponent(input.userId)}`;

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
      headers: this.adminHeaders(),
      body: JSON.stringify({ app_metadata: appMetadata }),
    });

    if (!res.ok) {
      const body = await res.text();
      this.logger.error(`Supabase app_metadata sync failed (${res.status}): ${body}`);
      throw new Error(`Supabase metadata sync failed: HTTP ${res.status}`);
    }
  }

  /** Phase 29 — Auth Admin user fetch (factors / ban state). */
  async getAuthUser(userId: string): Promise<{
    available: boolean;
    reason?: string;
    user?: Record<string, unknown>;
  }> {
    if (!this.isConfigured()) {
      return { available: false, reason: 'SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not configured' };
    }
    const res = await fetch(
      `${this.baseUrl()}/auth/v1/admin/users/${encodeURIComponent(userId)}`,
      { headers: this.adminHeaders() },
    );
    if (!res.ok) {
      const body = await res.text();
      this.logger.warn(`Supabase getAuthUser failed (${res.status}): ${body}`);
      return { available: false, reason: `Supabase Auth Admin HTTP ${res.status}` };
    }
    const user = (await res.json()) as Record<string, unknown>;
    return { available: true, user };
  }

  async listMfaFactors(userId: string): Promise<{
    available: boolean;
    reason?: string;
    factors: SupabaseMfaFactor[];
  }> {
    const got = await this.getAuthUser(userId);
    if (!got.available || !got.user) {
      return { available: false, reason: got.reason, factors: [] };
    }
    const raw = (got.user.factors as unknown[]) ?? [];
    const factors: SupabaseMfaFactor[] = raw.map((f) => {
      const row = f as Record<string, unknown>;
      return {
        id: String(row.id ?? ''),
        factorType: String(row.factor_type ?? row.factorType ?? 'totp'),
        status: String(row.status ?? 'unverified'),
        friendlyName: (row.friendly_name ?? row.friendlyName ?? null) as string | null,
        createdAt: (row.created_at ?? row.createdAt ?? null) as string | null,
      };
    });
    return { available: true, factors };
  }

  async deleteMfaFactor(userId: string, factorId: string): Promise<{
    available: boolean;
    reason?: string;
    ok?: boolean;
  }> {
    if (!this.isConfigured()) {
      return { available: false, reason: 'SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not configured' };
    }
    const res = await fetch(
      `${this.baseUrl()}/auth/v1/admin/users/${encodeURIComponent(userId)}/factors/${encodeURIComponent(factorId)}`,
      { method: 'DELETE', headers: this.adminHeaders() },
    );
    if (!res.ok) {
      const body = await res.text();
      this.logger.warn(`Supabase deleteMfaFactor failed (${res.status}): ${body}`);
      return { available: false, reason: `Supabase Auth Admin HTTP ${res.status}` };
    }
    return { available: true, ok: true };
  }

  /**
   * Force global sign-out when Auth Admin supports it.
   * Returns Unavailable rather than inventing session rows.
   */
  async signOutUser(userId: string): Promise<{
    available: boolean;
    reason?: string;
    ok?: boolean;
  }> {
    if (!this.isConfigured()) {
      return { available: false, reason: 'SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not configured' };
    }
    const logoutUrl = `${this.baseUrl()}/auth/v1/admin/users/${encodeURIComponent(userId)}/logout`;
    const res = await fetch(logoutUrl, {
      method: 'POST',
      headers: this.adminHeaders(),
      body: JSON.stringify({ scope: 'global' }),
    });
    if (res.ok) {
      return { available: true, ok: true };
    }
    const banRes = await fetch(
      `${this.baseUrl()}/auth/v1/admin/users/${encodeURIComponent(userId)}`,
      {
        method: 'PUT',
        headers: this.adminHeaders(),
        body: JSON.stringify({ ban_duration: '1s' }),
      },
    );
    if (!banRes.ok) {
      const body = await banRes.text();
      this.logger.warn(`Supabase signOutUser failed (${res.status}/${banRes.status}): ${body}`);
      return {
        available: false,
        reason: `Session revoke Unavailable (Auth Admin HTTP ${res.status}/${banRes.status})`,
      };
    }
    await fetch(`${this.baseUrl()}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
      method: 'PUT',
      headers: this.adminHeaders(),
      body: JSON.stringify({ ban_duration: 'none' }),
    }).catch(() => undefined);
    return { available: true, ok: true };
  }
}
