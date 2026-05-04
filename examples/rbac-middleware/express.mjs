/**
 * Express RBAC sketch — Owanbe
 * - Assumes upstream auth middleware sets req.user = { sub, tenantId, roles: string[] }
 * - Map roles -> permissions once per request; enforce on route via requirePermissions()
 */

const ROLE_PERMISSIONS = {
  admin: new Set([
    'admin:onboarding:queue',
    'admin:onboarding:review',
    'admin:vendor:suspend',
    'booking:read:own',
    'booking:read:vendor_scope',
    'tenant:read',
    'catalog:read',
  ]),
  client: new Set([
    'booking:create',
    'booking:read:own',
    'booking:update:own',
    'payment:initiate:own',
    'payment:read:own',
    'chat:thread:read',
    'chat:message:send',
    'tenant:read',
    'catalog:read',
  ]),
  vendor: new Set([
    'vendor:profile:write:own',
    'vendor:onboarding:submit',
    'vendor:package:write',
    'booking:read:vendor_scope',
    'booking:update:vendor_scope',
    'payout:read:vendor_scope',
    'chat:thread:read',
    'chat:message:send',
    'payment:read:own',
    'tenant:read',
    'catalog:read',
  ]),
};

function expandPermissions(roles) {
  const out = new Set();
  for (const r of roles || []) {
    for (const p of ROLE_PERMISSIONS[r] || []) out.add(p);
  }
  return out;
}

export function attachPermissions(req, res, next) {
  req.permissions = expandPermissions(req.user?.roles);
  next();
}

/** @param {string[]} required - all must be present */
export function requirePermissions(...required) {
  return (req, res, next) => {
    const missing = required.filter((p) => !req.permissions?.has(p));
    if (missing.length) {
      return res.status(403).json({ code: 'FORBIDDEN', message: 'Insufficient permissions', details: { missing } });
    }
    next();
  };
}

/** Example router snippet:
 * router.post('/v1/bookings',
 *   authenticateJwt,
 *   attachPermissions,
 *   requirePermissions('booking:create'),
 *   createBookingHandler
 * );
 */
