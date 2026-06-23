import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/ai_planner_models.dart';

class PlannerChecklist extends StatelessWidget {
  const PlannerChecklist({super.key, required this.items});

  final List<PlannerChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    final done = items.where((i) => i.done).length;

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$done of ${items.length} complete',
            style: context.eosText.labelLarge?.copyWith(
              color: context.eosColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          for (final item in items)
            Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: item.done ? const Color(0xFF0D9488) : context.eosColors.outline,
                    size: 22,
                  ),
                  SizedBox(width: context.eos.spacing.sm),
                  Expanded(
                    child: Text(
                      item.label,
                      style: context.eosText.bodyMedium?.copyWith(
                        decoration: item.done ? TextDecoration.lineThrough : null,
                        color: item.done ? context.eosColors.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
