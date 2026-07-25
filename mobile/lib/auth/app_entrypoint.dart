import '../platform/bootstrap/bootstrap.dart';
import '../router/experience_routes.dart';

/// Application binary entry mode — Customer Flutter vs Admin Flutter.
///
/// Same Supabase project / JWT / users. Different login UI and landing only.
abstract final class AppEntrypoint {
  static bool get isAdminApp => SharedBootstrap.isAdmin;
  static bool get isCustomerApp => !SharedBootstrap.isAdmin;

  /// Staff / control-tower roles (not customer workspaces).
  static bool hasAdministrationRole(Iterable<String> roles) {
    for (final raw in roles) {
      final r = raw.trim().toLowerCase();
      if (r == 'super_admin' ||
          r == 'platform_admin' ||
          r == 'admin' ||
          r == 'admin_super' ||
          r == 'admin_ops' ||
          r == 'admin_support' ||
          r == 'operations' ||
          r == 'finance' ||
          r == 'support' ||
          r.startsWith('admin_')) {
        return true;
      }
    }
    return false;
  }

  static bool hasCustomerWorkspaceRole(Iterable<String> roles) {
    for (final raw in roles) {
      final r = raw.trim().toLowerCase();
      if (r == 'client' ||
          r == 'organizer' ||
          r == 'vendor' ||
          r == 'vendor_pending') {
        return true;
      }
    }
    return false;
  }

  static const customerAccountIsAdminMessage =
      'This account is for the Administration Portal.';

  static const adminAccountNotAuthorizedMessage =
      'This account is not authorized for the Administration Portal.';

  /// Post-splash / signed-out destination for this binary.
  static String signedOutDestination({required bool showWalkthrough}) {
    if (isAdminApp) return ExperienceRoutes.adminAuth;
    if (showWalkthrough) return '/walkthrough';
    return ExperienceRoutes.auth;
  }

  /// Post-splash / signed-in destination for this binary.
  static String signedInDestination() {
    if (isAdminApp) return ExperienceRoutes.adminHome;
    return ExperienceRoutes.hub;
  }
}
