import '../../core/api/identity_api.dart';
import '../models/profile_avatar_value.dart';
import 'profile_media_uploader.dart';
import 'profile_repository.dart';

/// Global Hub profile persistence via existing [IdentityApi] (`PATCH /me/profile`).
///
/// Does not write workspace profile tables.
class GlobalProfileRepositoryImpl extends GlobalProfileRepository {
  GlobalProfileRepositoryImpl({
    required IdentityApi identityApi,
    required ProfileMediaUploader mediaUploader,
  })  : _identityApi = identityApi,
        _mediaUploader = mediaUploader;

  final IdentityApi _identityApi;
  final ProfileMediaUploader _mediaUploader;

  Future<AuthMeResult> save({
    String? firstName,
    String? lastName,
    String? displayName,
    String? bio,
    String? occupation,
    String? company,
    List<String>? interests,
    Map<String, String>? socialLinks,
    required ProfileAvatarValue avatar,
  }) async {
    final avatarResult = await resolveAvatar(avatar, uploader: _mediaUploader);
    return _identityApi.updateGlobalProfile(
      firstName: firstName,
      lastName: lastName,
      displayName: displayName,
      bio: bio,
      occupation: occupation,
      company: company,
      interests: interests,
      socialLinks: socialLinks,
      avatarUrl: avatarResult.avatarUrl,
      clearAvatar: avatarResult.clearAvatar,
      updateAvatar: avatarResult.updateAvatar,
    );
  }
}
