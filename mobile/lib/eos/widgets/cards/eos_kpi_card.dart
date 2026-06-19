import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';
import '../../tokens/eos_typography.dart';
import 'eos_surface_card.dart';

enum EosKpiAttention { none, info, warning, critical }

class EosKpiCard extends StatelessWidget {
  const EosKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.attentionSummary,
    this.attention = EosKpiAttention.none,
    this.icon,
    this.actionLabel,
    this.onTap,
    this.trend,
  });

  final String title;
  final String value;
  final String? subtitle;
  final String? attentionSummary;
  final EosKpiAttention attention;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onTap;
  final Widget? trend;

  Color _accent(BuildContext context) => switch (attention) {
        EosKpiAttention.critical => EosColors.critical,
        EosKpiAttention.warning => EosColors.warning,
        EosKpiAttention.info => context.eosColors.primary,
        EosKpiAttention.none => context.eosColors.outlineVariant,
      };

  @override
  Widget build(BuildContext context) {
    final hasAttention = attentionSummary != null && attentionSummary!.trim().isNotEmpty;
    final accent = _accent(context);

    return EosSurfaceCard(
      onTap: onTap,
      accentColor: hasAttention ? accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: hasAttention ? accent : context.eosColors.onSurfaceVariant),
                SizedBox(width: context.eos.spacing.xs),
              ],
              Expanded(child: Text(title, style: context.eosText.labelLarge)),
              if (trend != null) trend!,
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Text(
            value,
            style: EosTypography.metric(context.eosColors).copyWith(
              color: hasAttention ? accent : context.eosColors.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: context.eos.spacing.xxs),
            Text(subtitle!, style: context.eosText.bodySmall),
          ],
          if (hasAttention) ...[
            SizedBox(height: context.eos.spacing.sm),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: context.eos.spacing.sm,
                vertical: context.eos.spacing.xs,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: context.eos.radius.chip,
                border: Border.all(color: accent.withValues(alpha: 0.22)),
              ),
              child: Text(
                attentionSummary!,
                style: context.eosText.labelMedium?.copyWith(color: accent),
              ),
            ),
          ],
          if (actionLabel != null && onTap != null) ...[
            SizedBox(height: context.eos.spacing.xs),
            Text(actionLabel!, style: context.eosText.labelMedium?.copyWith(color: context.eosColors.primary)),
          ],
        ],
      ),
    );
  }
}
