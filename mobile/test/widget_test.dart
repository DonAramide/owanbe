import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:owambe/app.dart';
import 'package:owambe/core/bootstrap/bootstrap_scope.dart';
import 'package:owambe/core/bootstrap/shared_preferences_provider.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock',
    );
  });

  testWidgets('Splash screen shows Owanbe title', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const BootstrapScope(child: OwambeApp()),
      ),
    );
    await tester.pump();

    expect(find.text('Owanbe'), findsOneWidget);
    expect(find.text('Your Event. Our People.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}
