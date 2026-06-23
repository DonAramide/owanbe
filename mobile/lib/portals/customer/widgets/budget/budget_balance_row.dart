import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';

class BudgetBalanceRow extends StatelessWidget {
  const BudgetBalanceRow({
    super.key,
    required this.committedMinor,
    required this.remainingMinor,
  });

  final int committedMinor;
  final int remainingMinor;

  @override
  Widget build(BuildContext context) {
    final isOver = remainingMinor < 0;

    return Row(
      children: [
        Expanded(
          child: EosSurfaceCard(
            accentColor: EosColors.plum,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments_outlined, size: 18, color: context.eosColors.primary),
                    SizedBox(width: context.eos.spacing.xs),
                    Text('Committed spend', style: context.eosText.labelSmall),
                  ],
                ),
                SizedBox(height: context.eos.spacing.sm),
                Text(
                  formatRevenue(committedMinor),
                  style: context.eosText.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: context.eos.spacing.md),
        Expanded(
          child: EosSurfaceCard(
            accentColor: isOver ? EosColors.critical : EosColors.success,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isOver ? Icons.trending_up : Icons.savings_outlined,
                      size: 18,
                      color: isOver ? EosColors.critical : EosColors.success,
                    ),
                    SizedBox(width: context.eos.spacing.xs),
                    Text('Remaining balance', style: context.eosText.labelSmall),
                  ],
                ),
                SizedBox(height: context.eos.spacing.sm),
                Text(
                  isOver ? formatRevenue(0) : formatRevenue(remainingMinor),
                  style: context.eosText.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isOver ? EosColors.critical : null,
                  ),
                ),
                if (isOver)
                  Text('Over by ${formatRevenue(-remainingMinor)}', style: context.eosText.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
