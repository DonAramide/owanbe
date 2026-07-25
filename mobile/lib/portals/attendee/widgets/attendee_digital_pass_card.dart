import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../eos/eos.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/models/attendee_pass_status.dart';
import '../commerce/attendee_pass_actions.dart';
import '../navigation/attendee_routes.dart';
import 'attendee_pass_status_chip.dart';

/// Rich digital pass card — QR + admission fields for Phase 6A.
class AttendeeDigitalPassCard extends StatelessWidget {
  const AttendeeDigitalPassCard({
    super.key,
    required this.event,
    this.showActions = true,
    this.compactQr = false,
    this.onOpenEntry,
  });

  final AttendeeEventView event;
  final bool showActions;
  final bool compactQr;
  final VoidCallback? onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final payload = event.qrPayload.trim();
    final live = event.liveStatus;
    final qrSize = compactQr ? 120.0 : 168.0;

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.eventTitle, style: context.eosText.titleMedium),
                    SizedBox(height: context.eos.spacing.xxs),
                    Text(
                      '${event.tierName} · ${formatAttendeeDateRange(event.startsAt, event.endsAt)}',
                      style: context.eosText.bodySmall,
                    ),
                  ],
                ),
              ),
              AttendeePassStatusChip(status: live),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Text(live.description, style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.md),
          Center(
            child: payload.isEmpty
                ? Icon(Icons.qr_code_2, size: qrSize, color: context.eosColors.outline)
                : QrImageView(
                    data: payload,
                    size: qrSize,
                    backgroundColor: Colors.white,
                  ),
          ),
          SizedBox(height: context.eos.spacing.xs),
          SelectableText(
            event.ticket.ticketCode?.isNotEmpty == true ? event.ticket.ticketCode! : payload,
            style: context.eosText.labelSmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.eos.spacing.md),
          _InfoGrid(event: event),
          if (showActions) ...[
            SizedBox(height: context.eos.spacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onOpenEntry ??
                      () => context.push(AttendeeRoutes.entry(event.ticket.id)),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Event entry'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push(AttendeeRoutes.passDetail(event.ticket.id)),
                  icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                  label: const Text('Full pass'),
                ),
                OutlinedButton.icon(
                  onPressed: () => AttendeePassActions.shareTicket(event),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Share'),
                ),
                TextButton(
                  onPressed: () => AttendeePassActions.downloadTicket(context, event),
                  child: const Text('Save offline'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.event});

  final AttendeeEventView event;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Venue', [event.venue, event.city].where((s) => s.trim().isNotEmpty).join(', ')),
      if (event.venueAddress != null && event.venueAddress!.trim().isNotEmpty)
        ('Address', event.venueAddress!),
      ('Ticket tier', event.tierName),
      if (event.accessLevel != null && event.accessLevel!.trim().isNotEmpty)
        ('Access level', event.accessLevel!),
      if (event.seatLabel != null && event.seatLabel!.trim().isNotEmpty)
        ('Seat', event.seatLabel!),
      if (event.gateInfo != null && event.gateInfo!.trim().isNotEmpty)
        ('Gate', event.gateInfo!),
      ('Registration', event.isCancelled ? 'Inactive' : 'Registered'),
      ('Ticket status', event.entitlementStatus),
      ('Check-in', event.checkedIn ? 'Checked in' : 'Not checked in'),
      ('Attendance', event.liveStatusLabel),
      if (event.entryInstructions != null && event.entryInstructions!.trim().isNotEmpty)
        ('Entry', event.entryInstructions!),
    ];

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(row.$1, style: context.eosText.labelMedium),
                ),
                Expanded(child: Text(row.$2, style: context.eosText.bodySmall)),
              ],
            ),
          ),
      ],
    );
  }
}

class AttendeePassSwitcherBar extends StatelessWidget {
  const AttendeePassSwitcherBar({
    super.key,
    required this.siblings,
    required this.currentId,
    required this.onSelect,
  });

  final List<AttendeeEventView> siblings;
  final String currentId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (siblings.length <= 1) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your passes for this event', style: context.eosText.titleSmall),
        SizedBox(height: context.eos.spacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < siblings.length; i++)
                Padding(
                  padding: EdgeInsets.only(right: context.eos.spacing.xs),
                  child: ChoiceChip(
                    label: Text(
                      siblings[i].groupLabel?.trim().isNotEmpty == true
                          ? '${siblings[i].groupLabel} · ${i + 1}/${siblings.length}'
                          : '${siblings[i].tierName} · ${i + 1}/${siblings.length}',
                    ),
                    selected: siblings[i].ticket.id == currentId,
                    onSelected: (_) => onSelect(siblings[i].ticket.id),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
      ],
    );
  }
}
