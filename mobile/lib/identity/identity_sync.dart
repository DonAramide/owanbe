import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/identity_api.dart';
import '../core/api/persistence_providers.dart';

/// Single-flight coordinator for POST /auth/ensure-user + GET /auth/me.
///
/// All identity synchronization must go through this type so startup cannot
/// issue parallel ensure-user / auth/me storms from multiple providers.
class IdentitySyncCoordinator {
  IdentitySyncCoordinator(this._api);

  final IdentityApi _api;
  Future<AuthMeResult>? _inFlight;

  /// Stop joining an in-flight sync (e.g. after local sign-out).
  /// In-flight HTTP may still finish; new callers start a fresh sync.
  void invalidate() {
    _inFlight = null;
  }

  Future<AuthMeResult> synchronize({
    String? displayNameHint,
    bool force = false,
  }) {
    if (!force && _inFlight != null) return _inFlight!;
    final run = _run(displayNameHint);
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  Future<AuthMeResult> _run(String? displayNameHint) async {
    await _api.ensureUser(displayName: displayNameHint);
    return _api.fetchMe();
  }
}

final identitySyncCoordinatorProvider = Provider<IdentitySyncCoordinator>(
  (ref) => IdentitySyncCoordinator(ref.watch(identityApiProvider)),
);
