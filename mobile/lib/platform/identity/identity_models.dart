import '../../auth/user_role.dart';
export '../../auth/user_role.dart';

enum AuthOutcome {
  authenticated,
  requiresOnboarding,
  requiresWorkspaceSelection,
  requiresMFA,
  sessionExpired,
  unauthorized,
}

class UserContext {
  const UserContext({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.roles,
    required this.activeRole,
    this.activeTenantId,
    this.preferences = const {},
  });

  final String userId;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final List<UserRole> roles;
  final UserRole activeRole;
  final String? activeTenantId;
  final Map<String, dynamic> preferences;

  UserContext copyWith({
    String? displayName,
    UserRole? activeRole,
    String? activeTenantId,
    Map<String, dynamic>? preferences,
  }) {
    return UserContext(
      userId: userId,
      displayName: displayName ?? this.displayName,
      email: email,
      avatarUrl: avatarUrl,
      roles: roles,
      activeRole: activeRole ?? this.activeRole,
      activeTenantId: activeTenantId ?? this.activeTenantId,
      preferences: preferences ?? this.preferences,
    );
  }
}
