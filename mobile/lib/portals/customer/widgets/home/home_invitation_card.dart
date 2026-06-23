import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/home_hub_models.dart';

/// Card for an upcoming invitation or ticketed event the user attends.
class HomeInvitationCard extends StatelessWidget {
  const HomeInvitationCard({
    super.key,
    required this.invitation,
    this.onTap,
  });

  final CustomerInvitationCard invitation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = invitation.kind == CustomerInvitationKind.ticket
        ? Icons.confirmation_number_outlined
        : Icons.mail_outline;

    return SizedBox(
      width: 260,
      child: EosSurfaceCard(
        onTap: onTap,
        accentColor: EosColors.champagne,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.eosColors.primaryContainer,
                borderRadius: EosRadius.input,
              ),
              child: Icon(icon, color: context.eosColors.primary),
            ),
            SizedBox(width: context.eos.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invitation.eventTitle,
                    style: context.eosText.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: context.eos.spacing.xxs),
                  Text(formatEventDate(invitation.startsAt), style: context.eosText.labelSmall),
                  Text(
                    '${invitation.city} · ${invitation.venue}',
                    style: context.eosText.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
