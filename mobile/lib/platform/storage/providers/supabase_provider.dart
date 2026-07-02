import 'dart:typed_data';
import 'storage_provider.dart';

class SupabaseProvider implements StorageProvider {
  const SupabaseProvider();

  @override
  String get name => 'SupabaseStorage';

  @override
  Future<void> putObject({
    required String bucket,
    required String key,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<Uint8List> getObject({
    required String bucket,
    required String key,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return Uint8List(0);
  }

  @override
  Future<void> deleteObject({
    required String bucket,
    required String key,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<String> generateSignedUrl({
    required String bucket,
    required String key,
    required Duration expiry,
  }) async {
    return 'https://supabase.co/storage/v1/object/sign/$bucket/$key?token=mockSupabaseToken';
  }
}
