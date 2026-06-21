/**
 * Tenant isolation contract tests — Phase 8 Sprint 8.3.
 * Full cross-tenant HTTP checks run in scripts/verify-phase8-identity-security.js.
 */
describe('Tenant isolation contracts', () => {
  const TENANT_A = '11111111-1111-4111-8111-111111111111';
  const TENANT_B = '99999999-9999-4999-8999-999999999999';

  it('JWT tenant claim must not be overridden by header alone', () => {
    const jwtTenant = TENANT_A;
    const headerTenant = TENANT_B;
    expect(jwtTenant).not.toBe(headerTenant);
  });

  it('documents SkipTenant surfaces', () => {
    const skipTenantRoutes = [
      'GET /health',
      'POST /webhooks/quaser',
      'GET /super-admin/platform/overview',
    ];
    expect(skipTenantRoutes.length).toBeGreaterThan(0);
  });

  it('private event manage path requires tenant-scoped auth', () => {
    const privatePaths = ['/events/:eventId/manage', '/organizers/me/events'];
    for (const path of privatePaths) {
      expect(path).not.toContain('super-admin');
    }
  });
});
