import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../config/env.schema';

/** Central gate for production vs development integration behavior. */
@Injectable()
export class IntegrationsModeService {
  constructor(private readonly config: ConfigService<EnvVars, true>) {}

  isProduction(): boolean {
    return this.config.get('INTEGRATIONS_MODE', { infer: true }) === 'production';
  }

  isQuaserConfigured(): boolean {
    return Boolean(this.config.get('QUASER_ROUTER_BASE_URL', { infer: true }).trim());
  }

  /** Dev auto-capture / auto-complete only when not in production mode. */
  allowPaymentStubs(): boolean {
    return !this.isProduction() && !this.isQuaserConfigured();
  }

  requireProductionConfig(): void {
    if (!this.isProduction()) return;
    if (!this.isQuaserConfigured()) {
      throw new Error('INTEGRATIONS_MODE=production requires QUASER_ROUTER_BASE_URL');
    }
    if (!this.config.get('PUBLIC_API_BASE_URL', { infer: true }).trim()) {
      throw new Error('INTEGRATIONS_MODE=production requires PUBLIC_API_BASE_URL');
    }
  }
}
