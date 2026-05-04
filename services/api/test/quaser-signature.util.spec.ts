import {
  computeQuaserWebhookSignature,
  verifyQuaserWebhookSignature,
} from '../src/modules/payments/quaser-signature.util';

describe('quaser-signature.util', () => {
  const secret = 'test-secret-at-least-eight';
  const body = Buffer.from(JSON.stringify({ a: 1 }), 'utf8');

  it('accepts exact hex signature', () => {
    const sig = computeQuaserWebhookSignature(secret, body);
    expect(verifyQuaserWebhookSignature(secret, body, sig)).toBe(true);
  });

  it('accepts sha256= prefix', () => {
    const sig = computeQuaserWebhookSignature(secret, body);
    expect(verifyQuaserWebhookSignature(secret, body, `sha256=${sig}`)).toBe(true);
  });

  it('rejects wrong secret', () => {
    const sig = computeQuaserWebhookSignature(secret, body);
    expect(verifyQuaserWebhookSignature('other-secret-at-least-eight', body, sig)).toBe(false);
  });

  it('rejects tampered body', () => {
    const sig = computeQuaserWebhookSignature(secret, body);
    const tampered = Buffer.from(JSON.stringify({ a: 2 }), 'utf8');
    expect(verifyQuaserWebhookSignature(secret, tampered, sig)).toBe(false);
  });
});
