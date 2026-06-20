import {
  BadRequestException,
  createParamDecorator,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Request } from 'express';
import type { Pool } from 'pg';
import { Inject } from '@nestjs/common';
import { PG_POOL } from '../../database/database.tokens';
import type { EnvVars } from '../../config/env.schema';
import type { JwtUser } from '../../common/types/jwt-user';
import { randomUUID } from 'crypto';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export interface CommerceActor {
  userId: string;
  email?: string;
  tenantId: string;
}

@Injectable()
export class CommerceAuthService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
  ) {}

  devCommerceAllowed(): boolean {
    return (
      this.config.get('NODE_ENV', { infer: true }) !== 'production' &&
      this.config.get('ALLOW_DEV_COMMERCE_AUTH', { infer: true }) === true
    );
  }

  async resolveActor(req: Request, jwtUser?: JwtUser): Promise<CommerceActor> {
    const tenantHeader = req.headers['x-tenant-id'];
    const tenantId = typeof tenantHeader === 'string' ? tenantHeader.trim() : jwtUser?.tenantId;
    if (!tenantId || !UUID_RE.test(tenantId)) {
      throw new BadRequestException({ code: 'TENANT_REQUIRED', message: 'X-Tenant-Id required' });
    }

    if (jwtUser?.userId) {
      return { userId: jwtUser.userId, email: jwtUser.email, tenantId };
    }

    if (!this.devCommerceAllowed()) {
      throw new UnauthorizedException({ code: 'AUTH_REQUIRED', message: 'Sign in required' });
    }

    const devUser = req.headers['x-dev-user-id'];
    const devEmail = req.headers['x-dev-user-email'];
    const externalId = typeof devUser === 'string' ? devUser.trim() : '';
    const email =
      typeof devEmail === 'string' && devEmail.includes('@')
        ? devEmail.trim().toLowerCase()
        : externalId.includes('@')
          ? externalId.toLowerCase()
          : `${externalId || 'guest'}@dev.owanbe.local`;

    const userId = await this.ensureDevUser(tenantId, email, externalId || email);
    return { userId, email, tenantId };
  }

  /** Map dev attendee id to a stable UUID user row. */
  private async ensureDevUser(tenantId: string, email: string, label: string): Promise<string> {
    if (UUID_RE.test(label)) {
      const byId = await this.pool.query<{ id: string }>(
        `SELECT id FROM users WHERE tenant_id = $1 AND id = $2::uuid LIMIT 1`,
        [tenantId, label],
      );
      if (byId.rows[0]) {
        return byId.rows[0].id;
      }
    }

    const existing = await this.pool.query<{ id: string }>(
      `SELECT id FROM users WHERE tenant_id = $1 AND email_normalized = lower(trim($2)) LIMIT 1`,
      [tenantId, email],
    );
    if (existing.rows[0]) {
      return existing.rows[0].id;
    }

    const id = randomUUID();
    await this.pool.query(
      `INSERT INTO users (id, tenant_id, email, display_name, status)
       VALUES ($1, $2, $3, $4, 'active')
       ON CONFLICT DO NOTHING`,
      [id, tenantId, email, label.slice(0, 80)],
    );
    const again = await this.pool.query<{ id: string }>(
      `SELECT id FROM users WHERE tenant_id = $1 AND email_normalized = lower(trim($2)) LIMIT 1`,
      [tenantId, email],
    );
    const row = again.rows[0];
    if (!row) {
      throw new BadRequestException({ code: 'USER_BOOTSTRAP_FAILED', message: 'Could not create dev user' });
    }
    return row.id;
  }
}

export const CommerceActorParam = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): CommerceActor | undefined => {
    const req = ctx.switchToHttp().getRequest<Request & { commerceActor?: CommerceActor }>();
    return req.commerceActor;
  },
);
