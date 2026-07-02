import 'package:uuid/uuid.dart';

enum AssetType {
  identity,
  marketplace,
  products,
  services,
  events,
  venues,
  profiles,
  commerce,
  operations,
  compliance,
  communications
}

enum AssetLifecycleState {
  draft,
  uploading,
  processing,
  available,
  pendingVerification,
  verified,
  rejected,
  archived,
  deleted,
  expired
}

enum AssetVisibility {
  public,
  protected,
  private
}

class AssetPolicy {
  const AssetPolicy({
    required this.maxSize,
    required this.maxCount,
    required this.allowedExtensions,
    required this.visibility,
    this.maxDuration,
    this.compressionProfile,
    this.thumbnailProfile,
  });

  final int maxSize; // bytes
  final int maxCount;
  final List<String> allowedExtensions;
  final AssetVisibility visibility;
  final Duration? maxDuration;
  final String? compressionProfile;
  final String? thumbnailProfile;
}

class DigitalAsset {
  DigitalAsset({
    required this.id,
    required this.tenantId,
    required this.ownerType,
    required this.ownerId,
    required this.assetType,
    required this.storageProvider,
    required this.bucket,
    required this.objectKey,
    required this.checksum,
    required this.mimeType,
    required this.size,
    required this.visibility,
    required this.lifecycleState,
    required this.verificationStatus,
    required this.uploadedBy,
    required this.uploadedAt,
    this.width,
    this.height,
    this.duration,
    this.reviewedBy,
    this.reviewedAt,
  });

  final String id;
  final String tenantId;
  final String ownerType;
  final String ownerId;
  final AssetType assetType;
  final String storageProvider;
  final String bucket;
  final String objectKey;
  final String checksum;
  final String mimeType;
  final int size;
  final AssetVisibility visibility;
  AssetLifecycleState lifecycleState;
  String verificationStatus; // 'pending', 'verified', 'rejected'
  final String uploadedBy;
  final DateTime uploadedAt;
  final int? width;
  final int? height;
  final Duration? duration;
  String? reviewedBy;
  DateTime? reviewedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'owner_type': ownerType,
      'owner_id': ownerId,
      'asset_type': assetType.name,
      'storage_provider': storageProvider,
      'bucket': bucket,
      'object_key': objectKey,
      'checksum': checksum,
      'mime_type': mimeType,
      'size': size,
      'visibility': visibility.name,
      'lifecycle_state': lifecycleState.name,
      'verification_status': verificationStatus,
      'uploaded_by': uploadedBy,
      'uploaded_at': uploadedAt.toIso8601String(),
      'width': width,
      'height': height,
      'duration_seconds': duration?.inSeconds,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  factory DigitalAsset.fromJson(Map<String, dynamic> json) {
    return DigitalAsset(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      ownerType: json['owner_type'] as String,
      ownerId: json['owner_id'] as String,
      assetType: AssetType.values.firstWhere((e) => e.name == json['asset_type']),
      storageProvider: json['storage_provider'] as String,
      bucket: json['bucket'] as String,
      objectKey: json['object_key'] as String,
      checksum: json['checksum'] as String,
      mimeType: json['mime_type'] as String,
      size: json['size'] as int,
      visibility: AssetVisibility.values.firstWhere((e) => e.name == json['visibility']),
      lifecycleState: AssetLifecycleState.values.firstWhere((e) => e.name == json['lifecycle_state']),
      verificationStatus: json['verification_status'] as String,
      uploadedBy: json['uploaded_by'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      width: json['width'] as int?,
      height: json['height'] as int?,
      duration: json['duration_seconds'] != null ? Duration(seconds: json['duration_seconds'] as int) : null,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at'] as String) : null,
    );
  }
}

class AuditLogEntry {
  AuditLogEntry({
    required this.id,
    required this.assetId,
    required this.fromState,
    required this.toState,
    required this.actor,
    required this.timestamp,
    required this.correlationId,
    this.notes,
  });

  final String id;
  final String assetId;
  final String fromState;
  final String toState;
  final String actor;
  final DateTime timestamp;
  final String correlationId;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'asset_id': assetId,
      'from_state': fromState,
      'to_state': toState,
      'actor': actor,
      'timestamp': timestamp.toIso8601String(),
      'correlation_id': correlationId,
      'notes': notes,
    };
  }
}
