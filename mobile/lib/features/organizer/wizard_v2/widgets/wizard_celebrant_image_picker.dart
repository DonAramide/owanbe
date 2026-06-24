import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../eos/eos.dart';

/// Optional celebrant / couple photo for the event.
class WizardCelebrantImagePicker extends StatelessWidget {
  const WizardCelebrantImagePicker({
    super.key,
    this.imageBytes,
    this.imageUrl,
    required this.onPicked,
    required this.onClear,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final ValueChanged<Uint8List> onPicked;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null || (imageUrl != null && imageUrl!.isNotEmpty);

    return EosSurfaceCard(
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pick(context),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: EosColors.champagne.withValues(alpha: 0.35),
              backgroundImage: imageBytes != null
                  ? MemoryImage(imageBytes!)
                  : imageUrl != null && imageUrl!.isNotEmpty
                      ? NetworkImage(imageUrl!)
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
                Text('Celebrant image (optional)', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.xxs),
                Text(
                  'Add a photo of the couple or celebrant for your invitation card.',
                  style: context.eosText.bodySmall,
                ),
                SizedBox(height: context.eos.spacing.sm),
                Wrap(
                  spacing: context.eos.spacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pick(context),
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: const Text('Upload photo'),
                    ),
                    if (hasImage)
                      TextButton(onPressed: onClear, child: const Text('Remove')),
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
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload works best on mobile. Use a photo from your gallery.')),
      );
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    onPicked(bytes);
  }
}
