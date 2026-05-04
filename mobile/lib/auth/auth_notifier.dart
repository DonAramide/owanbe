import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_session.dart';
import 'user_role.dart';

/// Holds the signed-in user. `null` = logged out.
class AuthNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  /// Temporary demo sign-in — swap for OAuth/password + token refresh.
  void signInDemo({required UserRole role}) {
    state = AuthSession(
      userId: 'demo-${role.name}',
      displayName: 'Demo ${role.label}',
      role: role,
    );
  }

  void signOut() => state = null;
}

final authSessionProvider =
    NotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);
