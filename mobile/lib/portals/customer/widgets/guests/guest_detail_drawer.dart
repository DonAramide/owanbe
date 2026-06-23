import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../../../features/operations/models/operations_models.dart';
import '../../../../features/operations/providers/operations_providers.dart';
import '../../models/customer_guest_models.dart';
import '../../providers/customer_guest_providers.dart';
import 'guest_rsvp_chip.dart';

class GuestDetailDrawer extends ConsumerWidget {
  const GuestDetailDrawer({
    super.key,
    required this.eventId,
    required this.guest,
    required this.onClose,
  });

  final String eventId;
  final CustomerGuestView guest;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Guest details', style: context.eosText.titleLarge),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
            SizedBox(height: context.eos.spacing.lg),
            CircleAvatar(
              radius: 32,
              backgroundColor: context.eosColors.primaryContainer,
              child: Text(
                guest.name.isNotEmpty ? guest.name[0].toUpperCase() : '?',
                style: context.eosText.headlineSmall?.copyWith(color: context.eosColors.primary),
              ),
            ),
            SizedBox(height: context.eos.spacing.md),
            Text(guest.name, style: context.eosText.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text(guest.email, style: context.eosText.bodyMedium),
            SizedBox(height: context.eos.spacing.md),
            Wrap(
              spacing: context.eos.spacing.sm,
              runSpacing: context.eos.spacing.sm,
              children: [
                GuestRsvpChip(status: guest.rsvpStatus),
                EosCheckinStatus(checkedIn: guest.checkedIn),
                if (guest.tier == GuestTier.vip || guest.tier == GuestTier.vvip)
                  EosFinanceChip(
                    label: guest.tier == GuestTier.vvip ? 'vvip' : 'vip',
                    compact: true,
                  ),
              ],
            ),
            SizedBox(height: context.eos.spacing.lg),
            _DetailRow(label: 'Tier', value: guest.tierName),
            if (guest.ticketId.isNotEmpty) _DetailRow(label: 'Ticket', value: guest.ticketId),
            if (guest.purchasedAt != null)
              _DetailRow(label: 'RSVP date', value: '${guest.purchasedAt!.toLocal()}'.split('.').first),
            if (guest.checkedInAt != null)
              _DetailRow(label: 'Checked in at', value: '${guest.checkedInAt!.toLocal()}'.split('.').first),
            if (guest.timeline.isNotEmpty) ...[
              SizedBox(height: context.eos.spacing.lg),
              Text('Activity', style: context.eosText.titleSmall),
              SizedBox(height: context.eos.spacing.sm),
              for (final item in guest.timeline)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timeline, size: 18),
                  title: Text(item.label),
                  subtitle: Text('${item.at.toLocal()}'.split('.').first),
                ),
            ],
            SizedBox(height: context.eos.spacing.xl),
            if (!guest.checkedIn)
              FilledButton.icon(
                onPressed: () async {
                  await performManualCheckIn(ref, eventId, guest.toOpsGuest());
                  refreshCustomerGuests(ref);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${guest.name} checked in')),
                    );
                  }
                },
                icon: const Icon(Icons.how_to_reg_outlined),
                label: const Text('Check in guest'),
              ),
            SizedBox(height: context.eos.spacing.sm),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invitation resent to ${guest.email}')),
                );
              },
              icon: const Icon(Icons.mail_outline),
              label: const Text('Resend invitation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: context.eosText.labelSmall)),
          Expanded(child: Text(value, style: context.eosText.bodyMedium)),
        ],
      ),
    );
  }
}
