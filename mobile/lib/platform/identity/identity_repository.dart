import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api/identity_api.dart';
import '../../core/api/owanbe_api_auth.dart';
import 'identity_models.dart';
import '../../auth/user_role.dart';

class IdentityRepository {
  final _api = IdentityApi();

  Future<UserContext> fetchUserContext(Session session, UserRole activeRole) async {
    final user = session.user;
    final email = user.email ?? '';
    final name = user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String? ??
        user.userMetadata?['display_name'] as String? ??
        email.split('@').first;
    final avatar = user.userMetadata?['avatar_url'] as String?;

    List<UserRole> roles = _parseJwtRoles(session);
    String tenantId = OwambeApiAuth.resolveTenantId();

    try {
      final me = await _api.fetchMe();
      roles = _mapDbRoles(me.roles);
      tenantId = OwambeApiAuth.resolveTenantId();
      final resolvedRole = roles.contains(activeRole)
          ? activeRole
          : (roles.isNotEmpty ? roles.first : activeRole);

      return UserContext(
        userId: me.userId,
        displayName: name,
        email: me.email.isNotEmpty ? me.email : email,
        avatarUrl: avatar,
        roles: roles,
        activeRole: resolvedRole,
        activeTenantId: tenantId,
      );
    } catch (_) {
      // Fall back to JWT hints when API is unreachable (offline); no portal override.
    }

    return UserContext(
      userId: user.id,
      displayName: name,
      email: email,
      avatarUrl: avatar,
      roles: roles,
      activeRole: roles.contains(activeRole) ? activeRole : _primaryRole(roles, activeRole),
      activeTenantId: tenantId,
    );
  }

  List<UserRole> _parseJwtRoles(Session session) {
    final metadata = session.user.appMetadata;
    final rolesList = metadata['roles'] as List<dynamic>?;
    if (rolesList == null || rolesList.isEmpty) return const [];

    return _mapDbRoles(rolesList.map((r) => r.toString()).toList());
  }

  List<UserRole> _mapDbRoles(List<String> codes) {
    final out = <UserRole>[];
    for (final raw in codes) {
      final name = raw.toLowerCase();
      if (name == 'client') out.add(UserRole.client);
      if (name == 'organizer') out.add(UserRole.organizer);
      if (name == 'vendor' || name == 'vendor_pending') out.add(UserRole.vendor);
      if (name == 'admin' ||
          name == 'admin_super' ||
          name == 'admin_ops' ||
          name == 'admin_support' ||
          name == 'platform_admin') {
        out.add(UserRole.admin);
      }
      if (name == 'superadmin' || name == 'super_admin') out.add(UserRole.superAdmin);
    }
    return out.isEmpty ? const [] : out.toSet().toList();
  }

  UserRole _primaryRole(List<UserRole> roles, UserRole fallback) {
    if (roles.contains(fallback)) return fallback;
    if (roles.contains(UserRole.superAdmin)) return UserRole.superAdmin;
    if (roles.contains(UserRole.admin)) return UserRole.admin;
    if (roles.contains(UserRole.organizer)) return UserRole.organizer;
    if (roles.contains(UserRole.vendor)) return UserRole.vendor;
    if (roles.contains(UserRole.client)) return UserRole.client;
    return fallback;
  }

  Future<void> linkGoogleIdentity(String email) async {
    try {
      await _api.linkEntitlements(email: email);
    } catch (_) {
      // Allow linking fallback on mock databases
    }
  }
}
