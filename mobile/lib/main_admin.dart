import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_app.dart';
import 'core/bootstrap/bootstrap_scope.dart';
import 'core/bootstrap/shared_preferences_provider.dart';
import 'features/public/screens/supabase_diagnostics_screen.dart';
import 'platform/bootstrap/bootstrap_admin.dart';
import 'supabase/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final prefs = await bootstrapSharedPreferences();
  try {
    await bootstrapAdmin();
  } on SupabaseConfigException catch (e) {
    runApp(SupabaseBootstrapFailureApp(diagnostic: e.diagnostic));
    return;
  }
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const BootstrapScope(child: AdminApp()),
    ),
  );
}
