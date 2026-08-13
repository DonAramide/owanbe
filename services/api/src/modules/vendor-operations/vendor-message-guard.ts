/**
 * Detects Organizer↔Vendor attempts to move contact or payment off Owanbe.
 * Operational service discussion is allowed; bypass patterns are blocked.
 */
export const PLATFORM_KEEP_IN_OWANBE =
  'For your protection, please keep communication and payment within Owanbe.';

const BYPASS_PATTERNS: RegExp[] = [
  /\bwhats\s*app\b/i,
  /\bwa\.me\b/i,
  /\bt\.me\b/i,
  /\btelegram\b/i,
  /\bsignal\b/i,
  /\binstagram\b/i,
  /\bfacebook\b/i,
  /\bcall\s+me\b/i,
  /\btext\s+me\b/i,
  /\bdm\s+me\b/i,
  /\bmy\s+(?:phone|number|cell)\b/i,
  /\b(?:phone|mobile|cell)\s*(?:number|no\.?|#)?\s*[:=]?\s*\+?\d/i,
  /(?:\+?234|0)\s*\d[\d\s-]{7,14}\d/,
  /\b\d{3}[\s.-]?\d{3}[\s.-]?\d{4}\b/,
  /\b[\w.+-]+@[\w-]+\.[\w.-]+\b/i,
  /\bgmail\.com\b/i,
  /\byahoo\.com\b/i,
  /\boutlook\.com\b/i,
  /\bbank\s+(?:account|transfer|details)\b/i,
  /\baccount\s+(?:number|no\.?|#)\b/i,
  /\bnuban\b/i,
  /\bopay\b/i,
  /\bpalmpay\b/i,
  /\bgtbank\b/i,
  /\baccess\s+bank\b/i,
  /\bzelle\b/i,
  /\bvenmo\b/i,
  /\bpaypal\b/i,
  /\bpaystack\.me\b/i,
  /\bflutterwave\b/i,
  /\bpay\s+me\s+directly\b/i,
  /\bsend\s+(?:payment|money|cash)\s+(?:to|directly)\b/i,
  /\boutside\s+owanbe\b/i,
  /\boff[\s-]?platform\b/i,
  /\blet'?s\s+do\s+this\s+outside\b/i,
  /\bdirect\s+payment\b/i,
  /\bwire\s+transfer\b/i,
  /\bcash\s+app\b/i,
];

export function detectPlatformBypass(text: string): { blocked: boolean; reason: string | null } {
  const trimmed = text.trim();
  if (!trimmed) return { blocked: false, reason: null };
  for (const pattern of BYPASS_PATTERNS) {
    if (pattern.test(trimmed)) {
      return { blocked: true, reason: PLATFORM_KEEP_IN_OWANBE };
    }
  }
  return { blocked: false, reason: null };
}
