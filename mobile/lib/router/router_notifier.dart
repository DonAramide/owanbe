import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_session.dart';

/// Drives [GoRouter] refresh when [authSessionProvider] changes.
final class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AuthSession?>(authSessionProvider, (prev, next) => notifyListeners());
  }

  final Ref _ref;
}
