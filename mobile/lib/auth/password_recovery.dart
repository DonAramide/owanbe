import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../router/experience_routes.dart';

/// In-memory only. Set exclusively by [AuthChangeEvent.passwordRecovery].
final passwordRecoveryActiveProvider = StateProvider<bool>((ref) => false);

/// Password recovery rules. Supabase Auth remains the only credential authority.
abstract final class PasswordRecovery {
  static const mobileCallback = 'io.supabase.owambe://password-recovery';
  static const googleLoginCallback = 'io.supabase.owambe://login-callback';
  static const minPasswordLength = 6;

  /// Web recovery URL for the current origin, for example
  /// `http://localhost:3000/auth/recovery`.
  static String? webRedirect(String origin) {
    final trimmed = origin.trim();
    if (trimmed.isEmpty) return null;
    final base = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return '$base${ExperienceRoutes.passwordRecovery}';
  }

  static String redirectTo({required bool isWeb, required String webOrigin}) {
    if (isWeb) {
      final web = webRedirect(webOrigin);
      if (web != null && web.isNotEmpty) return web;
    }
    return mobileCallback;
  }

  /// Only the password-recovery event may enter recovery mode.
  static bool eventActivatesRecovery(AuthChangeEvent event) =>
      event == AuthChangeEvent.passwordRecovery;

  static String? validateNewPassword({
    required String password,
    required String confirmation,
  }) {
    if (password.isEmpty || confirmation.isEmpty) {
      return 'Enter and confirm your new password.';
    }
    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    if (password != confirmation) {
      return 'Passwords do not match.';
    }
    return null;
  }
}

class RecoveryEmailCall {
  const RecoveryEmailCall({required this.email, required this.redirectTo});

  final String email;
  final String redirectTo;
}

RecoveryEmailCall buildResetPasswordForEmailCall({
  required String email,
  required bool isWeb,
  required String webOrigin,
}) {
  return RecoveryEmailCall(
    email: email.trim(),
    redirectTo: PasswordRecovery.redirectTo(isWeb: isWeb, webOrigin: webOrigin),
  );
}

/// Sends the existing Supabase recovery email. Does not store the address or token.
Future<void> sendRecoveryEmail({
  required String email,
  required bool isWeb,
  required String webOrigin,
  required Future<void> Function(String email, {required String redirectTo})
      resetPasswordForEmail,
}) async {
  final call = buildResetPasswordForEmailCall(
    email: email,
    isWeb: isWeb,
    webOrigin: webOrigin,
  );
  await resetPasswordForEmail(call.email, redirectTo: call.redirectTo);
}

class RecoveryPasswordUpdate {
  const RecoveryPasswordUpdate({required this.passwordUpdated});

  final bool passwordUpdated;

  bool get rolesChanged => false;
  bool get onboardingChanged => false;
  bool get workspaceActivated => false;
  bool get userCreated => false;
  bool get passwordStoredLocally => false;
}

/// Updates the password on the current Supabase recovery session.
///
/// Does not write local storage, roles, profiles, or workspace state.
Future<RecoveryPasswordUpdate> applyRecoveryPasswordUpdate({
  required bool recoveryActive,
  required bool hasSession,
  required String password,
  required Future<void> Function(String password) updatePassword,
}) async {
  if (!recoveryActive) {
    throw StateError('RECOVERY_REQUIRED');
  }
  if (!hasSession) {
    throw StateError('RECOVERY_SESSION_REQUIRED');
  }
  await updatePassword(password);
  return const RecoveryPasswordUpdate(passwordUpdated: true);
}

enum RecoveryRedirectKind { allow, go, defer }

class RecoveryRedirectDecision {
  const RecoveryRedirectDecision.allow()
      : kind = RecoveryRedirectKind.allow,
        location = null;

  const RecoveryRedirectDecision.go(this.location) : kind = RecoveryRedirectKind.go;

  const RecoveryRedirectDecision.defer()
      : kind = RecoveryRedirectKind.defer,
        location = null;

  final RecoveryRedirectKind kind;
  final String? location;
}

/// Narrow customer-only exceptions. Admin routing always defers.
RecoveryRedirectDecision passwordRecoveryRedirect({
  required bool isAdminApp,
  required bool recoveryActive,
  required bool hasAuthSession,
  required String location,
}) {
  if (isAdminApp) {
    return const RecoveryRedirectDecision.defer();
  }
  if (recoveryActive) {
    if (location == ExperienceRoutes.passwordRecovery) {
      return const RecoveryRedirectDecision.allow();
    }
    return const RecoveryRedirectDecision.go(ExperienceRoutes.passwordRecovery);
  }
  if (location == ExperienceRoutes.passwordRecovery) {
    return RecoveryRedirectDecision.go(
      hasAuthSession ? ExperienceRoutes.hub : ExperienceRoutes.auth,
    );
  }
  if (!hasAuthSession && location == ExperienceRoutes.forgotPassword) {
    return const RecoveryRedirectDecision.allow();
  }
  return const RecoveryRedirectDecision.defer();
}
