import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../router/experience_routes.dart';
import 'enterprise_navigation_policy.dart';
import 'enterprise_router_readiness.dart';

/// Router-bound enterprise navigation — no [BuildContext] or inherited lookup.
///
/// Startup-safe: never reads [GoRouter.state]. Policy runs only when invoked
/// (Android back, AppBar back) — not during widget build.
final class EnterpriseNavigationService {
  const EnterpriseNavigationService(this.router);

  final GoRouter router;

  /// True once GoRouter has at least one matched route.
  bool get isRouterReady => EnterpriseRouterReadiness.isReady(router);

  /// Current route path, or null while the router is initializing.
  String? get currentLocation => EnterpriseRouterReadiness.currentPath(router);

  /// Whether enterprise policy would handle back for the current route.
  /// Safe during startup — returns false while idle.
  bool get canNavigateBack {
    final location = currentLocation;
    if (location == null) return false;
    if (EnterpriseNavigationPolicy.allowsAppExit(location)) return true;
    if (router.canPop()) return true;
    return EnterpriseNavigationPolicy.resolveBackFallback(location) != null;
  }

  /// Android system back — event-driven; idle until router is ready.
  void handleSystemBack() {
    if (!isRouterReady) return;

    final location = currentLocation;
    if (location == null) return;

    if (EnterpriseNavigationPolicy.allowsAppExit(location)) {
      SystemNavigator.pop();
      return;
    }

    if (router.canPop()) {
      router.pop();
      return;
    }

    final fallback = EnterpriseNavigationPolicy.resolveBackFallback(location);
    if (fallback != null) {
      router.go(fallback);
    }
  }

  /// AppBar / explicit back — same event-driven policy.
  void navigateBack() => handleSystemBack();

  /// Single UI entry to Owanbe Home.
  void returnToHub() {
    if (!isRouterReady) return;
    router.go(ExperienceRoutes.hub);
  }
}
