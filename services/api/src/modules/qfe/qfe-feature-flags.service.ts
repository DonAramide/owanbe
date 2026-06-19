import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvVars } from '../../config/env.schema';

@Injectable()
export class QfeFeatureFlagsService {
  constructor(private readonly config: ConfigService<EnvVars, true>) {}

  /** When true, treasury settlement journals also write financial_transactions + postings. */
  isTreasuryDualWriteEnabled(): boolean {
    return this.config.get('QFE_DUAL_WRITE_TREASURY', { infer: true });
  }
}
