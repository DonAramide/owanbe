import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';

class EosTrendBadge extends StatelessWidget {
  const EosTrendBadge({
    super.key,
    required this.deltaPercent,
    this.invertColors = false,
  });

  final double deltaPercent;
  final bool invertColors;

  @override
  Widget build(BuildContext context) {
    final positive = deltaPercent >= 0;
    final good = invertColors ? !positive : positive;
    final color = good ? EosColors.success : EosColors.critical;
    final icon = positive ? Icons.trending_up : Icons.trending_down;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.eos.spacing.xs,
        vertical: context.eos.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: context.eos.radius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: context.eos.spacing.xxs),
          Text(
            '${deltaPercent.abs().toStringAsFixed(1)}%',
            style: context.eosText.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
