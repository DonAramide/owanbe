import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';
import { EmailSecretsCrypto } from './email-secrets.crypto';
import { EmailService } from './email.service';

export interface SupabaseSyncResult {
  ok: boolean;
  reason?: string;
  syncedProviderId?: string;
  httpStatus?: number;
  errorCode?: string;
  recommendedAction?: string;
}

/**
 * Optional sync of the default Enterprise Email provider into Supabase Auth SMTP
 * via the Supabase Management API.
 */
@Injectable()
export class SupabaseSmtpSyncService {
  private readonly logger = new Logger(SupabaseSmtpSyncService.name);

  constructor(
    private readonly config: ConfigService<EnvVars, true>,
    private readonly email: EmailService,
    private readonly crypto: EmailSecretsCrypto,
  ) {}

  isConfigured(): boolean {
    return Boolean(this.accessToken() && this.projectRef());
  }

  async syncDefaultProvider(providerId?: string): Promise<SupabaseSyncResult> {
    if (!this.isConfigured()) {
      return {
        ok: false,
        errorCode: 'SUPABASE_PAT_MISSING',
        reason:
          'SUPABASE_ACCESS_TOKEN is not configured on the API. Sync to Supabase Auth is disabled until an Owner/Administrator personal access token is set.',
        recommendedAction:
          'Create a PAT at https://supabase.com/dashboard/account/tokens (Owner/Admin), set SUPABASE_ACCESS_TOKEN and SUPABASE_PROJECT_REF (or SUPABASE_URL) on the API, restart, then retry. Or configure Auth SMTP manually in the Supabase Dashboard.',
      };
    }

    const readiness = await this.email.getReadiness();
    if (!readiness.ready) {
      return {
        ok: false,
        errorCode: 'EMAIL_INFRASTRUCTURE_NOT_READY',
        reason: readiness.blockers.join('; '),
        recommendedAction:
          'Configure and enable a default SMTP provider with a decryptable password in Super Admin → Enterprise Email, then retry sync.',
      };
    }

    const provider = providerId
      ? await this.email.getRow(providerId)
      : await this.email.resolveActiveProvider();

    if (!provider) {
      return {
        ok: false,
        errorCode: 'NO_PROVIDER',
        reason: 'No email provider to sync',
        recommendedAction: 'Add and enable a default SMTP provider first.',
      };
    }

    if (!provider.smtp_host || !provider.username || !provider.password_ciphertext) {
      return {
        ok: false,
        errorCode: 'PROVIDER_NOT_SMTP',
        reason:
          'Supabase Auth SMTP sync requires an SMTP-style provider with host, username, and password. API-key providers (SendGrid/Resend) cannot be pushed as Auth SMTP.',
        recommendedAction:
          'Use a Zoho/Generic SMTP provider as default, or configure Auth SMTP manually in the Supabase Dashboard.',
        syncedProviderId: provider.id,
      };
    }

    let password: string;
    try {
      password = this.crypto.decrypt(provider.password_ciphertext);
    } catch (e) {
      return {
        ok: false,
        errorCode: 'SECRET_DECRYPT_FAILED',
        reason: e instanceof Error ? e.message : 'Failed to decrypt SMTP password',
        recommendedAction:
          'Re-save the provider password in Super Admin (ciphertext may have been encrypted with a different EMAIL_SECRETS_ENCRYPTION_KEY).',
        syncedProviderId: provider.id,
      };
    }

    const body = {
      external_email_enabled: true,
      mailer_secure_email_change_enabled: true,
      mailer_autoconfirm: false,
      smtp_admin_email: provider.sender_email,
      smtp_host: provider.smtp_host,
      smtp_port: String(provider.smtp_port ?? 587),
      smtp_user: provider.username,
      smtp_pass: password,
      smtp_sender_name: provider.sender_name,
    };

    const url = `https://api.supabase.com/v1/projects/${this.projectRef()}/config/auth`;
    try {
      const res = await fetch(url, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${this.accessToken()}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        const text = await res.text().catch(() => '');
        let parsed: { message?: string; error?: string; error_code?: string } = {};
        try {
          parsed = JSON.parse(text) as typeof parsed;
        } catch {
          /* raw text */
        }
        const reason =
          parsed.message || parsed.error || text || res.statusText || `HTTP ${res.status}`;
        this.logger.warn({ status: res.status, reason }, 'Supabase SMTP sync failed');
        return {
          ok: false,
          httpStatus: res.status,
          errorCode: parsed.error_code || `HTTP_${res.status}`,
          reason,
          syncedProviderId: provider.id,
          recommendedAction: this.recommendForHttpStatus(res.status),
        };
      }
      this.logger.log({ providerId: provider.id }, 'Synced SMTP to Supabase Auth');
      return { ok: true, syncedProviderId: provider.id, httpStatus: res.status };
    } catch (e) {
      return {
        ok: false,
        errorCode: 'NETWORK_ERROR',
        reason: e instanceof Error ? e.message : 'supabase_sync_failed',
        syncedProviderId: provider.id,
        recommendedAction: 'Check network connectivity to api.supabase.com and retry.',
      };
    }
  }

  describeLimitation(): string {
    return [
      'Supabase Auth emails (signup verification, password reset, magic link, email change)',
      'are sent by Supabase Auth GoTrue, not by the Nest EmailService.',
      'SMTP for Auth can be set in the Dashboard OR synced via Management API',
      '(PATCH /v1/projects/{ref}/config/auth) when SUPABASE_ACCESS_TOKEN + SUPABASE_PROJECT_REF are set.',
      'Requires Owner/Administrator PAT. Developer role may receive HTTP 403.',
      'After custom SMTP, raise Auth rate limits in the Dashboard (default remains restrictive).',
    ].join(' ');
  }

  private recommendForHttpStatus(status: number): string {
    if (status === 401 || status === 403) {
      return 'Use an Owner or Administrator personal access token. Developer-role PATs often return 403 on PATCH /config/auth.';
    }
    if (status === 404) {
      return 'Verify SUPABASE_PROJECT_REF matches your project (or SUPABASE_URL host).';
    }
    if (status === 429) {
      return 'Management API rate limited — wait and retry.';
    }
    return 'Inspect the Management API error reason above, fix credentials/project ref, then retry. Or set Auth SMTP in the Dashboard.';
  }

  private accessToken(): string {
    return (this.config.get('SUPABASE_ACCESS_TOKEN', { infer: true }) ?? '').trim();
  }

  private projectRef(): string {
    const explicit = (this.config.get('SUPABASE_PROJECT_REF', { infer: true }) ?? '').trim();
    if (explicit) return explicit;
    const url = (this.config.get('SUPABASE_URL', { infer: true }) ?? '').trim();
    const m = url.match(/https?:\/\/([a-z0-9-]+)\.supabase\.co/i);
    return m?.[1] ?? '';
  }
}
