import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/invitation_template_models.dart';
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

  Future<void> _sendInvitations(BuildContext context, int guestCount) async {
    if (guestCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add guests before sending invitations.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final template = _selectedTemplate;
      if (allowMockPersistenceFallback()) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        final costNote =
            template.priceMinor > 0 ? ' (${formatRevenue(template.priceMinor)} template fee)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sending "${template.name}" invitations to $guestCount guest${guestCount == 1 ? '' : 's'}$costNote',
            ),
          ),
        );
      } else {
        final sent = await ref.read(eventGuestsApiProvider).sendInvitations(
              widget.eventId,
              channel: 'link',
              templateId: template.id,
            );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent $sent invitation${sent == 1 ? '' : 's'} via API.')),
        );
      }
      refreshInvitationHub(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send invitations. Please try again.')),
        );
      }
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
            await ref.read(customerEventInvitationProvider(widget.eventId).future);
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
                onPressed: _sending || data.guestCount == 0
                    ? null
                    : () => _sendInvitations(context, data.guestCount),
                icon: _sending
                    ? const EventModuleBusyIndicator.onButton()
                    : const Icon(Icons.send_outlined),
                label: Text(
                  data.guestCount == 0
                      ? 'Add guests to send invitations'
                      : _selectedTemplate.isPremium
                          ? 'Send with ${formatRevenue(_selectedTemplate.priceMinor)} template'
                          : 'Send invitations to ${data.guestCount} guests',
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
