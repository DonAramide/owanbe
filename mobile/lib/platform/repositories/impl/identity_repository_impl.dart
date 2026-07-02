import '../../../auth/auth_session.dart';
import '../../../core/api/identity_api.dart';
import '../i_identity_repository.dart';

class IdentityRepositoryImpl implements IIdentityRepository {
  const IdentityRepositoryImpl(this._api);
  final IdentityApi _api;

  @override
  Future<Map<String, dynamic>> fetchProfile(AuthSession session) async {
    final profile = await _api.fetchOrganizerProfile(session);
    return {
      'id': session.userId,
      'displayName': session.displayName,
      'email': session.email,
      'isComplete': profile.isComplete,
    };
  }

  @override
  Future<void> updateProfile(AuthSession session, Map<String, dynamic> data) async {
    await _api.upsertOrganizerProfile(
      session,
      displayName: data['displayName']?.toString(),
      organizationName: data['organizationName']?.toString(),
      phoneE164: data['phoneE164']?.toString(),
      onboardingStep: data['onboardingStep']?.toString(),
    );
  }
}
