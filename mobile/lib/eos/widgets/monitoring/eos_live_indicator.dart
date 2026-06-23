import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';
import 'eos_status_pulse.dart';

class EosLiveIndicator extends StatelessWidget {
  const EosLiveIndicator({super.key, this.label = 'Live', this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const EosStatusPulse(color: EosColors.live),
        if (!compact) ...[
          SizedBox(width: context.eos.spacing.xs),
          Text(label, style: context.eosText.labelMedium?.copyWith(color: EosColors.live)),
        ],
      ],
    );
  }
}
