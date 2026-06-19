import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';

class EosEventStatusBadge extends StatelessWidget {
  const EosEventStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final (bg, fg, label) = switch (s) {
      'live' || 'in_progress' => (EosColors.successSoft, EosColors.live, 'LIVE'),
      'upcoming' || 'confirmed' => (EosColors.infoSoft, EosColors.info, 'UPCOMING'),
      'completed' => (EosColors.slate100, EosColors.slate700, 'ENDED'),
      'cancelled' => (EosColors.criticalSoft, EosColors.critical, 'CANCELLED'),
      _ => (EosColors.warningSoft, EosColors.warning, status.toUpperCase()),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.eos.spacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: context.eos.radius.chip),
      child: Text(label, style: context.eosText.labelSmall?.copyWith(color: fg)),
    );
  }
}
