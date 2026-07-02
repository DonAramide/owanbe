import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/upload_queue_item.dart';
import '../dam_framework.dart';

class BackgroundUploadQueue {
  BackgroundUploadQueue._();
  static final BackgroundUploadQueue instance = BackgroundUploadQueue._();

  final List<UploadQueueItem> _queue = [];
  final _controller = StreamController<List<UploadQueueItem>>.broadcast();

  List<UploadQueueItem> get items => List.unmodifiable(_queue);
  Stream<List<UploadQueueItem>> get queueStream => _controller.stream;

  void enqueue(UploadQueueItem item) {
    _queue.add(item);
    _notify();
    _processNext();
  }

  void pauseUpload(String id) {
    final item = _queue.firstWhere((e) => e.id == id);
    if (item.state == UploadQueueState.uploading || item.state == UploadQueueState.waiting) {
      item.state = UploadQueueState.paused;
      _notify();
    }
  }

  void resumeUpload(String id) {
    final item = _queue.firstWhere((e) => e.id == id);
    if (item.state == UploadQueueState.paused) {
      item.state = UploadQueueState.waiting;
      _notify();
      _processNext();
    }
  }

  void cancelUpload(String id) {
    final item = _queue.firstWhere((e) => e.id == id);
    item.state = UploadQueueState.cancelled;
    _notify();
  }

  void _notify() {
    _controller.add(List.from(_queue));
  }

  Future<void> _processNext() async {
    final nextIndex = _queue.indexWhere((e) => e.state == UploadQueueState.waiting);
    if (nextIndex == -1) return;

    final item = _queue[nextIndex];
    item.state = UploadQueueState.uploading;
    item.progress = 0.1;
    _notify();

    try {
      // Simulate progress updates
      for (int i = 2; i <= 9; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (item.state == UploadQueueState.cancelled || item.state == UploadQueueState.paused) return;
        item.progress = i / 10.0;
        _notify();
      }

      await DamFramework.instance.uploadAsset(
        bytes: item.bytes,
        filename: item.filename,
        assetType: item.assetType,
        tenantId: item.tenantId,
        ownerType: item.ownerType,
        ownerId: item.ownerId,
        userId: item.userId,
      );

      item.state = UploadQueueState.completed;
      item.progress = 1.0;
      _notify();
    } catch (e) {
      if (item.retryCount < 3) {
        item.retryCount++;
        item.state = UploadQueueState.retrying;
        item.errorMessage = 'Upload failed. Retrying... (Attempt ${item.retryCount})';
        _notify();
        await Future.delayed(Duration(seconds: item.retryCount * 2));
        item.state = UploadQueueState.waiting;
        _notify();
      } else {
        item.state = UploadQueueState.failed;
        item.errorMessage = e.toString();
        _notify();
      }
    } finally {
      _processNext();
    }
  }
}
