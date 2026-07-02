import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'platform_registry.dart';

class SharedBootstrap {
  static bool isAdmin = false;
  static Future<void> initSharedPlatform() async {
    // 1. Initialize core system logging/observability
    if (kDebugMode) {
      print("[Platform Bootstrap] Initializing System Observers & Logging...");
    }

    // 2. Load env and initialize Supabase client
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
      if (kDebugMode) {
        print('Supabase bootstrap failed: $e\n$st');
      }
      rethrow;
    }

    // 3. Initialize all registered platform capabilities
    await PlatformRegistry.instance.initializeAll();
  }
}
