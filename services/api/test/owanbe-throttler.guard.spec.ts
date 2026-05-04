import { OwanbeThrottlerGuard } from '../src/common/guards/owanbe-throttler.guard';
import type { JwtUser } from '../src/common/types/jwt-user';

describe('OwanbeThrottlerGuard getTracker', () => {
  it('prefixes with JWT tenant when authenticated', async () => {
    const fn = OwanbeThrottlerGuard.prototype['getTracker'] as (
      this: unknown,
      req: Record<string, unknown>,
    ) => Promise<string>;
    const user: JwtUser = {
      userId: 'u',
      tenantId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      jwtRoleHints: [],
      roles: [],
    };
    const tracker = await fn.call({}, { user, ip: '10.0.0.1' });
    expect(tracker).toContain('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    expect(tracker).toContain('10.0.0.1');
  });

  it('uses catalog tenant when anonymous', async () => {
    const fn = OwanbeThrottlerGuard.prototype['getTracker'] as (
      this: unknown,
      req: Record<string, unknown>,
    ) => Promise<string>;
    const tracker = await fn.call(
      {},
      {
        catalogTenantId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        ip: '10.0.0.2',
      },
    );
    expect(tracker).toContain('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
  });
});
