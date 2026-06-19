import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';

class EosVendorTierChip extends StatelessWidget {
  const EosVendorTierChip({super.key, required this.tier});

  final String tier;

  @override
  Widget build(BuildContext context) {
    final t = tier.toLowerCase();
    final (bg, fg) = switch (t) {
      'premium' || 'verified' => (EosColors.champagneLight, EosColors.plumDark),
      'active' => (EosColors.successSoft, EosColors.success),
      'pending' || 'draft' => (EosColors.warningSoft, EosColors.warning),
      _ => (EosColors.slate100, EosColors.slate700),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.xs, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: context.eos.radius.chip),
      child: Text(tier.toUpperCase(), style: context.eosText.labelSmall?.copyWith(color: fg)),
    );
  }
}
