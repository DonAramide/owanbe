import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../eos/eos.dart';
import '../../models/invitation_hub_models.dart';

class InvitationShareActions extends StatelessWidget {
  const InvitationShareActions({
    super.key,
    required this.share,
  });

  final InvitationShareTargets share;

  Future<void> _copy(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EosSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share link', style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: context.eos.spacing.xs),
              SelectableText(share.rsvpPageUrl, style: context.eosText.bodySmall),
              SizedBox(height: context.eos.spacing.sm),
              FilledButton.icon(
                onPressed: () => _copy(context, share.rsvpPageUrl, 'RSVP link'),
                icon: const Icon(Icons.link),
                label: const Text('Copy share link'),
              ),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        Wrap(
          spacing: context.eos.spacing.sm,
          runSpacing: context.eos.spacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: () => _copy(context, share.whatsappMessage, 'WhatsApp message'),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('WhatsApp share'),
            ),
            OutlinedButton.icon(
              onPressed: () => _copy(
                context,
                'mailto:?subject=${Uri.encodeComponent(share.emailSubject)}&body=${Uri.encodeComponent(share.emailBody)}',
                'Email draft link',
              ),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Email share'),
            ),
            OutlinedButton.icon(
              onPressed: () => _copy(context, share.eventPageUrl, 'Event page link'),
              icon: const Icon(Icons.public),
              label: const Text('Event page'),
            ),
          ],
        ),
      ],
    );
  }
}
