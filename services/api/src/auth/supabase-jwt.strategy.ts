import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import jwksRsa from 'jwks-rsa';
import type { JwtUser } from '../common/types/jwt-user';
import type { EnvVars } from '../config/env.schema';
import { extractJwtRoleHints, extractTenantId } from './jwt-payload.util';

type JwtPayload = Record<string, unknown> & { sub?: string; email?: string };

function decodeJwtHeader(token: string): { alg?: string; kid?: string } {
  const [headerB64] = token.split('.');
  if (!headerB64) return {};
  const json = Buffer.from(headerB64, 'base64url').toString('utf8');
  return JSON.parse(json) as { alg?: string; kid?: string };
}

@Injectable()
export class SupabaseJwtStrategy extends PassportStrategy(Strategy, 'supabase-jwt') {
  constructor(private readonly config: ConfigService<EnvVars, true>) {
    const secret = config.getOrThrow<string>('SUPABASE_JWT_SECRET');
    const supabaseUrl = config.get('SUPABASE_URL', { infer: true })?.trim();

    const jwksProvider =
      supabaseUrl.length > 0
        ? jwksRsa.passportJwtSecret({
            cache: true,
            rateLimit: true,
            jwksRequestsPerMinute: 10,
            jwksUri: `${supabaseUrl.replace(/\/$/, '')}/auth/v1/.well-known/jwks.json`,
          })
        : null;

    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKeyProvider: (
        _request: unknown,
        rawJwtToken: string,
        done: (err: Error | null, secretOrKey?: string | Buffer) => void,
      ) => {
        try {
          const header = decodeJwtHeader(rawJwtToken);
          if (header.alg === 'HS256' || !header.kid) {
            return done(null, secret);
          }
          if (jwksProvider && (header.alg === 'ES256' || header.kid)) {
            return jwksProvider(_request as never, rawJwtToken, done);
          }
          return done(null, secret);
        } catch (err) {
          return done(err instanceof Error ? err : new Error(String(err)));
        }
      },
      algorithms: ['HS256', 'ES256'],
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
