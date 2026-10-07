import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_session.dart';
import '../auth/password_recovery.dart';
import '../core/bootstrap/app_bootstrap.dart';
import '../core/bootstrap/app_boot_state.dart';
import '../identity/identity_provider.dart';
import 'deep_link_listener.dart';

/// Drives [GoRouter] refresh when auth, identity, or workspace context changes.
final class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AuthSession?>(authSessionProvider, (prev, next) {
      final prevUser = prev?.userId;
      final nextUser = next?.userId;
      if (prevUser != nextUser) notifyListeners();
    });
    _ref.listen(appBootstrapProvider, (prev, next) {
      if (prev?.phase != next.phase &&
          (next.phase == AppBootPhase.ready ||
              next.phase == AppBootPhase.connectivityBlocked ||
              next.phase == AppBootPhase.offlineReady)) {
        notifyListeners();
      }
    });
    _ref.listen(userIdentityProvider, (previous, next) {
      final prevId = previous?.valueOrNull?.userId;
      final nextId = next.valueOrNull?.userId;
      if (prevId != nextId) notifyListeners();
    });
    _ref.listen(activeWorkspaceProvider, (prev, next) {
      if (prev != next) notifyListeners();
    });
    _ref.listen<String?>(pendingDeepLinkProvider, (prev, next) {
      if (next != null) notifyListeners();
    });
    _ref.listen<bool>(passwordRecoveryActiveProvider, (prev, next) {
      if (prev != next) notifyListeners();
    });
  }

  final Ref _ref;
}
