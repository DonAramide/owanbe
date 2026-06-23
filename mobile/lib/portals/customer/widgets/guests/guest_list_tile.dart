import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../../../features/operations/models/operations_models.dart';
import '../../models/customer_guest_models.dart';
import 'guest_rsvp_chip.dart';

class GuestListTile extends StatelessWidget {
  const GuestListTile({
    super.key,
    required this.guest,
    required this.onTap,
  });

  final CustomerGuestView guest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      onTap: onTap,
      elevated: true,
      accentColor: guest.tier == GuestTier.vvip
          ? EosColors.champagne
          : guest.tier == GuestTier.vip
              ? context.eosColors.primary
              : null,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: context.eosColors.primaryContainer,
            child: Text(
              guest.name.isNotEmpty ? guest.name[0].toUpperCase() : '?',
              style: context.eosText.titleSmall?.copyWith(color: context.eosColors.primary),
            ),
          ),
          SizedBox(width: context.eos.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guest.name, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: context.eos.spacing.xxs),
                Text('${guest.tierName} · ${guest.email}', style: context.eosText.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GuestRsvpChip(status: guest.rsvpStatus),
              SizedBox(height: context.eos.spacing.xs),
              EosCheckinStatus(checkedIn: guest.checkedIn),
            ],
          ),
        ],
      ),
    );
  }
}
