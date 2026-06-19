import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../cards/eos_surface_card.dart';

class EosFeedItem extends StatelessWidget {
  const EosFeedItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String timestamp;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: EosSurfaceCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, SizedBox(width: context.eos.spacing.sm)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.eosText.titleSmall),
                  SizedBox(height: context.eos.spacing.xxs),
                  Text(subtitle, style: context.eosText.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (trailing != null) trailing!,
                SizedBox(height: context.eos.spacing.xxs),
                Text(timestamp, style: context.eosText.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
