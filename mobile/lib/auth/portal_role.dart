import 'user_role.dart';

/// Maps immutable server `signup_portal` codes to app [UserRole].
UserRole roleFromSignupPortal(String? portal) {
  return switch (portal?.toLowerCase()) {
    'organizer' => UserRole.organizer,
    'vendor' => UserRole.vendor,
    'admin' => UserRole.admin,
    'client' || _ => UserRole.client,
  };
}

/// Authoritative portal role: prefer DB `signupPortal`, then API role codes.
UserRole resolvePortalRole({
  String? signupPortal,
  List<String> apiRoles = const [],
}) {
  if (signupPortal != null && signupPortal.trim().isNotEmpty) {
    return roleFromSignupPortal(signupPortal);
  }
  return _mapApiRoles(apiRoles);
}

UserRole _mapApiRoles(List<String> roles) {
  if (roles.contains('super_admin')) return UserRole.superAdmin;
  if (roles.any((r) => r.startsWith('admin_')) || roles.contains('platform_admin')) {
    return UserRole.admin;
  }
  if (roles.contains('vendor') || roles.contains('vendor_pending')) {
    return UserRole.vendor;
  }
  if (roles.contains('organizer')) return UserRole.organizer;
  if (roles.contains('client')) return UserRole.client;
  return UserRole.client;
}

String portalCodeFor(UserRole role) => role.name;
