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
    );
  }
}
