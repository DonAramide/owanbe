import 'dart:typed_data';
import 'digital_asset.dart';

enum UploadQueueState {
  waiting,
  uploading,
  paused,
  retrying,
  completed,
  failed,
  cancelled
}

class UploadQueueItem {
  UploadQueueItem({
    required this.id,
    required this.bytes,
    required this.filename,
    required this.assetType,
    required this.tenantId,
    required this.ownerType,
    required this.ownerId,
    required this.userId,
    this.state = UploadQueueState.waiting,
    this.progress = 0.0,
    this.errorMessage,
    this.retryCount = 0,
  });

  final String id;
  final Uint8List bytes;
  final String filename;
  final AssetType assetType;
  final String tenantId;
  final String ownerType;
  final String ownerId;
  final String userId;
  UploadQueueState state;
  double progress;
  String? errorMessage;
  int retryCount;
}
