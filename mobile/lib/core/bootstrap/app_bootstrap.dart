import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/app_entrypoint.dart';
import '../../router/experience_routes.dart';
import '../../supabase/supabase_config.dart';
import '../../supabase/supabase_connectivity.dart';
import '../../supabase/supabase_diagnostic.dart';
import 'app_boot_state.dart';
import 'shared_preferences_provider.dart';

const _showWalkthroughKey = 'show_walkthrough';

/// Minimum splash brand display — presentation policy only (not a network timeout).
const kMinSplashBrandDuration = Duration(seconds: 2);

final appBootstrapProvider =
    NotifierProvider<AppBootstrapNotifier, AppBootSnapshot>(AppBootstrapNotifier.new);

/// Centralized application bootstrap — sole owner of cold-start orchestration.
class AppBootstrapNotifier extends Notifier<AppBootSnapshot> {
  bool _started = false;
  SupabaseDiagnostic? _lastDiagnostic;

  SupabaseDiagnostic? get lastDiagnostic => _lastDiagnostic;

  @override
  AppBootSnapshot build() {
    return AppBootSnapshot(
      phase: AppBootPhase.uninitialized,
      startedAt: DateTime.now(),
    );
  }

  /// Idempotent — same code path for cold start, hot restart, and resume.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _runBoot(respectBrandDelay: true);
  }

  /// Re-run connectivity (and continue to login when healthy).
  Future<void> retryConnectivity() async {
    state = state.copyWith(
      phase: AppBootPhase.initializing,
      clearConnectivity: true,
    );
    await _runBoot(respectBrandDelay: false);
  }

  Future<void> _runBoot({required bool respectBrandDelay}) async {
    final brandStarted = DateTime.now();
    state = state.copyWith(phase: AppBootPhase.initializing);

    try {
      final config = SupabaseConfig.current;
      if (config == null) {
        _blockWithDiagnostic(
          const SupabaseDiagnostic(
            kind: SupabaseFailureKind.configMissing,
            title: 'Supabase configuration is invalid.',
            message:
                'Supabase was not initialized. Restart the app after fixing assets/env/owanbe_config.',
          ),
        );
        return;
      }

      final connectivity = await SupabaseConnectivity.verify(config);
      if (!connectivity.ok && connectivity.diagnostic != null) {
        final d = connectivity.diagnostic!;
        // Invalid config always blocks. Network/DNS/timeout must not trap the user —
        // Android Wi‑Fi often reports "connected" while probes fail; sign-in can still work.
        if (d.isConfigurationError) {
          if (kDebugMode) {
            debugPrint(
              'Supabase connectivity blocked (config): ${d.kind.name} '
              '${d.technicalDetail ?? ''}',
            );
          }
          _blockWithDiagnostic(d);
          return;
        }
        if (kDebugMode) {
          debugPrint(
            'Supabase connectivity soft-fail (${d.kind.name}); continuing to login. '
            '${d.technicalDetail ?? d.message}',
          );
        }
        _lastDiagnostic = d;
      }

      await _finishReady(
        brandStarted: brandStarted,
        respectBrandDelay: respectBrandDelay,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('App bootstrap error: $e\n$st');
      }
      if (e is SupabaseConfigException) {
        _blockWithDiagnostic(e.diagnostic);
        return;
      }
      // Non-config bootstrap errors: soft-continue to login.
      if (kDebugMode) {
        debugPrint('Bootstrap soft-continue after: $e');
      }
      _lastDiagnostic = SupabaseConnectivity.classifyNetworkError(e);
      try {
        await _finishReady(
          brandStarted: brandStarted,
          respectBrandDelay: respectBrandDelay,
        );
      } catch (e2, st2) {
        if (kDebugMode) debugPrint('Bootstrap finish failed: $e2\n$st2');
        _blockWithDiagnostic(SupabaseConnectivity.classifyNetworkError(e2));
      }
    }
  }

  Future<void> _finishReady({
    required DateTime brandStarted,
    required bool respectBrandDelay,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final showWalkthrough =
        AppEntrypoint.isCustomerApp && (prefs.getBool(_showWalkthroughKey) ?? true);
    var supaSession = Supabase.instance.client.auth.currentSession;
    var isAuthenticated = supaSession != null;

    if (supaSession != null && !_sessionAllowedForEntrypoint(supaSession)) {
      try {
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
      isAuthenticated = false;
      supaSession = null;
    }

    state = state.copyWith(
      phase: AppBootPhase.sessionResolved,
      isAuthenticated: isAuthenticated,
      showWalkthrough: showWalkthrough,
      clearConnectivity: true,
    );

    if (respectBrandDelay) {
      final elapsed = DateTime.now().difference(brandStarted);
      if (elapsed < kMinSplashBrandDuration) {
        await Future<void>.delayed(kMinSplashBrandDuration - elapsed);
      }
    }

    state = state.copyWith(
      phase: AppBootPhase.ready,
      destination: _destination(
        isAuthenticated: isAuthenticated,
        showWalkthrough: showWalkthrough,
      ),
      clearConnectivity: true,
    );
  }

  /// Bypass a soft network block and continue to the normal signed-out destination.
  Future<void> continueToLogin() async {
    await _finishReady(
      brandStarted: DateTime.now(),
      respectBrandDelay: false,
    );
  }

  void _blockWithDiagnostic(SupabaseDiagnostic diagnostic) {
    _lastDiagnostic = diagnostic;
    state = state.copyWith(
      phase: AppBootPhase.connectivityBlocked,
      destination: ExperienceRoutes.supabaseDiagnostics,
      errorMessage: diagnostic.message,
      connectivityTitle: diagnostic.title,
      connectivityMessage: diagnostic.message,
      connectivityKind: diagnostic.kind.name,
      configuredUrl: diagnostic.configuredUrl,
      technicalDetail: diagnostic.technicalDetail,
    );
  }

  /// Called when auth confirms API is unreachable but Supabase session exists.
  void markOfflineReady() {
    if (state.phase == AppBootPhase.ready || state.phase == AppBootPhase.offlineReady) {
      return;
    }
    state = state.copyWith(
      phase: AppBootPhase.offlineReady,
      destination: _destination(
        isAuthenticated: state.isAuthenticated,
        showWalkthrough: state.showWalkthrough,
      ),
    );
  }

  static bool _sessionAllowedForEntrypoint(Session session) {
    final roles = _jwtRoles(session);
    if (AppEntrypoint.isAdminApp) {
      return AppEntrypoint.hasAdministrationRole(roles);
    }
    // Customer app: administration staff must use Admin Flutter.
    return !AppEntrypoint.hasAdministrationRole(roles);
  }

  static List<String> _jwtRoles(Session session) {
    for (final source in [
      session.user.appMetadata['roles'],
      session.user.userMetadata?['roles'],
    ]) {
      if (source is List) {
        return source.map((e) => e.toString()).toList();
      }
    }
    return const [];
  }

  static String _destination({
    required bool isAuthenticated,
    required bool showWalkthrough,
  }) {
    if (isAuthenticated) return AppEntrypoint.signedInDestination();
    return AppEntrypoint.signedOutDestination(showWalkthrough: showWalkthrough);
  }
}
