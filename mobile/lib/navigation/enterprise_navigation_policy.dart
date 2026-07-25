import '../identity/workspace_models.dart';
import '../portals/attendee/navigation/attendee_routes.dart';
import '../portals/customer/router/event_route_registry.dart';
import '../router/experience_routes.dart';

/// Route zone for enterprise back-policy fallbacks.
enum NavigationZone {
  hub,
  organizerShell,
  organizerPortfolio,
  eventOverview,
  eventModule,
  marketplace,
  attendeeRoot,
  attendeeFlow,
  vendorRoot,
  vendorSubRoute,
  activation,
  auth,
  public,
  unknown,
}

/// Pure route classification and fallback resolution — no BuildContext.
abstract final class EnterpriseNavigationPolicy {
  static String normalizePath(String location) => location.split('?').first;

  static NavigationZone classify(String location) {
    final path = normalizePath(location);

    if (ExperienceRoutes.isHubPath(path)) return NavigationZone.hub;
    if (ExperienceRoutes.isAuthPath(path) || ExperienceRoutes.isLegacyPortalAuthPath(path)) {
      return NavigationZone.auth;
    }
    if (ExperienceRoutes.isActivationPath(path)) return NavigationZone.activation;

    // Organizer Event OS — must precede public `/events/` overlap in [PortalRoutes.isPublicPath].
    if (path == EventRouteRegistry.portfolio || path.startsWith('${EventRouteRegistry.portfolio}/')) {
      return NavigationZone.organizerPortfolio;
    }

    if (EventRouteRegistry.isEventModulePath(path)) return NavigationZone.eventModule;
    if (EventRouteRegistry.isEventOverviewPath(path)) return NavigationZone.eventOverview;
    if (EventRouteRegistry.isShellPath(path)) return NavigationZone.organizerShell;

    if (path == EventRouteRegistry.vendors || path.startsWith('${EventRouteRegistry.vendors}/')) {
      return NavigationZone.marketplace;
    }

    if (path == AttendeeRoutes.dashboard) return NavigationZone.attendeeRoot;
    if (path.startsWith('/attendee/')) return NavigationZone.attendeeFlow;

    if (path == ExperienceRoutes.workspaceHomeFor(ExperienceWorkspace.vendor)) {
      return NavigationZone.vendorRoot;
    }
    if (path.startsWith('/vendor/')) return NavigationZone.vendorSubRoute;

    if (ExperienceRoutes.isPublicPath(path)) return NavigationZone.public;

    if (EventRouteRegistry.isOrganizerWorkspacePath(path)) {
      return NavigationZone.organizerShell;
    }

    return NavigationZone.unknown;
  }

  /// Fallback destination when [GoRouter.canPop] is false.
  /// Returns null only at hub — the only zone where the app may exit.
  static String? resolveBackFallback(String location) {
    final path = normalizePath(location);
    final zone = classify(path);

    return switch (zone) {
      NavigationZone.hub => null,
      NavigationZone.eventModule => _eventOverviewFromModule(path),
      NavigationZone.eventOverview => EventRouteRegistry.home,
      NavigationZone.organizerPortfolio => ExperienceRoutes.hub,
      NavigationZone.organizerShell => ExperienceRoutes.hub,
      NavigationZone.marketplace => EventRouteRegistry.home,
      NavigationZone.attendeeRoot => ExperienceRoutes.hub,
      NavigationZone.attendeeFlow => _attendeeFlowFallback(path),
      NavigationZone.vendorRoot => ExperienceRoutes.hub,
      NavigationZone.vendorSubRoute => ExperienceRoutes.workspaceHomeFor(ExperienceWorkspace.vendor),
      NavigationZone.activation => ExperienceRoutes.hub,
      NavigationZone.auth => ExperienceRoutes.hub,
      NavigationZone.public => ExperienceRoutes.hub,
      NavigationZone.unknown => ExperienceRoutes.hub,
    };
  }

  static bool allowsAppExit(String location) =>
      classify(normalizePath(location)) == NavigationZone.hub;

  static String? _eventOverviewFromModule(String path) {
    final match = RegExp(r'^/events/([^/]+)/').firstMatch(path);
    if (match == null) return EventRouteRegistry.home;
    return EventRouteRegistry.event(match.group(1)!);
  }

  static String? _attendeeFlowFallback(String path) {
    final ticketsMatch = RegExp(r'^/attendee/events/([^/]+)/tickets').firstMatch(path);
    if (ticketsMatch != null) {
      return AttendeeRoutes.eventDetail(ticketsMatch.group(1)!);
    }

    final eventMatch = RegExp(r'^/attendee/events/([^/]+)$').firstMatch(path);
    if (eventMatch != null) {
      return AttendeeRoutes.dashboard;
    }

    return AttendeeRoutes.dashboard;
  }
}

/// Reusable Android back handler — apply via [EnterpriseBackHandler] or app builder.
abstract final class EnterpriseBackActions {
  /// System back: pop when possible, else policy fallback. Hub may exit naturally.
  static bool canPopRoute(String location, {required bool routerCanPop}) {
    if (EnterpriseNavigationPolicy.allowsAppExit(location)) return true;
    if (routerCanPop) return true;
    return EnterpriseNavigationPolicy.resolveBackFallback(location) == null;
  }

  static String? backFallbackFor(String location) =>
      EnterpriseNavigationPolicy.resolveBackFallback(location);
}
