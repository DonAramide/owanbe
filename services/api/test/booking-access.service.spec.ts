import { NotFoundException } from '@nestjs/common';
import { BookingAccessService } from '../src/ownership/booking-access.service';
import type { JwtUser } from '../src/common/types/jwt-user';

describe('BookingAccessService ownership', () => {
  const audit = { logRead: jest.fn() };

  it('returns 404 when client accesses another users booking', async () => {
    const pool = {
      query: jest.fn().mockResolvedValue({
        rows: [{ client_user_id: 'other-client', vendor_id: 'v1' }],
      }),
    };
    const svc = new BookingAccessService(pool as never, audit as never);
    const user: JwtUser = {
      userId: 'me',
      tenantId: 't1',
      jwtRoleHints: [],
      roles: ['client'],
    };
    await expect(svc.assertCanReadBooking('t1', 'b1', user)).rejects.toThrow(NotFoundException);
  });
});
