String ngnFromMinor(String minorRaw) {
  final cleaned = minorRaw.trim().isEmpty ? '0' : minorRaw.trim();
  final minor = int.tryParse(cleaned) ?? 0;
  final sign = minor < 0 ? '-' : '';
  final abs = minor.abs();
  final naira = abs ~/ 100;
  final kobo = abs % 100;
  final withCommas = naira.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );
  return '$sign₦$withCommas.${kobo.toString().padLeft(2, '0')}';
}
