import { createHmac, timingSafeEqual } from 'crypto';

export function computeQuaserWebhookSignature(secret: string, rawBody: Buffer): string {
  return createHmac('sha256', secret).update(rawBody).digest('hex');
}

function normalizeSignatureHeader(headerValue: string): string {
  const v = headerValue.trim();
  const prefix = 'sha256=';
  if (v.toLowerCase().startsWith(prefix)) {
    return v.slice(prefix.length).trim();
  }
  return v;
}

function tryHexBuffer(hex: string): Buffer | null {
  const h = hex.trim();
  if (!/^[0-9a-fA-F]+$/.test(h) || h.length % 2 !== 0) {
    return null;
  }
  return Buffer.from(h, 'hex');
}

export function verifyQuaserWebhookSignature(
  secret: string,
  rawBody: Buffer,
  headerValue: string | undefined,
): boolean {
  if (!secret || !headerValue) {
    return false;
  }
  const expectedHex = computeQuaserWebhookSignature(secret, rawBody);
  const receivedHex = normalizeSignatureHeader(headerValue);
  const expectedBuf = tryHexBuffer(expectedHex);
  const receivedBuf = tryHexBuffer(receivedHex);
  if (!expectedBuf || !receivedBuf || expectedBuf.length !== receivedBuf.length) {
    return false;
  }
  try {
    return timingSafeEqual(expectedBuf, receivedBuf);
  } catch {
    return false;
  }
}
