import 'package:flutter/material.dart';

import '../quick_action_chip.dart';

/// Quick action chips for the home hub.
class HomeQuickActionsRow extends StatelessWidget {
  const HomeQuickActionsRow({
    super.key,
    required this.onCreateEvent,
    required this.onFindVendors,
    required this.onInviteGuests,
    required this.onAiPlanner,
  });

  final VoidCallback onCreateEvent;
  final VoidCallback onFindVendors;
  final VoidCallback onInviteGuests;
  final VoidCallback onAiPlanner;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        QuickActionChip(
          label: 'Create event',
          icon: Icons.add_circle_outline,
          emphasized: true,
          onTap: onCreateEvent,
        ),
        QuickActionChip(
          label: 'Find vendors',
          icon: Icons.storefront_outlined,
          onTap: onFindVendors,
        ),
        QuickActionChip(
          label: 'Invite guests',
          icon: Icons.mail_outline,
          onTap: onInviteGuests,
        ),
        QuickActionChip(
          label: 'AI planner',
          icon: Icons.auto_awesome_outlined,
          onTap: onAiPlanner,
        ),
      ],
    );
  }
}
