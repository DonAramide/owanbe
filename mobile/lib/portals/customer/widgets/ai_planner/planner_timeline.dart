import 'package:flutter/material.dart';
import '../../../../eos/eos.dart';
import '../../models/ai_planner_models.dart';
import '../../models/home_hub_models.dart';

class PlannerTimeline extends StatelessWidget {
  const PlannerTimeline({super.key, required this.items});

  final List<PlannerTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _TimelineRow(
              item: items[i],
              dateLabel: items[i].weeksBefore == 0 ? 'Event day' : formatEventDate(items[i].dueAt),
              isLast: i == items.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.dateLabel,
    required this.isLast,
  });

  final PlannerTimelineItem item;
  final String dateLabel;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (item.status) {
      PlannerTimelineStatus.complete => (const Color(0xFF0D9488), 'Done'),
      PlannerTimelineStatus.overdue => (const Color(0xFFDC2626), 'Overdue'),
      PlannerTimelineStatus.dueSoon => (const Color(0xFFD4A853), 'Due soon'),
      PlannerTimelineStatus.upcoming => (context.eosColors.outline, 'Upcoming'),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: context.eosColors.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: context.eos.spacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : context.eos.spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          style: context.eosText.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: EosRadius.input,
                        ),
                        child: Text(label, style: context.eosText.labelSmall?.copyWith(color: color)),
                      ),
                    ],
                  ),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    item.weeksBefore == 0 ? dateLabel : '$dateLabel · ${item.weeksBefore}w before',
                    style: context.eosText.labelSmall?.copyWith(
                      color: context.eosColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
