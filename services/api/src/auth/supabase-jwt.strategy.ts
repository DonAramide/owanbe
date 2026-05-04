import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import type { JwtUser } from '../common/types/jwt-user';
import type { EnvVars } from '../config/env.schema';
import { extractJwtRoleHints, extractTenantId } from './jwt-payload.util';

type JwtPayload = Record<string, unknown> & { sub?: string; email?: string };

@Injectable()
export class SupabaseJwtStrategy extends PassportStrategy(Strategy, 'supabase-jwt') {
  constructor(private readonly config: ConfigService<EnvVars, true>) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>('SUPABASE_JWT_SECRET'),
      algorithms: ['HS256'],
    });
  }

  validate(payload: JwtPayload): JwtUser {
    const sub = payload.sub;
    if (!sub || typeof sub !== 'string') {
      throw new UnauthorizedException({ code: 'INVALID_TOKEN', message: 'Missing sub' });
    }
    const tenantPath = this.config.get('JWT_TENANT_CLAIM_PATH', { infer: true });
    const rolesPath = this.config.get('JWT_ROLES_CLAIM_PATH', { infer: true });
    const tenantId = extractTenantId(payload, tenantPath);
    if (!tenantId) {
      throw new UnauthorizedException({
        code: 'INVALID_TOKEN',
        message: 'Missing tenant_id in JWT (configure app_metadata.tenant_id)',
      });
    }
    const jwtRoleHints = extractJwtRoleHints(payload, rolesPath);
    return {
      userId: sub,
      email: typeof payload.email === 'string' ? payload.email : undefined,
      tenantId,
      jwtRoleHints,
      roles: [],
    };
  }
}
