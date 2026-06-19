enum FinanceAttentionLevel { none, info, warning, critical }

FinanceAttentionLevel attentionLevelFromString(String? raw) {
  return switch ((raw ?? '').toLowerCase()) {
    'critical' => FinanceAttentionLevel.critical,
    'warning' => FinanceAttentionLevel.warning,
    'info' => FinanceAttentionLevel.info,
    _ => FinanceAttentionLevel.none,
  };
}

String humanizeFinanceToken(String raw) {
  if (raw.isEmpty) return raw;
  return raw.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String formatAttentionAge(DateTime? oldest) {
  if (oldest == null) return '';
  final diff = DateTime.now().difference(oldest);
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'just now';
}
