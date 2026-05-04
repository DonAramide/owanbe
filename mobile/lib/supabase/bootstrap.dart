import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads public Supabase config from bundled [assets/env/supabase.env] and initializes the client.
///
/// Never put `sb_secret` / service_role keys here — server only.
Future<void> bootstrapSupabase() async {
  try {
    await dotenv.load(fileName: 'assets/env/supabase.env');
    final url = dotenv.env['SUPABASE_URL']?.trim();
    final anon = dotenv.env['SUPABASE_ANON_KEY']?.trim();
    if (url == null || anon == null || url.isEmpty || anon.isEmpty) {
      throw StateError('SUPABASE_URL / SUPABASE_ANON_KEY missing in assets/env/supabase.env');
    }
    await Supabase.initialize(
      url: url,
      anonKey: anon,
      debug: kDebugMode,
    );
  } catch (e, st) {
    debugPrint('Supabase bootstrap failed: $e\n$st');
    rethrow;
  }
}
