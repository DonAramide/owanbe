import 'package:flutter/material.dart';

/// Branded Owanbe app icon (yellow Ó mark).
class OwanbeLogo extends StatelessWidget {
  const OwanbeLogo({super.key, this.size = 32, this.borderRadius = 8});

  final double size;
  final double borderRadius;

  static const assetPath = 'assets/branding/owanbe_logo.png';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.celebration, size: size),
      ),
    );
  }
}

/// Logo + wordmark row used in shells and marketing surfaces.
class OwanbeBrandMark extends StatelessWidget {
  const OwanbeBrandMark({
    super.key,
    this.logoSize = 32,
    this.showSubtitle = false,
    this.subtitle,
  });

  final double logoSize;
  final bool showSubtitle;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OwanbeLogo(size: logoSize, borderRadius: logoSize * 0.22),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Owanbe', style: Theme.of(context).textTheme.titleLarge),
            if (showSubtitle && subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}
