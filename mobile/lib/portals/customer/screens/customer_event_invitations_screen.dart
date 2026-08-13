import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/event_guests_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/invitation_template_models.dart';
import '../providers/customer_guest_providers.dart';
import '../providers/customer_invitation_providers.dart';
import '../navigation/event_navigator.dart';
import '../workspace/event_module_scaffold.dart';
import '../workspace/widgets/event_error_view.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../workspace/widgets/event_module_busy_indicator.dart';
import '../widgets/guests/import_contacts_sheet.dart';
import '../widgets/invitations/invitation_preview_card.dart';
import '../widgets/invitations/invitation_qr_card.dart';
import '../widgets/invitations/invitation_share_actions.dart';
import '../widgets/invitations/invitation_stats_row.dart';
import '../widgets/invitations/invitation_template_gallery.dart';
import '../widgets/invitations/send_invitation_guest_picker_sheet.dart';
import '../widgets/section_header.dart';

/// Invitation Hub at `/events/:eventId/invitations`.
class CustomerEventInvitationsScreen extends ConsumerStatefulWidget {
  const CustomerEventInvitationsScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CustomerEventInvitationsScreen> createState() =>
      _CustomerEventInvitationsScreenState();
}

class _CustomerEventInvitationsScreenState extends ConsumerState<CustomerEventInvitationsScreen> {
  String _selectedTemplateId = kInvitationTemplates.first.id;
  var _sending = false;

  InvitationTemplate get _selectedTemplate =>
      kInvitationTemplates.firstWhere((t) => t.id == _selectedTemplateId);

  Future<void> _openSendPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SendInvitationGuestPickerSheet(
        eventId: widget.eventId,
        templateLabel: _selectedTemplate.name,
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    await _sendInvitations(selected);
  }

