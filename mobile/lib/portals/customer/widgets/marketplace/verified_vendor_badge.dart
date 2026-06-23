import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';

class VerifiedVendorBadge extends StatelessWidget {
  const VerifiedVendorBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? context.eos.spacing.xs : context.eos.spacing.sm,
        vertical: context.eos.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: EosColors.successSoft,
        borderRadius: EosRadius.chip,
        border: Border.all(color: EosColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: compact ? 14 : 16, color: EosColors.success),
          SizedBox(width: context.eos.spacing.xxs),
          Text(
            'Verified',
            style: context.eosText.labelSmall?.copyWith(
              color: EosColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
