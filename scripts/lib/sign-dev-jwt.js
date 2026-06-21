#!/usr/bin/env node
/**
 * Sign a dev JWT compatible with SupabaseJwtStrategy (Phase 8 gate tests).
 */
const jwt = require('../../services/api/node_modules/jsonwebtoken');

const JWT_SECRET = process.env.SUPABASE_JWT_SECRET || 'dev-jwt-secret-16chars';

function signDevJwt(params) {
  const {
    userId,
    email,
    tenantId,
    roles = [],
    expiresIn = '1h',
    expired = false,
  } = params;
  const payload = {
    sub: userId,
    email,
    app_metadata: { tenant_id: tenantId, roles },
  };
  if (expired) {
    return jwt.sign(payload, JWT_SECRET, {
      algorithm: 'HS256',
      expiresIn: '-10s',
    });
  }
  return jwt.sign(payload, JWT_SECRET, { algorithm: 'HS256', expiresIn });
}

function signInvalidJwt() {
  return jwt.sign({ sub: 'bad' }, 'wrong-secret-not-matching', {
    algorithm: 'HS256',
    expiresIn: '1h',
  });
}

module.exports = { signDevJwt, signInvalidJwt, JWT_SECRET };
