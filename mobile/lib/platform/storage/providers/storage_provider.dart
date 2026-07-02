import 'dart:typed_data';

abstract class StorageProvider {
  String get name;
  
  Future<void> putObject({
    required String bucket,
    required String key,
    required Uint8List bytes,
    required String mimeType,
  });

  Future<Uint8List> getObject({
    required String bucket,
    required String key,
  });

  Future<void> deleteObject({
    required String bucket,
    required String key,
  });

  Future<String> generateSignedUrl({
    required String bucket,
    required String key,
    required Duration expiry,
  });
}
