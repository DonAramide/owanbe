import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';

class EosAttendeeChip extends StatelessWidget {
  const EosAttendeeChip({
    super.key,
    required this.name,
    this.ticketType,
    this.compact = false,
  });

  final String name;
  final String? ticketType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? context.eos.spacing.xs : context.eos.spacing.sm,
        vertical: context.eos.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: EosColors.slate100,
        borderRadius: context.eos.radius.chip,
        border: Border.all(color: context.eosColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: compact ? 10 : 12,
            backgroundColor: context.eosColors.primaryContainer,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: context.eosText.labelSmall?.copyWith(color: context.eosColors.primary, fontSize: compact ? 10 : 11),
            ),
          ),
          SizedBox(width: context.eos.spacing.xs),
          Text(name, style: compact ? context.eosText.labelSmall : context.eosText.labelMedium),
          if (ticketType != null) ...[
            SizedBox(width: context.eos.spacing.xs),
            Text('· $ticketType', style: context.eosText.labelSmall),
          ],
        ],
      ),
    );
  }
}
