import 'package:go_router/go_router.dart';

/// Startup-safe GoRouter introspection — never touches [GoRouter.state].
///
/// [GoRouter.state] internally calls [RouteMatchList.last], which throws
/// `Bad state: No element` when the match list is empty during cold startup.
abstract final class EnterpriseRouterReadiness {
  static bool isReady(GoRouter router) =>
      router.routerDelegate.currentConfiguration.matches.isNotEmpty;

  /// Active route path, or null while the router is still initializing.
  static String? currentPath(GoRouter router) {
    if (!isReady(router)) return null;
    final uri = router.routerDelegate.currentConfiguration.uri;
    return uri.path.isEmpty ? '/' : uri.path;
  }
}
