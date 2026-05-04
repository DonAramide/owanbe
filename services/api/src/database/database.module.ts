import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool } from 'pg';
import { PG_POOL } from './database.tokens';
import type { EnvVars } from '../config/env.schema';

@Global()
@Module({
  providers: [
    {
      provide: PG_POOL,
      inject: [ConfigService],
      useFactory: (config: ConfigService<EnvVars, true>) => {
        return new Pool({
          connectionString: config.getOrThrow<string>('DATABASE_URL'),
          max: 10,
          idleTimeoutMillis: 30_000,
        });
      },
    },
  ],
  exports: [PG_POOL],
})
export class DatabaseModule {}
