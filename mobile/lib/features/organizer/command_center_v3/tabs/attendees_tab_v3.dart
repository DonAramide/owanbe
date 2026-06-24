import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../eos/eos.dart';
import '../../../../portals/customer/widgets/guests/import_contacts_sheet.dart';
import '../../data/organizer_persistence.dart';
import '../../models/organizer_models.dart';
import '../../providers/organizer_providers.dart';
import '../models/event_command_center_v3_models.dart';
import '../providers/event_command_center_v3_providers.dart';
import '../widgets/cc_v3_health_cards.dart';

final _guestGroupFilterProvider = StateProvider.autoDispose<GuestGroup?>((ref) => null);
final _guestStatusFilterProvider = StateProvider.autoDispose<GuestRsvpStatus?>((ref) => null);

class AttendeesTabV3 extends ConsumerWidget {
  const AttendeesTabV3({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(eventCommandCenterV3Provider(eventId));
    final query = ref.watch(attendeeSearchQueryProvider).toLowerCase();
    final groupFilter = ref.watch(_guestGroupFilterProvider);
    final statusFilter = ref.watch(_guestStatusFilterProvider);

    return snapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (snap) {
        final event = snap.event;
        var guests = event.attendees.asMap().entries.toList();
        if (query.isNotEmpty) {
          guests = guests
              .where((e) =>
                  e.value.name.toLowerCase().contains(query) ||
                  e.value.email.toLowerCase().contains(query))
              .toList();
        }
        if (groupFilter != null) {
          guests = guests.where((e) => guestGroupFor(e.value, e.key) == groupFilter).toList();
        }
        if (statusFilter != null) {
          guests = guests.where((e) => guestRsvpStatus(e.value) == statusFilter).toList();
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CcV3HealthCard(
                title: 'Guest list health',
                progressPercent: snap.guestHealth.responsePercent,
                metrics: [
                  CcV3MetricItem(label: 'Invited', value: '${snap.guestHealth.invited}'),
                  CcV3MetricItem(label: 'Accepted', value: '${snap.guestHealth.rsvpAccepted}'),
                  CcV3MetricItem(label: 'Pending', value: '${snap.guestHealth.rsvpPending}'),
                  CcV3MetricItem(label: 'Checked in', value: '${snap.guestHealth.checkedIn}'),
                ],
              ),
              SizedBox(height: context.eos.spacing.lg),
              const CcV3SectionHeader(
                title: 'Import guests',
                subtitle: 'Phone contacts, CSV, or Google Contacts',
              ),
              Wrap(
                spacing: context.eos.spacing.sm,
                runSpacing: context.eos.spacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: () => _importContacts(context, eventId),
                    icon: const Icon(Icons.contact_phone_outlined, size: 18),
                    label: const Text('Import from device contacts'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _stubAction(context, 'CSV upload'),
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Upload CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _stubAction(context, 'Google Contacts'),
                    icon: const Icon(Icons.contacts_outlined, size: 18),
                    label: const Text('Google Contacts'),
                  ),
                ],
              ),
              SizedBox(height: context.eos.spacing.lg),
              const CcV3SectionHeader(title: 'Guest groups'),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: GuestGroup.values.length + 1,
                  separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.xs),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return FilterChip(
                        label: const Text('All'),
                        selected: groupFilter == null,
                        onSelected: (_) => ref.read(_guestGroupFilterProvider.notifier).state = null,
                      );
                    }
                    final g = GuestGroup.values[index - 1];
                    return FilterChip(
                      label: Text(g.label),
                      selected: groupFilter == g,
                      onSelected: (_) => ref.read(_guestGroupFilterProvider.notifier).state = g,
                    );
                  },
                ),
              ),
              SizedBox(height: context.eos.spacing.md),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: GuestRsvpStatus.values.length + 1,
                  separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.xs),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return FilterChip(
                        label: const Text('All statuses'),
                        selected: statusFilter == null,
                        onSelected: (_) => ref.read(_guestStatusFilterProvider.notifier).state = null,
                      );
                    }
                    final s = GuestRsvpStatus.values[index - 1];
                    return FilterChip(
                      label: Text(_statusLabel(s)),
                      selected: statusFilter == s,
                      onSelected: (_) => ref.read(_guestStatusFilterProvider.notifier).state = s,
                    );
                  },
                ),
              ),
              SizedBox(height: context.eos.spacing.md),
              EosTextField(
                label: 'Search guests',
                hint: 'Name or email',
                onChanged: (v) => ref.read(attendeeSearchQueryProvider.notifier).state = v,
              ),
              SizedBox(height: context.eos.spacing.lg),
              const CcV3SectionHeader(title: 'Your guests', subtitle: 'Tap for communication options'),
              if (guests.isEmpty)
                EosSurfaceCard(child: Text('No guests match your filters.', style: context.eosText.bodyMedium))
              else
                for (final entry in guests)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                    child: _GuestCard(
                      guest: entry.value,
                      group: guestGroupFor(entry.value, entry.key),
                      status: guestRsvpStatus(entry.value),
                      onCheckIn: () => _checkIn(ref, eventId, entry.value.id),
                      onInvite: () => context.push('/events/$eventId/invitations'),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(GuestRsvpStatus s) => switch (s) {
        GuestRsvpStatus.invited => 'Invited',
        GuestRsvpStatus.accepted => 'RSVP yes',
        GuestRsvpStatus.pending => 'Pending',
        GuestRsvpStatus.declined => 'Declined',
        GuestRsvpStatus.checkedIn => 'Checked in',
      };

  Future<void> _importContacts(BuildContext context, String eventId) async {
    final count = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: ImportContactsSheet(eventId: eventId),
      ),
    );
    if (count != null && count > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count contact(s)')),
      );
    }
  }

  void _stubAction(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — connect your account in Settings')),
    );
  }

  Future<void> _checkIn(WidgetRef ref, String eventId, String guestId) async {
    await updateAttendee(ref, eventId, (e) {
      final attendees = e.attendees.map((x) => x.id == guestId ? x.copyWith(checkedIn: true) : x).toList();
      return e.copyWith(attendees: attendees);
    });
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({
    required this.guest,
    required this.group,
    required this.status,
    required this.onCheckIn,
    required this.onInvite,
  });

  final OrganizerAttendee guest;
  final GuestGroup group;
  final GuestRsvpStatus status;
  final VoidCallback onCheckIn;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: EosColors.champagne.withValues(alpha: 0.4),
                child: Text(guest.name.isNotEmpty ? guest.name[0].toUpperCase() : '?'),
              ),
              SizedBox(width: context.eos.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(guest.name, style: context.eosText.titleSmall),
                    Text('${group.label} · ${guest.email}', style: context.eosText.bodySmall),
                  ],
                ),
              ),
              EosFinanceChip(label: _statusLabel(status), compact: true),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Wrap(
            spacing: context.eos.spacing.xs,
            children: [
              _CommButton(icon: Icons.sms_outlined, label: 'SMS', onTap: () => _toast(context, 'SMS')),
              _CommButton(icon: Icons.chat_outlined, label: 'WhatsApp', onTap: () => _toast(context, 'WhatsApp')),
              _CommButton(icon: Icons.email_outlined, label: 'Email', onTap: () => _toast(context, 'Email')),
              _CommButton(icon: Icons.card_giftcard_outlined, label: 'Invitation', onTap: onInvite),
              if (!guest.checkedIn)
                _CommButton(icon: Icons.qr_code_scanner, label: 'Check in', onTap: onCheckIn),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(GuestRsvpStatus s) => switch (s) {
        GuestRsvpStatus.invited => 'Invited',
        GuestRsvpStatus.accepted => 'RSVP yes',
        GuestRsvpStatus.pending => 'Pending',
        GuestRsvpStatus.declined => 'Declined',
        GuestRsvpStatus.checkedIn => 'Checked in',
      };

  void _toast(BuildContext context, String channel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Send $channel to ${guest.name}')),
    );
  }
}

class _CommButton extends StatelessWidget {
  const _CommButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }
}
