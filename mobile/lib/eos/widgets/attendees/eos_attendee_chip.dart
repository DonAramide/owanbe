import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';
import '../../../profile/widgets/profile_network_avatar.dart';

class EosAttendeeChip extends StatelessWidget {
  const EosAttendeeChip({
    super.key,
    required this.name,
    this.ticketType,
    this.compact = false,
    this.avatarUrl,
    this.onTap,
  });

  final String name;
  final String? ticketType;
  final bool compact;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
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
          ProfileNetworkAvatar(
            name: name,
            avatarUrl: avatarUrl,
            radius: compact ? 10 : 12,
            backgroundColor: context.eosColors.primaryContainer,
            foregroundColor: context.eosColors.primary,
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

    if (onTap == null) return chip;
    return Tooltip(
      message: 'View profile',
      child: InkWell(
        onTap: onTap,
        borderRadius: context.eos.radius.chip,
        child: chip,
      ),
    );
  }
}
