import '../auth/user_role.dart';
import '../identity/owanbe_identity_config.dart';
import '../router/experience_routes.dart';
import 'portal_routes.dart';

/// Maps `owambe://` deep links to in-app routes (v2 hub-first + legacy portal).
abstract final class PortalDeepLinks {
  static const scheme = 'owambe';

  /// `owambe://auth/vendor` → universal auth (v2) or portal auth (legacy)
  static String? mapUri(Uri uri) {
    if (uri.scheme != scheme) return null;

    if (uri.host == 'auth') {
      final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (OwanbeIdentityConfig.identityV2) {
        return ExperienceRoutes.auth;
      }
      return switch (segment) {
        'attendee' => PortalRoutes.authFor(UserRole.client),
        'organizer' => PortalRoutes.authFor(UserRole.organizer),
        'vendor' => PortalRoutes.authFor(UserRole.vendor),
        'admin' => PortalRoutes.authFor(UserRole.admin),
        _ => null,
      };
    }

    if (uri.host == 'portal-gate' || uri.path == '/portal-gate') {
      return OwanbeIdentityConfig.identityV2 ? ExperienceRoutes.hub : PortalRoutes.gate;
    }

    if (uri.host == 'hub' || uri.path == '/hub') {
      return ExperienceRoutes.hub;
    }

    if (uri.host == 'attendee') {
      return OwanbeIdentityConfig.identityV2 ? '/attendee' : PortalRoutes.homeFor(UserRole.client);
    }
    if (uri.host == 'organizer') {
      return OwanbeIdentityConfig.identityV2 ? '/home' : PortalRoutes.homeFor(UserRole.organizer);
    }
    if (uri.host == 'vendor') {
      return OwanbeIdentityConfig.identityV2 ? '/vendor' : PortalRoutes.homeFor(UserRole.vendor);
    }
    if (uri.host == 'admin') return PortalRoutes.homeFor(UserRole.admin);

    return null;
  }
}
