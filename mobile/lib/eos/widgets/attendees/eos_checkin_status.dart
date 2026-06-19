import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';

class EosCheckinStatus extends StatelessWidget {
  const EosCheckinStatus({super.key, required this.checkedIn, this.checkedInAt});

  final bool checkedIn;
  final String? checkedInAt;

  @override
  Widget build(BuildContext context) {
    final color = checkedIn ? EosColors.success : EosColors.slate500;
    final label = checkedIn ? 'Checked in' : 'Not checked in';

    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(checkedIn ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: color),
          SizedBox(width: context.eos.spacing.xxs),
          Text(
            checkedInAt != null ? '$label · $checkedInAt' : label,
            style: context.eosText.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
