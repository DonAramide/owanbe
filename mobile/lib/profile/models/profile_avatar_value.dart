import 'dart:typed_data';

/// Mutable avatar edit state shared across profile editors.
class ProfileAvatarValue {
  const ProfileAvatarValue({
    this.remoteUrl,
    this.localBytes,
    this.removed = false,
  });

  final String? remoteUrl;
  final Uint8List? localBytes;
  final bool removed;

  bool get hasPreview =>
      localBytes != null || (!removed && (remoteUrl != null && remoteUrl!.trim().isNotEmpty));

  bool get isDirty => localBytes != null || removed;

  /// True when save must send an avatar update (upload or clear).
  bool get shouldUpdateRemote => localBytes != null || removed;

  ProfileAvatarValue copyWith({
    String? remoteUrl,
    Uint8List? localBytes,
    bool? removed,
    bool clearLocalBytes = false,
  }) {
    return ProfileAvatarValue(
      remoteUrl: remoteUrl ?? this.remoteUrl,
      localBytes: clearLocalBytes ? null : (localBytes ?? this.localBytes),
      removed: removed ?? this.removed,
    );
  }

  ProfileAvatarValue withPickedBytes(Uint8List bytes) => ProfileAvatarValue(
        remoteUrl: remoteUrl,
        localBytes: bytes,
        removed: false,
      );

  ProfileAvatarValue cleared() => const ProfileAvatarValue(removed: true);

  factory ProfileAvatarValue.fromRemote(String? url) => ProfileAvatarValue(remoteUrl: url);
}
