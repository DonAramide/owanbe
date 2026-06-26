import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';

class VendorStageBadge extends StatelessWidget {
  const VendorStageBadge({super.key, required this.stage});

  final String stage;

  Color _color(BuildContext context) => switch (stage) {
        'negotiating' => EosColors.plum,
        'accepted' => Colors.teal.shade700,
        'scheduled' => Colors.indigo,
        'arrived' => Colors.green.shade700,
        'completed' => Colors.blueGrey,
        'declined' || 'cancelled' => EosColors.critical,
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final label = switch (stage) {
      'new' => 'New',
      'negotiating' => 'Negotiating',
      'accepted' => 'Accepted',
      'scheduled' => 'Scheduled',
      'arrived' => 'Arrived',
      'completed' => 'Completed',
      'declined' => 'Declined',
      'cancelled' => 'Cancelled',
      _ => stage,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
