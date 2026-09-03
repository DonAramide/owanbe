import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../supabase/bootstrap.dart';
import 'platform_registry.dart';

class SharedBootstrap {
  static bool isAdmin = false;
  static Future<void> initSharedPlatform() async {
    // 1. Initialize core system logging/observability
    if (kDebugMode) {
      print('[Platform Bootstrap] Initializing System Observers & Logging...');
    }

    // 2. Load env + initialize Supabase via single authoritative bootstrap
    await bootstrapSupabase();

    // Ensure dotenv is available for non-Supabase keys (API base, storage, etc.)
    // bootstrapSupabase already loaded the asset; dotenv.isInitialized covers re-entry.
    if (!dotenv.isInitialized) {
      final configFile = isAdmin
          ? 'assets/env/owanbe_config.admin'
          : 'assets/env/owanbe_config';
      await dotenv.load(fileName: configFile);
    }

    // 3. Initialize all registered platform capabilities
    await PlatformRegistry.instance.initializeAll();
  }
}
