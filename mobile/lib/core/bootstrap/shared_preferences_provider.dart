import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pre-initialized in [main] before [runApp] — never call [SharedPreferences.getInstance] at runtime.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'SharedPreferences not initialized. Call bootstrapSharedPreferences() in main() '
    'and override sharedPreferencesProvider.',
  );
});

/// Must be awaited once in main() before runApp.
Future<SharedPreferences> bootstrapSharedPreferences() {
  return SharedPreferences.getInstance();
}
