import 'user_role.dart';

/// Replace with JWT claims + profile from your API.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;
  final String displayName;
  final UserRole role;
}
