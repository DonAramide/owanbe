import 'package:flutter/material.dart';

import '../../../eos/eos.dart';

/// Tappable chip for quick actions on customer surfaces.
class QuickActionChip extends StatelessWidget {
  const QuickActionChip({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final bg = emphasized
        ? context.eosColors.primary
        : context.eosColors.primaryContainer.withValues(alpha: 0.55);
    final fg = emphasized ? Colors.white : context.eosColors.onPrimaryContainer;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: EosRadius.chip,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: context.eos.spacing.md,
            vertical: context.eos.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: EosRadius.chip,
            border: Border.all(
              color: emphasized
                  ? context.eosColors.primary
                  : context.eosColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              SizedBox(width: context.eos.spacing.xs),
              Text(
                label,
                style: context.eosText.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
