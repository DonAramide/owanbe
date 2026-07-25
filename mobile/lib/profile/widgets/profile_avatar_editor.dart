import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../eos/eos.dart';
import '../models/profile_avatar_value.dart';

/// Reusable avatar uploader: preview, upload, replace, remove.
class ProfileAvatarEditor extends StatelessWidget {
  const ProfileAvatarEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.title = 'Avatar',
    this.subtitle = 'Upload, replace, or remove your photo.',
  });

  final ProfileAvatarValue value;
  final ValueChanged<ProfileAvatarValue> onChanged;
  final bool enabled;
  final String title;
  final String subtitle;

  static Future<Uint8List?> pickGalleryBytes() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = value.hasPreview;

    return EosSurfaceCard(
      child: Row(
        children: [
          GestureDetector(
            onTap: enabled ? () => _pick(context) : null,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: EosColors.champagne.withValues(alpha: 0.35),
              backgroundImage: value.localBytes != null
                  ? MemoryImage(value.localBytes!)
                  : (!value.removed && value.remoteUrl != null && value.remoteUrl!.isNotEmpty)
                      ? NetworkImage(value.remoteUrl!)
                      : null,
              child: hasImage
                  ? null
                  : Icon(Icons.add_a_photo_outlined, size: 32, color: EosColors.plum),
            ),
          ),
          SizedBox(width: context.eos.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.xxs),
                Text(subtitle, style: context.eosText.bodySmall),
                SizedBox(height: context.eos.spacing.sm),
                Wrap(
                  spacing: context.eos.spacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: enabled ? () => _pick(context) : null,
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: Text(hasImage ? 'Replace' : 'Upload'),
                    ),
                    if (hasImage)
                      TextButton(
                        onPressed: enabled ? () => onChanged(value.cleared()) : null,
                        child: const Text('Remove'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final bytes = await pickGalleryBytes();
    if (bytes == null) return;
    onChanged(value.withPickedBytes(bytes));
  }
}
