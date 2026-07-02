import '../../auth/auth_session.dart';

abstract interface class IIdentityRepository {
  Future<Map<String, dynamic>> fetchProfile(AuthSession session);
  Future<void> updateProfile(AuthSession session, Map<String, dynamic> data);
}
