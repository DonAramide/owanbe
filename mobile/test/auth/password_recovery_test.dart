import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:owambe/auth/auth_notifier.dart';
import 'package:owambe/auth/auth_session.dart';
import 'package:owambe/auth/password_recovery.dart';
import 'package:owambe/eos/theme/eos_theme.dart';
import 'package:owambe/features/auth/screens/universal_auth_screen.dart';
import 'package:owambe/features/identity/screens/recovery_password_screen.dart';
import 'package:owambe/router/experience_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SilentAuth extends AuthNotifier {
  @override
  AuthSession? build() => null;
}

void main() {
  test('forgot password and recovery routes exist', () {
    expect(ExperienceRoutes.forgotPassword, '/auth/forgot-password');
    expect(ExperienceRoutes.passwordRecovery, '/auth/recovery');
    final router = File('lib/router/app_router.dart').readAsStringSync();
    expect(router.contains('ForgotPasswordScreen'), isTrue);
    expect(router.contains('RecoveryPasswordScreen'), isTrue);
    expect(router.contains('ExperienceRoutes.forgotPassword'), isTrue);
    expect(router.contains('ExperienceRoutes.passwordRecovery'), isTrue);
  });

  test('logged-out customer can stay on forgot password', () {
    final decision = passwordRecoveryRedirect(
      isAdminApp: false,
      recoveryActive: false,
      hasAuthSession: false,
      location: ExperienceRoutes.forgotPassword,
    );
    expect(decision.kind, RecoveryRedirectKind.allow);
  });

  test('resetPasswordForEmail is called with the trimmed email and redirect', () async {
    String? email;
    String? sentRedirect;
    await sendRecoveryEmail(
      email: '  attendee@owanbe.dev  ',
      isWeb: true,
      webOrigin: 'http://localhost:3000',
      resetPasswordForEmail: (value, {required redirectTo}) async {
        email = value;
        sentRedirect = redirectTo;
      },
    );
    expect(email, 'attendee@owanbe.dev');
    expect(sentRedirect, 'http://localhost:3000/auth/recovery');
  });

  test('web recovery redirect uses the current origin', () {
    expect(
      PasswordRecovery.webRedirect('http://localhost:3000'),
      'http://localhost:3000/auth/recovery',
    );
    expect(
      PasswordRecovery.webRedirect('https://dev.owanbe.com/'),
      'https://dev.owanbe.com/auth/recovery',
    );
    expect(
      PasswordRecovery.redirectTo(isWeb: true, webOrigin: 'http://localhost:3000'),
      'http://localhost:3000/auth/recovery',
    );
  });

  test('mobile recovery redirect is the password-recovery callback', () {
    expect(
      PasswordRecovery.redirectTo(isWeb: false, webOrigin: ''),
      PasswordRecovery.mobileCallback,
    );
    expect(
      PasswordRecovery.mobileCallback,
      'io.supabase.owambe://password-recovery',
    );
    expect(PasswordRecovery.mobileCallback, isNot(PasswordRecovery.googleLoginCallback));
  });

  test('only passwordRecovery activates recovery mode', () {
    expect(PasswordRecovery.eventActivatesRecovery(AuthChangeEvent.passwordRecovery), isTrue);
    expect(PasswordRecovery.eventActivatesRecovery(AuthChangeEvent.signedIn), isFalse);
    expect(PasswordRecovery.eventActivatesRecovery(AuthChangeEvent.initialSession), isFalse);
    expect(PasswordRecovery.eventActivatesRecovery(AuthChangeEvent.tokenRefreshed), isFalse);
    expect(PasswordRecovery.eventActivatesRecovery(AuthChangeEvent.signedOut), isFalse);
  });

  test('recovery route requires recovery mode', () {
    final blocked = passwordRecoveryRedirect(
      isAdminApp: false,
      recoveryActive: false,
      hasAuthSession: true,
      location: ExperienceRoutes.passwordRecovery,
    );
    expect(blocked.kind, RecoveryRedirectKind.go);
    expect(blocked.location, ExperienceRoutes.hub);

    final loggedOut = passwordRecoveryRedirect(
      isAdminApp: false,
      recoveryActive: false,
      hasAuthSession: false,
      location: ExperienceRoutes.passwordRecovery,
    );
    expect(loggedOut.location, ExperienceRoutes.auth);

    final allowed = passwordRecoveryRedirect(
      isAdminApp: false,
      recoveryActive: true,
      hasAuthSession: false,
      location: ExperienceRoutes.passwordRecovery,
    );
    expect(allowed.kind, RecoveryRedirectKind.allow);
  });

  test('active recovery stays off the hub', () {
    final decision = passwordRecoveryRedirect(
      isAdminApp: false,
      recoveryActive: true,
      hasAuthSession: true,
      location: ExperienceRoutes.hub,
    );
    expect(decision.location, ExperienceRoutes.passwordRecovery);
  });

  test('new password confirmation is validated before submit', () {
    expect(
      PasswordRecovery.validateNewPassword(password: '123456', confirmation: '123457'),
      'Passwords do not match.',
    );
    expect(
      PasswordRecovery.validateNewPassword(password: '12345', confirmation: '12345'),
      contains('at least'),
    );
    expect(
      PasswordRecovery.validateNewPassword(password: '123456', confirmation: '123456'),
      isNull,
    );
  });

  test('updateUser runs only with recovery mode and a session', () async {
    String? updated;
    await applyRecoveryPasswordUpdate(
      recoveryActive: true,
      hasSession: true,
      password: '123456',
      updatePassword: (password) async {
        updated = password;
      },
    );
    expect(updated, '123456');

    expect(
      () => applyRecoveryPasswordUpdate(
        recoveryActive: false,
        hasSession: true,
        password: '123456',
        updatePassword: (_) async {},
      ),
      throwsStateError,
    );
    expect(
      () => applyRecoveryPasswordUpdate(
        recoveryActive: true,
        hasSession: false,
        password: '123456',
        updatePassword: (_) async {},
      ),
      throwsStateError,
    );
  });

  test('recovery password update does not store the password or change identity', () async {
    final writes = <String>[];
    final result = await applyRecoveryPasswordUpdate(
      recoveryActive: true,
      hasSession: true,
      password: '123456',
      updatePassword: (_) async {},
    );
    expect(writes, isEmpty);
    expect(result.passwordUpdated, isTrue);
    expect(result.passwordStoredLocally, isFalse);
    expect(result.rolesChanged, isFalse);
    expect(result.onboardingChanged, isFalse);
    expect(result.workspaceActivated, isFalse);
    expect(result.userCreated, isFalse);
  });

  test('recovery implementation does not touch roles, onboarding, or workspace activation', () {
    final notifier = File('lib/auth/auth_notifier.dart').readAsStringSync();
    final screen = File('lib/features/identity/screens/recovery_password_screen.dart').readAsStringSync();
    final rules = File('lib/auth/password_recovery.dart').readAsStringSync();
    for (final src in [notifier, screen, rules]) {
      expect(src.contains('completeSignup'), isFalse);
      expect(src.contains('activateWorkspace'), isFalse);
      expect(src.contains('ensureUser'), isFalse);
    }
    expect(notifier.contains('UserAttributes(password: next)'), isTrue);
    expect(screen.contains('SharedPreferences'), isFalse);
    expect(rules.contains('SharedPreferences'), isFalse);
  });

  test('normal customer login route is unchanged when recovery is inactive', () {
    final decision = passwordRecoveryRedirect(
      isAdminApp: false,
      recoveryActive: false,
      hasAuthSession: false,
      location: ExperienceRoutes.auth,
    );
    expect(decision.kind, RecoveryRedirectKind.defer);
  });

  test('admin routing is not given the recovery exception', () {
    final forgot = passwordRecoveryRedirect(
      isAdminApp: true,
      recoveryActive: false,
      hasAuthSession: false,
      location: ExperienceRoutes.forgotPassword,
    );
    final recovery = passwordRecoveryRedirect(
      isAdminApp: true,
      recoveryActive: true,
      hasAuthSession: false,
      location: ExperienceRoutes.passwordRecovery,
    );
    expect(forgot.kind, RecoveryRedirectKind.defer);
    expect(recovery.kind, RecoveryRedirectKind.defer);
    final admin = File('lib/features/auth/screens/admin_auth_screen.dart').readAsStringSync();
    expect(admin.contains('Forgot password?'), isFalse);
  });

  test('Google login callback is unchanged and Android accepts password recovery', () {
    final identity = File('lib/platform/identity/identity_platform.dart').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    expect(identity.contains("redirectTo: 'io.supabase.owambe://login-callback'"), isTrue);
    expect(manifest.contains('android:host="login-callback"'), isTrue);
    expect(manifest.contains('android:host="password-recovery"'), isTrue);
    expect(ios.contains('<string>io.supabase.owambe</string>'), isTrue);
    expect(ios.contains('<string>owambe</string>'), isTrue);
  });

  test('admin password reset stub remains unsupported', () {
    final admin = File('lib/eos/services/platform_admin_services.dart').readAsStringSync();
    expect(admin.contains('throw UnsupportedError'), isTrue);
    expect(admin.contains('Password reset uses Supabase Auth recovery flows'), isTrue);
  });

  testWidgets('Forgot password? opens the forgot-password route', (tester) async {
    final router = GoRouter(
      initialLocation: ExperienceRoutes.auth,
      routes: [
        GoRoute(
          path: ExperienceRoutes.auth,
          builder: (context, state) => const UniversalAuthScreen(),
        ),
        GoRoute(
          path: ExperienceRoutes.forgotPassword,
          builder: (context, state) => const Scaffold(body: Text('forgot-destination')),
        ),
      ],
    );
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authSessionProvider.overrideWith(_SilentAuth.new)],
        child: MaterialApp.router(
          theme: EosTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    final forgot = find.text('Forgot password?');
    await tester.ensureVisible(forgot);
    await tester.pump();
    expect(forgot, findsOneWidget);
    await tester.tap(forgot);
    await tester.pumpAndSettle();
    expect(find.text('forgot-destination'), findsOneWidget);
  });

  testWidgets('recovery screen rejects a mismatched confirmation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authSessionProvider.overrideWith(_SilentAuth.new)],
        child: MaterialApp(
          theme: EosTheme.dark(),
          home: const RecoveryPasswordScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'New password'), '123456');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), '654321');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });
}
