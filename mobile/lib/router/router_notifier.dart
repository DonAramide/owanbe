import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_session.dart';
import '../core/bootstrap/app_bootstrap.dart';
import '../identity/identity_provider.dart';
import 'deep_link_listener.dart';
/// Drives [GoRouter] refresh when auth, identity, or workspace context changes.
final class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AuthSession?>(authSessionProvider, (prev, next) => notifyListeners());
    _ref.listen(appBootstrapProvider, (_, __) => notifyListeners());
    _ref.listen(userIdentityProvider, (previous, next) {
      // Refresh routing when identity resolves or userId changes — not on sync errors.
      final prevId = previous?.valueOrNull?.userId;
      final nextId = next.valueOrNull?.userId;
      if (previous?.isLoading != next.isLoading || prevId != nextId) {
        notifyListeners();
      }
    });
    _ref.listen(activeWorkspaceProvider, (_, __) => notifyListeners());
    _ref.listen<String?>(pendingDeepLinkProvider, (prev, next) {
      if (next != null) notifyListeners();
    });
  }

  final Ref _ref;
}
