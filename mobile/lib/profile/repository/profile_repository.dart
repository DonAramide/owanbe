import '../models/profile_avatar_value.dart';
import 'profile_media_uploader.dart';

/// Result of resolving avatar bytes/removal into a remote URL payload.
class ProfileAvatarPersistResult {
  const ProfileAvatarPersistResult({
    required this.updateAvatar,
    this.avatarUrl,
    this.clearAvatar = false,
  });

  final bool updateAvatar;
  final String? avatarUrl;
  final bool clearAvatar;
}

/// Contract for profile persistence backends.
///
/// Implementations must write only their own profile store
/// (global `users`, or a future workspace profile table) — never merge layers.
abstract class ProfileRepository {
  /// Resolves local avatar edits into upload / clear flags for PATCH payloads.
  Future<ProfileAvatarPersistResult> resolveAvatar(
    ProfileAvatarValue avatar, {
    required ProfileMediaUploader uploader,
  }) async {
    if (!avatar.shouldUpdateRemote) {
      return const ProfileAvatarPersistResult(updateAvatar: false);
    }
    if (avatar.localBytes != null) {
      final url = await uploader.uploadAvatar(bytes: avatar.localBytes!);
      return ProfileAvatarPersistResult(updateAvatar: true, avatarUrl: url);
    }
    return const ProfileAvatarPersistResult(updateAvatar: true, clearAvatar: true);
  }
}

/// Marker mixin for repositories that edit the Global User Profile only.
abstract class GlobalProfileRepository extends ProfileRepository {}

/// Marker for Attendee workspace profile repositories (fields live in attendee portal).
abstract class AttendeeProfileRepository extends ProfileRepository {}

/// Marker for Organizer workspace profile repositories (fields live in organizer feature).
abstract class OrganizerProfileRepository extends ProfileRepository {}

/// Marker for Vendor workspace profile repositories (fields live in vendor feature).
abstract class VendorProfileRepository extends ProfileRepository {}
