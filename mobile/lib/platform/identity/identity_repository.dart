import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api/persistence_providers.dart';
import '../../core/api/identity_api.dart';
import 'identity_models.dart';
import '../../auth/user_role.dart';

class IdentityRepository {
  final _supabase = Supabase.instance.client;

  Future<UserContext> fetchUserContext(Session session, UserRole activeRole) async {
    final user = session.user;
    final jwtRoles = _parseJwtRoles(session);
    
    // Resolve user profile info
    final email = user.email ?? '';
    final name = user.userMetadata?['full_name'] as String? ?? user.userMetadata?['name'] as String? ?? email.split('@').first;
    final avatar = user.userMetadata?['avatar_url'] as String?;
    
    return UserContext(
      userId: user.id,
      displayName: name,
      email: email,
      avatarUrl: avatar,
      roles: jwtRoles,
      activeRole: activeRole,
      activeTenantId: '11111111-1111-4111-8111-111111111111', // default fallback tenant
    );
  }

  List<UserRole> _parseJwtRoles(Session session) {
    final metadata = session.user.appMetadata;
    final rolesList = metadata['roles'] as List<dynamic>?;
    if (rolesList == null) return [UserRole.client];
    
    return rolesList.map((r) {
      final name = r.toString().toLowerCase();
      if (name == 'client') return UserRole.client;
      if (name == 'organizer') return UserRole.organizer;
      if (name == 'vendor') return UserRole.vendor;
      if (name == 'admin' || name == 'admin_super') return UserRole.admin;
      if (name == 'superadmin' || name == 'super_admin') return UserRole.superAdmin;
      return UserRole.client;
    }).toList();
  }

  Future<void> linkGoogleIdentity(String email) async {
    // Standard routine to link provider accounts on existing email login
    try {
      final api = IdentityApi();
      await api.linkEntitlements(email: email);
    } catch (_) {
      // Allow linking fallback on mock databases
    }
  }
}
