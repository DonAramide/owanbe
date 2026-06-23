import 'package:flutter/material.dart';

import '../../../eos/eos.dart';

/// Compact metric summary used on home and event command surfaces.
class SummaryMetricCard extends StatelessWidget {
  const SummaryMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      onTap: onTap,
      accentColor: accentColor ?? context.eosColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: accentColor ?? context.eosColors.primary),
                SizedBox(width: context.eos.spacing.xs),
              ],
              Expanded(
                child: Text(label, style: context.eosText.labelSmall),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 18, color: context.eosColors.onSurfaceVariant),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Text(
            value,
            style: context.eosText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            SizedBox(height: context.eos.spacing.xxs),
            Text(subtitle!, style: context.eosText.bodySmall),
          ],
        ],
      ),
    );
  }
}
