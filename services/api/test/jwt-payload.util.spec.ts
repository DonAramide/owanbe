import { extractJwtRoleHints, normalizeJwtRoleCode } from '../src/auth/jwt-payload.util';

describe('jwt-payload.util', () => {
  it('maps legacy admin JWT hint to admin_super', () => {
    expect(normalizeJwtRoleCode('admin')).toBe('admin_super');
  });

  it('extracts hints from nested app_metadata.roles', () => {
    const payload = {
      app_metadata: {
        roles: ['admin', 'client'],
      },
    };
    const hints = extractJwtRoleHints(payload, 'app_metadata.roles');
    expect(hints).toEqual(['admin_super', 'client']);
  });
});
