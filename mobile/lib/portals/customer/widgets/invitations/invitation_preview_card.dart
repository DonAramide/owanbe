import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../../../features/organizer/models/organizer_models.dart';
import '../../models/home_hub_models.dart';
import '../../models/invitation_template_models.dart';
import 'invitation_card_renderer.dart';

class InvitationPreviewCard extends StatelessWidget {
  const InvitationPreviewCard({
    super.key,
    required this.event,
    this.template,
  });

  final OrganizerEvent event;
  final InvitationTemplate? template;

  @override
  Widget build(BuildContext context) {
    final activeTemplate = template ?? kInvitationTemplates.first;
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: InvitationCardRenderer(
              template: activeTemplate,
              event: event,
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          Text(
            event.tagline.isNotEmpty ? event.tagline : event.category,
            style: context.eosText.bodyMedium,
          ),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            '${formatEventDate(event.startsAt)} · ${event.venue}, ${event.city}',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.md),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.celebration_outlined),
            label: const Text('RSVP to celebrate'),
          ),
        ],
      ),
    );
  }
}
