import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'supabase_diagnostic.dart';

/// Loads public Supabase config from the single authoritative env asset and initializes the client.
///
/// Used by Customer (`main.dart` / `main_customer.dart`) and Admin (`main_admin.dart`).
/// Never put `sb_secret` / service_role keys here — server only.
class SupabaseBootstrap {
  SupabaseBootstrap._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  /// Last config failure before [Supabase.initialize] (if any).
  static SupabaseDiagnostic? lastConfigFailure;

  /// Validates config and initializes [Supabase]. Idempotent.
  ///
  /// Throws [SupabaseConfigException] when configuration is invalid — callers
  /// should show diagnostics and must not continue boot.
  static Future<SupabaseConfig> ensureInitialized() async {
    if (_initialized) {
      final cached = SupabaseConfig.current;
      if (cached != null) return cached;
    }

    lastConfigFailure = null;
    try {
      final config = await SupabaseConfig.load();
      if (!_initialized) {
        if (kDebugMode) {
          debugPrint(
            'Supabase bootstrap: url=${config.url} '
            'projectRef=${config.projectRef} '
            'anonKeySuffix=${config.anonKey.length >= 8 ? config.anonKey.substring(config.anonKey.length - 8) : '***'}',
          );
        }
        await Supabase.initialize(
          url: config.url,
          anonKey: config.anonKey,
          debug: kDebugMode,
        );
        _initialized = true;
      }
      return config;
    } on SupabaseConfigException catch (e) {
      lastConfigFailure = e.diagnostic;
      if (kDebugMode) {
        debugPrint('Supabase configuration failed: ${e.diagnostic.message}');
        if (e.diagnostic.technicalDetail != null) {
          debugPrint('  detail: ${e.diagnostic.technicalDetail}');
        }
      }
      rethrow;
    } catch (e, st) {
      lastConfigFailure = SupabaseDiagnostic(
        kind: SupabaseFailureKind.unknown,
        title: 'Supabase configuration is invalid.',
        message: 'Supabase client failed to initialize.',
        technicalDetail: '$e',
      );
      if (kDebugMode) {
        debugPrint('Supabase bootstrap failed: $e\n$st');
      }
      throw SupabaseConfigException(lastConfigFailure!);
    }
  }
}

/// Compatibility entry used by [main.dart] and platform bootstrap.
Future<void> bootstrapSupabase() => SupabaseBootstrap.ensureInitialized();
