import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap/bootstrap_scope.dart';
import 'core/bootstrap/shared_preferences_provider.dart';
import 'customer_app.dart';
import 'features/public/screens/supabase_diagnostics_screen.dart';
import 'platform/bootstrap/bootstrap_customer.dart';
import 'supabase/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final prefs = await bootstrapSharedPreferences();
  try {
    await bootstrapCustomer();
  } on SupabaseConfigException catch (e) {
    runApp(SupabaseBootstrapFailureApp(diagnostic: e.diagnostic));
    return;
  }
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const BootstrapScope(child: CustomerApp()),
    ),
  );
}
