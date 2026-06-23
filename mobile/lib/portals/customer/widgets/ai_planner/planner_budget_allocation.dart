import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../models/budget_dashboard_models.dart';
import '../../models/ai_planner_models.dart';

class PlannerBudgetAllocation extends StatelessWidget {
  const PlannerBudgetAllocation({super.key, required this.slices});

  final List<PlannerBudgetSlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.amountMinor);

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final slice in slices) ...[
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(slice.colorArgb),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: context.eos.spacing.sm),
                Expanded(
                  child: Text(slice.category.label, style: context.eosText.bodyMedium),
                ),
                Text(
                  formatRevenue(slice.amountMinor),
                  style: context.eosText.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: context.eos.spacing.xs),
            ClipRRect(
              borderRadius: EosRadius.input,
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : slice.amountMinor / total,
                minHeight: 6,
                backgroundColor: context.eosColors.surfaceContainerHighest,
                color: Color(slice.colorArgb),
              ),
            ),
            SizedBox(height: context.eos.spacing.md),
          ],
          if (total > 0)
            Text(
              'Total planned: ${formatRevenue(total)}',
              style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.end,
            ),
        ],
      ),
    );
  }
}
