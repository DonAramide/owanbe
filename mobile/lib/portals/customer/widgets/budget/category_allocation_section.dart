import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../models/budget_dashboard_models.dart';

class CategoryAllocationSection extends StatelessWidget {
  const CategoryAllocationSection({super.key, required this.categories});

  final List<CategoryAllocation> categories;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in categories)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.category.label,
                          style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        formatRevenue(item.committedMinor),
                        style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  SizedBox(height: context.eos.spacing.xxs),
                  Text(
                    'Allocated ${formatRevenue(item.allocatedMinor)}',
                    style: context.eosText.bodySmall,
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                  ClipRRect(
                    borderRadius: EosRadius.chip,
                    child: LinearProgressIndicator(
                      value: item.allocatedMinor == 0
                          ? 0
                          : (item.committedMinor / item.allocatedMinor).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: context.eosColors.surfaceContainerHighest,
                      color: item.utilization > 1 ? EosColors.critical : context.eosColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
