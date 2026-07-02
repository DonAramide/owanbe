import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:owambe/app.dart';

void main() {
  setUpAll(() async {
    // Initialize mock SharedPreferences & Supabase client for widget test pipeline
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock',
    );
  });

  testWidgets('Splash screen shows Owanbe title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OwambeApp()));
    await tester.pump(); // Pump initial frame

    expect(find.text('Owanbe'), findsOneWidget);
    expect(find.text('Your Event. Our People.'), findsOneWidget);

    // Let the 6-second redirect timer complete to clear pending timers
    await tester.pump(const Duration(seconds: 6));
  });
}
