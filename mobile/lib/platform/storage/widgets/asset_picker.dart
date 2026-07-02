import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../eos/eos.dart';
import '../models/digital_asset.dart';
import '../models/upload_queue_item.dart';
import '../services/background_upload_queue.dart';

class AssetPicker extends StatefulWidget {
  const AssetPicker({
    super.key,
    required this.assetType,
    required this.tenantId,
    required this.ownerType,
    required this.ownerId,
    required this.userId,
    this.onUploadComplete,
  });

  final AssetType assetType;
  final String tenantId;
  final String ownerType;
  final String ownerId;
  final String userId;
  final VoidCallback? onUploadComplete;

  @override
  State<AssetPicker> createState() => _AssetPickerState();
}

class _AssetPickerState extends State<AssetPicker> {
  final ImagePicker _picker = ImagePicker();
  List<UploadQueueItem> _activeUploads = [];

  @override
  void initState() {
    super.initState();
    BackgroundUploadQueue.instance.queueStream.listen((queue) {
      if (mounted) {
        setState(() {
          _activeUploads = queue.where((e) =>
              e.ownerId == widget.ownerId && e.tenantId == widget.tenantId).toList();
          
          if (_activeUploads.isNotEmpty &&
              _activeUploads.every((e) => e.state == UploadQueueState.completed)) {
            widget.onUploadComplete?.call();
          }
        });
      }
    });
  }

  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final bytes = await file.readAsBytes();
      final item = UploadQueueItem(
        id: const Uuid().v4(),
        bytes: bytes,
        filename: file.name,
        assetType: widget.assetType,
        tenantId: widget.tenantId,
        ownerType: widget.ownerType,
        ownerId: widget.ownerId,
        userId: widget.userId,
      );
      BackgroundUploadQueue.instance.enqueue(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_upload, color: EosColors.champagne),
                const SizedBox(width: 12),
                Text(
                  'Upload to Owanbe DAM (${widget.assetType.name.toUpperCase()})',
                  style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        if (_activeUploads.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Active Queue Status:', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          ..._activeUploads.map((item) {
            return Card(
              color: Colors.white10,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item.filename, style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: item.progress,
                      backgroundColor: Colors.white10,
                      color: EosColors.champagne,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'State: ${item.state.name.toUpperCase()}',
                      style: TextStyle(
                        color: item.state == UploadQueueState.completed
                            ? Colors.green
                            : (item.state == UploadQueueState.failed ? Colors.red : Colors.white60),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.state == UploadQueueState.uploading)
                      IconButton(
                        icon: const Icon(Icons.pause, color: Colors.white70),
                        onPressed: () => BackgroundUploadQueue.instance.pauseUpload(item.id),
                      ),
                    if (item.state == UploadQueueState.paused)
                      IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.white70),
                        onPressed: () => BackgroundUploadQueue.instance.resumeUpload(item.id),
                      ),
                    if (item.state == UploadQueueState.uploading || item.state == UploadQueueState.paused)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => BackgroundUploadQueue.instance.cancelUpload(item.id),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
