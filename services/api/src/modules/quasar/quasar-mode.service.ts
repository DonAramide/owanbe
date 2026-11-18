import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';
import { normalizeQuasarBaseUrl, quasarKeyEnvironment, type QuasarKeyEnvironment } from './quasar.policy';

@Injectable()
export class QuasarModeService implements OnModuleInit {
  constructor(private readonly config: ConfigService<EnvVars, true>) {}

  onModuleInit(): void {
    this.keyEnvironment();
    const secret = this.clientSecret();
    if (secret.startsWith('sk_live_')) {
      throw new Error('Quasar live keys are disabled');
    }
  }

  clientId(): string {
    return (this.config.get('QUASAR_CLIENT_ID', { infer: true }) ?? 'OWANBE').trim() || 'OWANBE';
  }

  clientSecret(): string {
    return (this.config.get('QUASAR_CLIENT_SECRET', { infer: true }) ?? '').trim();
  }

  serviceId(): string {
    return (this.config.get('QUASAR_SERVICE_ID', { infer: true }) ?? '').trim();
  }

  serviceSecret(): string {
    return (this.config.get('QUASAR_SERVICE_SECRET', { infer: true }) ?? '').trim();
  }

  baseUrl(): string {
    const configured = (this.config.get('QUASAR_BASE_URL', { infer: true }) ?? '').trim();
    const raw = configured || (this.clientSecret() ? 'http://localhost:4000/api/v1' : '');
    return normalizeQuasarBaseUrl(raw);
  }

  isConfigured(): boolean {
    return Boolean(this.baseUrl() && this.clientId() && this.clientSecret());
  }

  keyEnvironment(): QuasarKeyEnvironment {
    return quasarKeyEnvironment(
      this.config.get('QUASAR_ENVIRONMENT', { infer: true }),
      this.config.get('QUASAR_LIVE_ENABLED', { infer: true }),
    );
  }

  webhookUrlFor(quasarTenantId: string): string | null {
    const base = (this.config.get('PUBLIC_API_BASE_URL', { infer: true }) ?? '').trim().replace(/\/$/, '');
    if (!base) return null;
    return `${base}/webhooks/quasar/${quasarTenantId}`;
  }
}
