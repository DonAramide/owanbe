import { Injectable, PipeTransform } from '@nestjs/common';

const CONTROL_CHARS = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g;

function sanitizeValue(value: unknown): unknown {
  if (typeof value === 'string') {
    return value.replace(CONTROL_CHARS, '').trim();
  }
  if (Array.isArray(value)) {
    return value.map(sanitizeValue);
  }
  if (value !== null && typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[k] = sanitizeValue(v);
    }
    return out;
  }
  return value;
}

/** Strips control characters from string fields in request bodies. */
@Injectable()
export class SanitizeInputPipe implements PipeTransform {
  transform(value: unknown): unknown {
    return sanitizeValue(value);
  }
}
