import 'dart:typed_data';

import '../../core/api/media_api.dart';

/// Shared avatar upload via existing [MediaApi] (presign + PUT).
class ProfileMediaUploader {
  ProfileMediaUploader(this._media);

  final MediaApi _media;

  Future<String> uploadAvatar({
    required Uint8List bytes,
    String filename = 'avatar.jpg',
    String contentType = 'image/jpeg',
    String purpose = 'avatar',
  }) async {
    final presign = await _media.presignUpload(
      filename: filename,
      contentType: contentType,
      purpose: purpose,
    );
    if (presign.uploadUrl.isEmpty || presign.publicUrl.isEmpty) {
      throw MediaApiException(
        code: 'INVALID_PRESIGN',
        message: 'Avatar upload could not be prepared',
      );
    }
    final servedUrl = await _media.uploadBytesReturningPublicUrl(
      uploadUrl: presign.uploadUrl,
      bytes: bytes,
      contentType: contentType,
    );
    return (servedUrl != null && servedUrl.isNotEmpty) ? servedUrl : presign.publicUrl;
  }
}
