import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:owambe/auth/auth_notifier.dart';
import 'package:owambe/auth/auth_session.dart';
import 'package:owambe/auth/user_role.dart';
import 'package:owambe/core/bootstrap/shared_preferences_provider.dart';
import 'package:owambe/identity/identity_provider.dart';
import 'package:owambe/identity/user_identity.dart';
import 'package:owambe/portals/attendee/widgets/attendee_flow_scaffold.dart';
import 'package:owambe/theme/owanbe_theme.dart';

class _StubIdentityNotifier extends UserIdentityNotifier {
  @override
  Future<OwanbeUserIdentity?> build() async => null;
}

class _StubAuthNotifier extends AuthNotifier {
  @override
  AuthSession? build() => const AuthSession(
        userId: 'test-user',
        displayName: 'Test Attendee',
        role: UserRole.client,
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AttendeeFlowScaffold provides Material context for Chip widgets', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authSessionProvider.overrideWith(_StubAuthNotifier.new),
          userIdentityProvider.overrideWith(_StubIdentityNotifier.new),
        ],
        child: MaterialApp(
          theme: owanbeTheme,
          home: AttendeeFlowScaffold(
            body: Center(
              child: Chip(
                label: const Text('Afrobeats'),
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Afrobeats'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
