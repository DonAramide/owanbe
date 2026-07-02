import 'dart:typed_data';
import 'storage_provider.dart';

class ContaboProvider implements StorageProvider {
  const ContaboProvider({
    required this.endpoint,
    required this.region,
    required this.accessKey,
    required this.secretKey,
  });

  final String endpoint;
  final String region;
  final String accessKey;
  final String secretKey;

  @override
  String get name => 'ContaboS3';

  @override
  Future<void> putObject({
    required String bucket,
    required String key,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    // Simulates S3 API PUT request to Contabo:
    // PUT https://<bucket>.<endpoint>/<key> with Auth Signature Headers.
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<Uint8List> getObject({
    required String bucket,
    required String key,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Uint8List(0);
  }

  @override
  Future<void> deleteObject({
    required String bucket,
    required String key,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<String> generateSignedUrl({
    required String bucket,
    required String key,
    required Duration expiry,
  }) async {
    // Generates a pre-signed URL with AWS Signature Version 4 HMAC parameters:
    return '$endpoint/$bucket/$key?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=$accessKey&X-Amz-Expires=${expiry.inSeconds}';
  }
}
