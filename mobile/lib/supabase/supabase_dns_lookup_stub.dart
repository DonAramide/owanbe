/// Web / non-IO stub — DNS is verified via the HTTPS health request instead.
Future<({bool ok, String? error})> lookupHost(
  String host, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  return (ok: true, error: null);
}
