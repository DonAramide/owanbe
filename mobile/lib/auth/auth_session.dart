import 'user_role.dart';

/// Replace with JWT claims + profile from your API.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.displayName,
    required this.role,
    this.email,
    this.onboardingComplete = false,
    this.signupPortal,
    this.roles = const [],
  });

  final String userId;
  final String displayName;
  final UserRole role;
  final String? email;
  final bool onboardingComplete;
  final String? signupPortal;
  /// All role codes from GET /auth/me (multi-role in Owanbe 2.0).
  final List<String> roles;

  bool hasRoleCode(String code) =>
      roles.map((r) => r.toLowerCase()).contains(code.toLowerCase());

  AuthSession copyWith({
    String? displayName,
    bool? onboardingComplete,
    String? signupPortal,
  }) {
    return AuthSession(
      userId: userId,
      displayName: displayName ?? this.displayName,
      role: role,
      email: email,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      signupPortal: signupPortal ?? this.signupPortal,
      roles: roles,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthSession &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.role == role &&
        other.email == email &&
        other.onboardingComplete == onboardingComplete &&
        other.signupPortal == signupPortal &&
        _stringListEquals(other.roles, roles);
  }

  @override
  int get hashCode => Object.hash(
        userId,
        displayName,
        role,
        email,
        onboardingComplete,
        signupPortal,
        Object.hashAll(roles),
      );
}

/// JWT rotation must not replace API-enriched identity (roles, onboarding, name).
bool shouldReplaceAuthSessionForSupabaseEvent({
  required bool isTokenRefresh,
  required bool isInitialSession,
  required String? currentUserId,
  required String incomingUserId,
}) {
  if (isTokenRefresh) return false;
  if (isInitialSession && currentUserId != null && currentUserId == incomingUserId) {
    return false;
  }
  return true;
}

bool _stringListEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
