import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';

/// Status chip for finance / payout / reconciliation states.
class EosFinanceChip extends StatelessWidget {
  const EosFinanceChip({super.key, required this.label, this.compact = false});

  final String label;
  final bool compact;

  static (Color bg, Color fg) _colorsFor(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('fail') || s.contains('critical') || s.contains('frozen')) {
      return (EosColors.criticalSoft, EosColors.critical);
    }
    if (s.contains('review') || s.contains('warn') || s.contains('pending') || s.contains('processing')) {
      return (EosColors.warningSoft, EosColors.warning);
    }
    if (s.contains('complete') || s.contains('captured') || s.contains('success') || s.contains('normal')) {
      return (EosColors.successSoft, EosColors.success);
    }
    if (s.contains('open') || s.contains('mismatch')) {
      return (EosColors.infoSoft, EosColors.info);
    }
    return (EosColors.slate100, EosColors.slate700);
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colorsFor(label);
    final textStyle = compact ? context.eosText.labelSmall : context.eosText.labelMedium;

    return Semantics(
      label: 'Status $label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? context.eos.spacing.xs : context.eos.spacing.sm,
          vertical: compact ? 2 : context.eos.spacing.xxs,
        ),
        decoration: BoxDecoration(color: bg, borderRadius: context.eos.radius.chip),
        child: Text(
          label.replaceAll('_', ' ').toUpperCase(),
          style: textStyle?.copyWith(color: fg, letterSpacing: 0.4),
        ),
      ),
    );
  }
}
