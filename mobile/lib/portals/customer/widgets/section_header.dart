import 'package:flutter/material.dart';

import '../../../eos/eos.dart';

/// Section title row for customer portal screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.eosText.titleLarge),
                if (subtitle != null)
                  Padding(
                    padding: EdgeInsets.only(top: context.eos.spacing.xxs),
                    child: Text(subtitle!, style: context.eosText.bodySmall),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (trailingLabel != null && onTrailingTap != null)
            TextButton(onPressed: onTrailingTap, child: Text(trailingLabel!)),
        ],
      ),
    );
  }
}