  Future<void> _sendInvitations(List<String> guestIds) async {
    setState(() => _sending = true);
    try {
      final template = _selectedTemplate;
      final sent = await ref.read(eventGuestsApiProvider).sendInvitations(
            widget.eventId,
            guestIds: guestIds,
            channel: 'email',
            templateId: template.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent $sent invitation${sent == 1 ? '' : 's'}'
            '${template.priceMinor > 0 ? ' (${formatRevenue(template.priceMinor)} template)' : ''}.',
          ),
        ),
      );
      refreshInvitationHub(ref);
      refreshCustomerGuests(ref);
      ref.invalidate(invitationHubPayloadProvider(widget.eventId));
      ref.invalidate(invitationStatusRowsProvider(widget.eventId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send invitations: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _importContacts(BuildContext context) async {
    final count = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ImportContactsSheet(eventId: widget.eventId),
      ),
    );
    if (count != null && count > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count contact(s). Ready to send invitations.')),
      );
      refreshInvitationHub(ref);
      refreshCustomerGuests(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = ref.watch(customerEventInvitationProvider(widget.eventId));

    return EventModuleScaffold(
      eventId: widget.eventId,
      title: 'Invitation hub',
      subtitle: 'Templates, send, and share',
      actions: [
        if (allowMockPersistenceFallback())
          IconButton(
            tooltip: 'Import phone contacts',
            onPressed: () => _importContacts(context),
            icon: const Icon(Icons.contacts_outlined),
          ),
        IconButton(
          tooltip: 'Manage guests',
          onPressed: () => context.eventNav.openGuests(widget.eventId),
          icon: const Icon(Icons.groups_outlined),
        ),
      ],
      body: hub.when(
        loading: () => const EventLoadingSkeleton(),
        error: (_, _) => ListView(
          padding: EosSpacing.pagePadding,
          children: [
            EventErrorView.module(
              moduleLabel: 'invitations',
              onRetry: () {
                refreshInvitationHub(ref);
                ref.invalidate(customerEventInvitationProvider(widget.eventId));
              },
              onBackToOverview: () => context.eventNav.backToOverview(widget.eventId),
            ),
          ],
        ),
        data: (data) => EventModuleScrollBody(
          onRefresh: () async {
            refreshInvitationHub(ref);
            refreshCustomerGuests(ref);
            ref.invalidate(invitationHubPayloadProvider(widget.eventId));
            await ref.read(customerEventInvitationProvider(widget.eventId).future);
            await ref.read(invitationStatusRowsProvider(widget.eventId).future);
          },
          hero: SectionHeader(
            title: data.event.title,
            subtitle: 'Invitation dashboard · ${data.guestCount} guests on your list',
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Invitation templates',
                subtitle: '30 photo-ready designs — classic included, plus premium 3D & 4D add-ons.',
              ),
              InvitationTemplateGallery(
                event: data.event,
                selectedId: _selectedTemplateId,
                onSelected: (template) => setState(() => _selectedTemplateId = template.id),
              ),
              InvitationTemplatePreview(event: data.event, template: _selectedTemplate),
              SizedBox(height: context.eos.spacing.md),
              FilledButton.icon(
                onPressed: _sending || data.guestCount == 0 ? null : () => _openSendPicker(context),
                icon: _sending
                    ? const EventModuleBusyIndicator.onButton()
                    : const Icon(Icons.send_outlined),
                label: Text(
                  data.guestCount == 0
                      ? 'Add guests to send invitations'
                      : _sending
                          ? 'Sending…'
                          : _selectedTemplate.isPremium
                              ? 'Choose guests · ${formatRevenue(_selectedTemplate.priceMinor)} template'
                              : 'Choose guests to invite',
                ),
              ),
              SizedBox(height: context.eos.spacing.sm),
              if (allowMockPersistenceFallback())
                OutlinedButton.icon(
                  onPressed: () => _importContacts(context),
                  icon: const Icon(Icons.contact_phone_outlined),
                  label: const Text('Import from phone contacts'),
                ),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'Statistics',
                subtitle: 'Sent, delivered, opened, and RSVP funnel.',
              ),
              InvitationStatsRow(stats: data.stats),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'Invitation status',
                subtitle: 'Live guest list — send, resend, or cancel.',
              ),
              _InvitationDeliveriesPanel(eventId: widget.eventId),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'Classic preview',
                subtitle: 'Selected template with your event photo, name, and location.',
              ),
              InvitationPreviewCard(event: data.event, template: _selectedTemplate),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'Share & QR',
                subtitle: 'Spread the word across channels.',
              ),
              InvitationShareActions(share: data.share),
              SizedBox(height: context.eos.spacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 640;
                  final qrCards = [
                    InvitationQrCard(
                      title: 'QR invitation',
                      subtitle: 'Guests scan to view your celebration invite.',
                      payload: data.share.inviteQrPayload,
                    ),
                    InvitationQrCard(
                      title: 'QR RSVP',
                      subtitle: 'Direct RSVP and ticket selection.',
                      payload: data.share.rsvpQrPayload,
                    ),
                  ];
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: qrCards[0]),
                        SizedBox(width: context.eos.spacing.md),
                        Expanded(child: qrCards[1]),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      qrCards[0],
                      SizedBox(height: context.eos.spacing.md),
                      qrCards[1],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationDeliveriesPanel extends ConsumerStatefulWidget {
  const _InvitationDeliveriesPanel({required this.eventId});

  final String eventId;

  @override
  ConsumerState<_InvitationDeliveriesPanel> createState() => _InvitationDeliveriesPanelState();
}

class _InvitationDeliveriesPanelState extends ConsumerState<_InvitationDeliveriesPanel> {
  String _filter = 'all';
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      ref.invalidate(invitationHubPayloadProvider(widget.eventId));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _act(InvitationRecord item, String action) async {
    final api = ref.read(eventGuestsApiProvider);
    try {
      if (action == 'send' || (action == 'resend' && !item.hasBeenSent)) {
        await api.sendInvitations(
          widget.eventId,
          guestIds: [item.guestId],
          channel: 'email',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invitation sent to ${item.guestEmail ?? item.guestName}')),
          );
        }
      } else if (action == 'resend') {
        await api.resendInvitation(widget.eventId, item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Resent to ${item.guestEmail ?? item.guestName}')),
          );
        }
      } else if (action == 'cancel') {
        if (!item.hasBeenSent) return;
        await api.cancelInvitation(widget.eventId, item.id);
      } else if (action == 'link') {
        final url = await api.createInviteLink(widget.eventId, item.guestId);
        if (url != null) {
          await Clipboard.setData(ClipboardData(text: url));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invite link copied')),
            );
          }
        }
      }
      refreshInvitationHub(ref);
      refreshCustomerGuests(ref);
      ref.invalidate(invitationHubPayloadProvider(widget.eventId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(invitationStatusRowsProvider(widget.eventId));

    return statusAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => EosSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$e', style: context.eosText.bodySmall),
            TextButton(
              onPressed: () => ref.invalidate(invitationHubPayloadProvider(widget.eventId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) {
        final filtered = data.rows.where((i) {
          final r = (i.rsvpStatus ?? '').toLowerCase();
          final notSent = !i.hasBeenSent;
          return switch (_filter) {
            'pending' =>
              notSent || r == 'pending' || r == 'invited' || r.isEmpty,
            'accepted' => r == 'confirmed',
            'declined' => r == 'declined',
            _ => true,
          };
        }).toList();
        final s = data.stats;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: context.eos.spacing.sm,
              runSpacing: context.eos.spacing.sm,
              children: [
                _chip(context, 'Invited', '${s.totalInvited}'),
                _chip(context, 'Awaiting', '${s.pending}'),
                _chip(context, 'Accepted', '${s.rsvp}'),
                _chip(context, 'Declined', '${s.declined}'),
                _chip(context, 'Tickets', '${s.ticketsIssued}'),
              ],
            ),
            SizedBox(height: context.eos.spacing.sm),
            Wrap(
              spacing: 8,
              children: [
                for (final f in ['all', 'pending', 'accepted', 'declined'])
                  FilterChip(
                    label: Text(f[0].toUpperCase() + f.substring(1)),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
            SizedBox(height: context.eos.spacing.sm),
            if (filtered.isEmpty)
              EosSurfaceCard(
                child: Text(
                  data.rows.isEmpty
                      ? 'No guests yet. Add guests, then choose who to invite.'
                      : 'No invitations in this filter.',
                  style: context.eosText.bodyMedium,
                ),
              )
            else
              EosSurfaceCard(
                child: Column(
                  children: [
                    for (final item in filtered)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.guestName, style: context.eosText.titleSmall),
                        subtitle: Text(
                          '${item.guestEmail ?? 'No email'} · '
                          '${item.hasBeenSent ? (item.rsvpStatus ?? item.status) : 'not sent'}'
                          '${item.ticketIssued ? ' · ticket issued' : ''}\n'
                          '${item.hasBeenSent ? 'Sent ${item.sentAt?.split('T').first ?? '—'}' : 'Waiting to send'}'
                          '${item.respondedAt != null ? ' · Responded ${item.respondedAt!.split('T').first}' : ''}',
                          style: context.eosText.bodySmall,
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) => _act(item, v),
                          itemBuilder: (_) => [
                            if (!item.hasBeenSent)
                              const PopupMenuItem(value: 'send', child: Text('Send invite')),
                            if (item.hasBeenSent)
                              const PopupMenuItem(value: 'resend', child: Text('Resend')),
                            const PopupMenuItem(value: 'link', child: Text('Copy invite link')),
                            if (item.hasBeenSent)
                              const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _chip(BuildContext context, String label, String value) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.eosText.bodySmall),
            Text(value, style: context.eosText.titleSmall),
          ],
        ),
      ),
    );
  }
}
