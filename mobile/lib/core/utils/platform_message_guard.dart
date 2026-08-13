/// Detects Organizer↔Vendor attempts to move contact or payment off Owanbe.
class PlatformMessageGuard {
  PlatformMessageGuard._();

  static const keepInOwanbe =
      'For your protection, please keep communication and payment within Owanbe.';

  static final List<RegExp> _patterns = [
    RegExp(r'\bwhats\s*app\b', caseSensitive: false),
    RegExp(r'\bwa\.me\b', caseSensitive: false),
    RegExp(r'\bt\.me\b', caseSensitive: false),
    RegExp(r'\btelegram\b', caseSensitive: false),
    RegExp(r'\bsignal\b', caseSensitive: false),
    RegExp(r'\binstagram\b', caseSensitive: false),
    RegExp(r'\bfacebook\b', caseSensitive: false),
    RegExp(r'\bcall\s+me\b', caseSensitive: false),
    RegExp(r'\btext\s+me\b', caseSensitive: false),
    RegExp(r'\bdm\s+me\b', caseSensitive: false),
    RegExp(r'\bmy\s+(?:phone|number|cell)\b', caseSensitive: false),
    RegExp(r'(?:\+?234|0)\s*\d[\d\s-]{7,14}\d'),
    RegExp(r'\b\d{3}[\s.-]?\d{3}[\s.-]?\d{4}\b'),
    RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b', caseSensitive: false),
    RegExp(r'\bbank\s+(?:account|transfer|details)\b', caseSensitive: false),
    RegExp(r'\baccount\s+(?:number|no\.?|#)\b', caseSensitive: false),
    RegExp(r'\bnuban\b', caseSensitive: false),
    RegExp(r'\bopay\b', caseSensitive: false),
    RegExp(r'\bpalmpay\b', caseSensitive: false),
    RegExp(r'\bgtbank\b', caseSensitive: false),
    RegExp(r'\bpay\s+me\s+directly\b', caseSensitive: false),
    RegExp(r'\bsend\s+(?:payment|money|cash)\s+(?:to|directly)\b', caseSensitive: false),
    RegExp(r'\boutside\s+owanbe\b', caseSensitive: false),
    RegExp(r'\boff[\s-]?platform\b', caseSensitive: false),
    RegExp(r"\blet'?s\s+do\s+this\s+outside\b", caseSensitive: false),
    RegExp(r'\bdirect\s+payment\b', caseSensitive: false),
    RegExp(r'\bwire\s+transfer\b', caseSensitive: false),
    RegExp(r'\bcash\s+app\b', caseSensitive: false),
    RegExp(r'\bpaypal\b', caseSensitive: false),
    RegExp(r'\bvenmo\b', caseSensitive: false),
  ];

  static bool isBypassAttempt(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return _patterns.any((p) => p.hasMatch(trimmed));
  }

  /// Returns [keepInOwanbe] when blocked, otherwise null.
  static String? blockReason(String text) =>
      isBypassAttempt(text) ? keepInOwanbe : null;
}
