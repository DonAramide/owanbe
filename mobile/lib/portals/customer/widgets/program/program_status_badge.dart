import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/program_constants.dart';

class ProgramStatusBadge extends StatelessWidget {
  const ProgramStatusBadge({super.key, required this.status});

  final String status;

  Color _color(BuildContext context) => switch (status) {
        'ready' => EosColors.plum,
        'in_progress' => Colors.green.shade700,
        'completed' => Colors.blueGrey,
        'skipped' => Theme.of(context).colorScheme.outline,
        'delayed' => EosColors.critical,
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final label = programStatusLabels[status] ?? status;
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
