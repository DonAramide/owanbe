import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { GovernanceGuard } from '../src/common/guards/governance.guard';
import type { Pool } from 'pg';

function mockContext(headers: Record<string, string>): ExecutionContext {
  return {
    switchToHttp: () => ({
      getRequest: () => ({ headers }),
    }),
  } as ExecutionContext;
}

describe('GovernanceGuard Tests', () => {
  it('should allow active vendors without restrictions', async () => {
    const mockPool = {
      query: jest.fn().mockResolvedValue({
        rows: [{ state: 'open', risk_score: 'low' }],
      }),
    } as unknown as Pool;

    const guard = new GovernanceGuard(mockPool);
    const result = await guard.canActivate(mockContext({ 'x-vendor-id': 'active_v' }));
    expect(result).toBe(true);
  });

  it('should block suspended or blocked vendors with ForbiddenException', async () => {
    const mockPool = {
      query: jest.fn().mockResolvedValue({
        rows: [{ state: 'suspended', risk_score: 'high' }],
      }),
    } as unknown as Pool;

    const guard = new GovernanceGuard(mockPool);
    await expect(
      guard.canActivate(mockContext({ 'x-vendor-id': 'suspended_v' })),
    ).rejects.toThrow(ForbiddenException);
  });
});
