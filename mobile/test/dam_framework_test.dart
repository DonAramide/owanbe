import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/platform/storage/dam_framework.dart';
import 'package:owambe/platform/storage/models/digital_asset.dart';
import 'package:owambe/platform/storage/providers/local_provider.dart';
import 'package:owambe/platform/storage/services/asset_metadata_service.dart';

class MockAssetMetadataService extends AssetMetadataService {
  MockAssetMetadataService() : super(null as dynamic);

  final List<DigitalAsset> _mockCache = [];

  @override
  Future<void> registerAsset(DigitalAsset asset) async {
    _mockCache.add(asset);
  }

  @override
  Future<void> updateLifecycleState(String assetId, AssetLifecycleState state) async {
    final idx = _mockCache.indexWhere((e) => e.id == assetId);
    if (idx != -1) {
      _mockCache[idx].lifecycleState = state;
    }
  }

  @override
  Future<void> updateVerificationStatus(
    String assetId, {
    required String status,
    required String reviewer,
  }) async {
    final idx = _mockCache.indexWhere((e) => e.id == assetId);
    if (idx != -1) {
      _mockCache[idx].verificationStatus = status;
    }
  }

  @override
  Future<List<DigitalAsset>> fetchAssets() async {
    return _mockCache;
  }
}

void main() {
  group('Digital Asset Management (DAM) Framework Tests', () {
    setUp(() {
      DamFramework.instance.configureProvider(const LocalProvider());
      DamFramework.instance.configureMetadataService(MockAssetMetadataService());
    });

    test('Should enforce asset size policy limits and throw error', () async {
      final largeBytes = Uint8List(15 * 1024 * 1024); // 15MB
      
      expect(
        () => DamFramework.instance.uploadAsset(
          bytes: largeBytes,
          filename: 'document.pdf',
          assetType: AssetType.identity, // Limit is 10MB
          tenantId: 'tenant-123',
          ownerType: 'vendor',
          ownerId: 'vendor-456',
          userId: 'user-789',
        ),
        throwsArgumentError,
      );
    });

    test('Should enforce format extensions policies and throw error', () async {
      final bytes = Uint8List(100);
      
      expect(
        () => DamFramework.instance.uploadAsset(
          bytes: bytes,
          filename: 'malicious_script.exe',
          assetType: AssetType.identity, // Only pdf, jpg, jpeg, png allowed
          tenantId: 'tenant-123',
          ownerType: 'vendor',
          ownerId: 'vendor-456',
          userId: 'user-789',
        ),
        throwsArgumentError,
      );
    });
  });
}
