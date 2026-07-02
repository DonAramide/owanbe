import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models/digital_asset.dart';
import 'providers/storage_provider.dart';
import 'providers/contabo_provider.dart';
import 'providers/supabase_provider.dart';
import 'providers/local_provider.dart';
import 'services/asset_processor.dart';
import 'services/asset_security.dart';
import 'services/asset_metadata_service.dart';

class DamFramework {
  DamFramework._() {
    _processor = const AssetProcessor();
    _security = const AssetSecurity();
    _activeProvider = const LocalProvider();
  }

  static final DamFramework instance = DamFramework._();

  late final AssetProcessor _processor;
  late final AssetSecurity _security;
  AssetMetadataService? _metadataService;
  late StorageProvider _activeProvider;

  StorageProvider get activeProvider => _activeProvider;
  AssetMetadataService get metadataService => 
      _metadataService ??= AssetMetadataService(Supabase.instance.client);

  // Pre-defined Asset Policies
  final Map<AssetType, AssetPolicy> _policies = {
    AssetType.identity: const AssetPolicy(
      maxSize: 10 * 1024 * 1024, // 10MB
      maxCount: 5,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      visibility: AssetVisibility.private,
    ),
    AssetType.marketplace: const AssetPolicy(
      maxSize: 5 * 1024 * 1024, // 5MB
      maxCount: 21,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      visibility: AssetVisibility.public,
    ),
    AssetType.products: const AssetPolicy(
      maxSize: 5 * 1024 * 1024, // 5MB
      maxCount: 3,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      visibility: AssetVisibility.public,
    ),
    AssetType.services: const AssetPolicy(
      maxSize: 5 * 1024 * 1024, // 5MB
      maxCount: 6,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      visibility: AssetVisibility.public,
    ),
    AssetType.profiles: const AssetPolicy(
      maxSize: 3 * 1024 * 1024, // 3MB
      maxCount: 2,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      visibility: AssetVisibility.public,
    ),
  };

  void configureProvider(StorageProvider provider) {
    _activeProvider = provider;
  }

  void configureMetadataService(AssetMetadataService service) {
    _metadataService = service;
  }

  AssetPolicy getPolicy(AssetType type) {
    return _policies[type] ?? const AssetPolicy(
      maxSize: 5 * 1024 * 1024,
      maxCount: 10,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      visibility: AssetVisibility.protected,
    );
  }

  Future<DigitalAsset> uploadAsset({
    required Uint8List bytes,
    required String filename,
    required AssetType assetType,
    required String tenantId,
    required String ownerType,
    required String ownerId,
    required String userId,
  }) async {
    final policy = getPolicy(assetType);
    
    // 1. Run Pipeline Processing
    final result = await _processor.process(
      rawBytes: bytes,
      filename: filename,
      policy: policy,
    );

    final assetId = const Uuid().v4();
    final bucket = 'owanbe-${assetType.name}';
    final objectKey = '$tenantId/$ownerType/$ownerId/$assetId.$filename';

    // 2. Upload using Interchangeable Provider
    await _activeProvider.putObject(
      bucket: bucket,
      key: objectKey,
      bytes: result.bytes,
      mimeType: result.mimeType,
    );

    final asset = DigitalAsset(
      id: assetId,
      tenantId: tenantId,
      ownerType: ownerType,
      ownerId: ownerId,
      assetType: assetType,
      storageProvider: _activeProvider.name,
      bucket: bucket,
      objectKey: objectKey,
      checksum: result.checksum,
      mimeType: result.mimeType,
      size: result.bytes.length,
      visibility: policy.visibility,
      lifecycleState: AssetLifecycleState.available,
      verificationStatus: 'pending',
      uploadedBy: userId,
      uploadedAt: DateTime.now(),
      width: result.width,
      height: result.height,
      duration: result.duration,
    );

    // 3. Register Metadata in PostgreSQL
    await metadataService.registerAsset(asset);

    return asset;
  }

  Future<void> deleteAsset(DigitalAsset asset) async {
    await _activeProvider.deleteObject(bucket: asset.bucket, key: asset.objectKey);
    await metadataService.updateLifecycleState(asset.id, AssetLifecycleState.deleted);
  }

  Future<String> getAssetUrl(DigitalAsset asset, {String actorId = '', List<String> actorRoles = const []}) async {
    final permitted = _security.checkPermission(
      asset: asset,
      actorId: actorId,
      actorRoles: actorRoles,
    );
    if (!permitted) {
      throw SecurityError('Unauthorized to access asset ${asset.id}');
    }

    if (asset.visibility == AssetVisibility.public) {
      return '${_activeProvider.generateSignedUrl(bucket: asset.bucket, key: asset.objectKey, expiry: const Duration(hours: 24))}';
    }

    await _security.auditDownload(assetId: asset.id, actor: actorId);
    return _activeProvider.generateSignedUrl(
      bucket: asset.bucket,
      key: asset.objectKey,
      expiry: const Duration(minutes: 15),
    );
  }
}

class SecurityError implements Exception {
  SecurityError(this.message);
  final String message;
  @override
  String toString() => 'SecurityError: $message';
}
