import 'package:flutter/material.dart';

import '../quick_action_chip.dart';

class CommandQuickActions extends StatelessWidget {
  const CommandQuickActions({
    super.key,
    required this.onInviteGuests,
    required this.onFindVendors,
    required this.onEventDay,
  });

  final VoidCallback onInviteGuests;
  final VoidCallback onFindVendors;
  final VoidCallback onEventDay;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        QuickActionChip(
          label: 'Invite guests',
          icon: Icons.mail_outline,
          emphasized: true,
          onTap: onInviteGuests,
        ),
        QuickActionChip(
          label: 'Find vendors',
          icon: Icons.storefront_outlined,
          onTap: onFindVendors,
        ),
        QuickActionChip(
          label: 'Open event day',
          icon: Icons.sensors_outlined,
          onTap: onEventDay,
        ),
      ],
    );
  }
}
