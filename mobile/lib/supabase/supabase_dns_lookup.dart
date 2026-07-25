import 'supabase_dns_lookup_stub.dart'
    if (dart.library.io) 'supabase_dns_lookup_io.dart' as dns_lookup;

/// Platform DNS probe used by [SupabaseConnectivity].
Future<({bool ok, String? error})> lookupHost(
  String host, {
  Duration timeout = const Duration(seconds: 4),
}) =>
    dns_lookup.lookupHost(host, timeout: timeout);
