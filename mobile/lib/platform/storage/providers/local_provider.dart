import 'dart:typed_data';
import 'storage_provider.dart';

class LocalProvider implements StorageProvider {
  const LocalProvider();

  @override
  String get name => 'LocalStorage';

  @override
  Future<void> putObject({
    required String bucket,
    required String key,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<Uint8List> getObject({
    required String bucket,
    required String key,
  }) async {
    await Future.delayed(const Duration(milliseconds: 30));
    return Uint8List(0);
  }

  @override
  Future<void> deleteObject({
    required String bucket,
    required String key,
  }) async {
    await Future.delayed(const Duration(milliseconds: 20));
  }

  @override
  Future<String> generateSignedUrl({
    required String bucket,
    required String key,
    required Duration expiry,
  }) async {
    return 'file:///local/storage/$bucket/$key';
  }
}
