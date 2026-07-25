import '../../auth/user_role.dart';
import '../identity/workspace_models.dart';
import '../portals/customer/router/event_route_registry.dart';
import 'portal_routes.dart';

/// Owanbe 2.0 experience routing — hub-first for Customer; Control Tower for Admin.
abstract final class ExperienceRoutes {
  static const hub = '/hub';
  /// Customer Flutter login (Unified Identity customer entry).
  static const auth = '/auth';
  /// Admin Flutter login — never reused by Customer Flutter.
  static const adminAuth = '/auth/admin';
  /// Admin Flutter landing — Super Admin dashboard.
  static const adminHome = '/super-admin';
  /// Startup connectivity / configuration diagnostics (blocks login until healthy).
  static const supabaseDiagnostics = '/diagnostics/supabase';

  static String activateFor(ExperienceWorkspace ws) => switch (ws) {
        ExperienceWorkspace.attendee => '/activate/attendee',
        ExperienceWorkspace.organizer => '/activate/organizer',
        ExperienceWorkspace.vendor => '/activate/vendor',
      };

  static String workspaceHomeFor(ExperienceWorkspace ws) => switch (ws) {
        ExperienceWorkspace.attendee => '/attendee',
        ExperienceWorkspace.organizer => '/home',
        ExperienceWorkspace.vendor => '/vendor',
      };

  static String onboardingFor(ExperienceWorkspace ws) => switch (ws) {
        ExperienceWorkspace.attendee => '/attendee/onboarding',
        ExperienceWorkspace.organizer => '/organizer/onboarding',
        ExperienceWorkspace.vendor => '/vendor/onboarding',
      };

  static ExperienceWorkspace? workspaceFromPath(String location) {
    if (location.startsWith('/attendee')) return ExperienceWorkspace.attendee;
    if (location.startsWith('/organizer') ||
        EventRouteRegistry.isOrganizerWorkspacePath(location)) {
      return ExperienceWorkspace.organizer;
    }
    if (location.startsWith('/vendor')) return ExperienceWorkspace.vendor;
    return null;
  }

  static bool isHubPath(String location) =>
      location == hub || location == '/platform/home';

  static bool isAuthPath(String location) =>
      location == auth || location == adminAuth;

  static bool isCustomerAuthPath(String location) => location == auth;

  static bool isAdminAuthPath(String location) => location == adminAuth;

  static bool isAdminHomePath(String location) =>
      location == adminHome ||
      location.startsWith('/super-admin') ||
      location.startsWith('/admin');

  static bool isActivationPath(String location) =>
      location.startsWith('/activate/');

  static bool isPublicPath(String location) {
    if (PortalRoutes.isPublicPath(location)) return true;
    if (location == '/walkthrough') return true;
    if (location == supabaseDiagnostics) return true;
    return false;
  }

  static bool isDiagnosticsPath(String location) =>
      location == supabaseDiagnostics;

  /// Legacy customer portal auth paths — redirect to Customer `/auth` (not Admin).
  static bool isLegacyPortalAuthPath(String location) =>
      location == '/auth/attendee' ||
      location == '/auth/organizer' ||
      location == '/auth/vendor' ||
      location == '/portal-gate';
}

extension ExperienceWorkspaceLegacy on ExperienceWorkspace {
  UserRole get legacyRole => userRole;
}
