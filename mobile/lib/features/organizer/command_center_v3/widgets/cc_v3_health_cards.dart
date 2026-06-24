import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';

class CcV3SectionHeader extends StatelessWidget {
  const CcV3SectionHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.eosText.titleLarge),
          if (subtitle != null) Text(subtitle!, style: context.eosText.bodySmall),
        ],
      ),
    );
  }
}

class CcV3HealthCard extends StatelessWidget {
  const CcV3HealthCard({
    super.key,
    required this.title,
    required this.progressPercent,
    required this.metrics,
    this.onTap,
  });

  final String title;
  final double progressPercent;
  final List<CcV3MetricItem> metrics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.eosText.titleSmall)),
              Text('${progressPercent.round()}%', style: context.eosText.labelLarge?.copyWith(color: EosColors.plum)),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (progressPercent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: context.eosColors.outlineVariant.withValues(alpha: 0.4),
              color: EosColors.plum,
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          Wrap(
            spacing: context.eos.spacing.md,
            runSpacing: context.eos.spacing.sm,
            children: metrics
                .map(
                  (m) => SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.label, style: context.eosText.labelSmall),
                        Text(
                          m.value,
                          style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class CcV3MetricItem {
  const CcV3MetricItem({required this.label, required this.value});
  final String label;
  final String value;
}

class CcV3Timeline extends StatelessWidget {
  const CcV3Timeline({super.key, required this.items});

  final List<CcV3TimelineItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EosSurfaceCard(
        child: Text('No recent activity yet.', style: context.eosText.bodyMedium),
      );
    }
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: EosColors.plum.withValues(alpha: 0.12),
                      child: Icon(items[i].icon, size: 16, color: EosColors.plum),
                    ),
                    if (i < items.length - 1)
                      Container(width: 2, height: 32, color: context.eosColors.outlineVariant),
                  ],
                ),
                SizedBox(width: context.eos.spacing.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].title, style: context.eosText.titleSmall),
                        Text(items[i].subtitle, style: context.eosText.bodySmall),
                        Text(items[i].timeAgo, style: context.eosText.labelSmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class CcV3TimelineItem {
  const CcV3TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String timeAgo;
}
