import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../features/public/data/recently_viewed_events_store.dart';
import '../../../features/public/data/saved_events_store.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/models/public_models.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../features/public/providers/public_providers.dart';
import '../../../features/public/utils/event_detail_actions.dart';
import '../../../features/public/widgets/attendee_event_card.dart';
import '../../../features/public/widgets/discover_event_rail.dart';
import '../../../features/public/widgets/event_detail_gallery.dart';
import '../../../features/public/widgets/public_event_hero.dart';
import '../../../portals/customer/models/program_models.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_event_commerce_provider.dart';
import '../widgets/attendee_flow_scaffold.dart';

/// Canonical attendee event detail — decision screen with interactive sections only.
class AttendeeEventDetailScreen extends ConsumerWidget {
  const AttendeeEventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commerceAsync = ref.watch(attendeeEventCommerceProvider(eventId));
    final hasTicket = ref.watch(attendeeHasTicketProvider(eventId));
    final myEvent = ref
        .watch(attendeeEventsProvider)
        .valueOrNull
        ?.where((e) => e.eventId == eventId)
        .firstOrNull;
    final offline = ref.watch(attendeeOfflineProvider);
    final saved = ref.watch(isEventSavedProvider(eventId));

    return AttendeeFlowScaffold(
      backLabel: 'Back',
      onBack: () => _back(context),
      body: commerceAsync.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => _DetailError(
          message: '$e',
          offline: offline,
          onRetry: () => ref.invalidate(attendeeEventCommerceProvider(eventId)),
        ),
        data: (commerce) {
          if (commerce == null) {
            return Center(
              child: EosSurfaceCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Event not found', style: context.eosText.titleMedium),
                    SizedBox(height: context.eos.spacing.sm),
                    Text(
                      'This celebration may be private or no longer published.',
                      style: context.eosText.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    FilledButton(onPressed: () => _back(context), child: const Text('Back to Discover')),
                  ],
                ),
              ),
            );
          }

          final event = commerce.event;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            recordEventViewed(ref, eventId);
          });

          final gallery = event.resolvedGallery;
          final organizerLabel = (event.organizerName?.trim().isNotEmpty ?? false)
              ? event.organizerName!.trim()
              : commerce.organizerLabel;
          final address = (event.venueAddress?.trim().isNotEmpty ?? false)
              ? event.venueAddress!.trim()
              : commerce.venueAddress;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(attendeeEventCommerceProvider(eventId));
              ref.invalidate(publicEventProgramProvider(eventId));
              ref.invalidate(publicEventCatalogProvider);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(context.eos.spacing.lg),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 920 : double.infinity),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (offline)
                          Padding(
                            padding: EdgeInsets.only(bottom: context.eos.spacing.md),
                            child: EosSurfaceCard(
                              accentColor: EosColors.warning,
                              child: Text(
                                'You appear offline. Showing cached event data where available.',
                                style: context.eosText.bodySmall,
                              ),
                            ),
                          ),
                        PublicEventHero(
                          event: event,
                          onCta: hasTicket
                              ? () => _showQr(context, event, myEvent)
                              : () => context.push(AttendeeRoutes.eventTickets(eventId)),
                          ctaLabel: hasTicket ? 'Show my ticket' : 'Select tickets',
                        ),
                        SizedBox(height: context.eos.spacing.md),
                        _ActionBar(
                          saved: saved,
                          onSave: () async {
                            final nowSaved = await toggleSavedEvent(ref, eventId);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(nowSaved ? 'Event saved' : 'Removed from saved')),
                            );
                          },
                          onShare: () async {
                            final link = Uri.base.replace(fragment: AttendeeRoutes.eventDetail(eventId)).toString();
                            await EventDetailActions.shareEvent(event, deepLink: link);
                          },
                          onCalendar: () => EventDetailActions.addToCalendar(event),
                          onContact: () async {
                            try {
                              await EventDetailActions.contactOrganizer(
                                email: event.organizerContactEmail,
                                phone: event.organizerContactPhone,
                                eventTitle: event.title,
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          },
                          onReport: () => _showReportSheet(context, ref, event),
                        ),
                        SizedBox(height: context.eos.spacing.xl),
                        if (hasTicket && myEvent != null) ...[
                          EosSection(
                            title: 'Your ticket',
                            subtitle: 'You are registered for this celebration',
                            child: AttendeeEventCard(
                              event: myEvent,
                              onShowQr: () => showAttendeeQrSheet(context, myEvent),
                            ),
                          ),
                          if (myEvent.isPast) ...[
                            SizedBox(height: context.eos.spacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    context.push(AttendeeRoutes.eventRecap(eventId)),
                                icon: const Icon(Icons.auto_stories_outlined, size: 18),
                                label: const Text('Open event recap'),
                              ),
                            ),
                          ],
                          SizedBox(height: context.eos.spacing.xl),
                        ],
                        EosSection(
                          title: 'About this event',
                          child: Text(event.description, style: context.eosText.bodyLarge),
                        ),
                        SizedBox(height: context.eos.spacing.lg),
                        EosSection(
                          title: 'Event details',
                          child: EosSurfaceCard(
                            child: Column(
                              children: [
                                _InfoRow(icon: Icons.schedule, label: 'Date & time', value: _when(event)),
                                Divider(height: context.eos.spacing.lg),
                                _InfoRow(
                                  icon: Icons.place_outlined,
                                  label: 'Venue',
                                  value: event.venue,
                                  onTap: () => EventDetailActions.openDirections(event),
                                ),
                                if (address != null) ...[
                                  Divider(height: context.eos.spacing.lg),
                                  _InfoRow(
                                    icon: Icons.map_outlined,
                                    label: 'Location',
                                    value: address,
                                    onTap: () => EventDetailActions.openDirections(event),
                                  ),
                                ],
                                Divider(height: context.eos.spacing.lg),
                                _InfoRow(icon: Icons.location_city_outlined, label: 'City', value: event.city),
                                Divider(height: context.eos.spacing.lg),
                                _InfoRow(icon: Icons.storefront_outlined, label: 'Organizer', value: organizerLabel),
                                Divider(height: context.eos.spacing.lg),
                                _InfoRow(icon: Icons.category_outlined, label: 'Category', value: event.category),
                                Divider(height: context.eos.spacing.lg),
                                _InfoRow(
                                  icon: Icons.videocam_outlined,
                                  label: 'Format',
                                  value: event.venueType[0].toUpperCase() + event.venueType.substring(1),
                                ),
                                Divider(height: context.eos.spacing.lg),
                                _InfoRow(
                                  icon: Icons.people_outline,
                                  label: 'Attending',
                                  value: '${event.attendeeCount ?? 0}+ guests',
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: context.eos.spacing.lg),
                        _LocationSection(event: event),
                        SizedBox(height: context.eos.spacing.lg),
                        EosSection(
                          title: 'Tickets & pricing',
                          subtitle: commerce.hasTicketAvailability
                              ? '${commerce.totalTicketsRemaining} tickets available across ${event.ticketTiers.length} tiers'
                              : 'Currently sold out — check back later',
                          child: event.ticketTiers.isEmpty
                              ? EosSurfaceCard(
                                  child: Text(
                                    'No public ticket tiers are listed yet.',
                                    style: context.eosText.bodyMedium,
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (final tier in event.ticketTiers) ...[
                                      _TierSummaryRow(tier: tier),
                                      if (tier != event.ticketTiers.last)
                                        SizedBox(height: context.eos.spacing.sm),
                                    ],
                                  ],
                                ),
                        ),
                        if (gallery.isNotEmpty) ...[
                          SizedBox(height: context.eos.spacing.lg),
                          EventDetailGallerySection(items: gallery),
                        ],
                        SizedBox(height: context.eos.spacing.lg),
                        _AgendaSection(eventId: eventId),
                        if (event.speakers.isNotEmpty) ...[
                          SizedBox(height: context.eos.spacing.lg),
                          _SpeakersSection(speakers: event.speakers),
                        ],
                        if (event.sponsors.isNotEmpty) ...[
                          SizedBox(height: context.eos.spacing.lg),
                          _SponsorsSection(sponsors: event.sponsors),
                        ],
                        if (event.faqs.isNotEmpty) ...[
                          SizedBox(height: context.eos.spacing.lg),
                          _FaqsSection(faqs: event.faqs),
                        ],
                        SizedBox(height: context.eos.spacing.lg),
                        DiscoverAsyncRail(
                          title: 'Similar Events',
                          subtitle: 'Based on this celebration',
                          asyncEvents: ref.watch(eventDetailSimilarProvider(eventId)),
                          onEventTap: (e) => context.push(AttendeeRoutes.eventDetail(e.id)),
                        ),
                        DiscoverAsyncRail(
                          title: 'More from this organizer',
                          asyncEvents: ref.watch(eventDetailFromOrganizerProvider(eventId)),
                          onEventTap: (e) => context.push(AttendeeRoutes.eventDetail(e.id)),
                        ),
                        DiscoverAsyncRail(
                          title: 'Recommended for you',
                          subtitle: 'Matched to your interests',
                          asyncEvents: ref.watch(eventDetailRecommendedProvider(eventId)),
                          onEventTap: (e) => context.push(AttendeeRoutes.eventDetail(e.id)),
                        ),
                        SizedBox(height: context.eos.spacing.xl),
                        if (!hasTicket && commerce.hasTicketAvailability)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => context.push(AttendeeRoutes.eventTickets(eventId)),
                              icon: const Icon(Icons.confirmation_number_outlined),
                              label: const Text('Select tickets'),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AttendeeRoutes.dashboard);
    }
  }

  void _showQr(BuildContext context, PublicEvent event, AttendeeEventView? myEvent) {
    showAttendeeQrSheet(
      context,
      myEvent ??
          AttendeeEventView.fromTicket(
            AttendeeTicket(
              id: 'view',
              eventId: eventId,
              eventTitle: event.title,
              tierName: 'Guest',
              venue: event.venue,
              city: event.city,
              startsAt: event.startsAt,
              qrPayload: 'OWANBE:$eventId',
              purchasedAt: DateTime.now(),
            ),
            event,
          ),
    );
  }

  Future<void> _showReportSheet(BuildContext context, WidgetRef ref, PublicEvent event) async {
    const reasons = [
      'Spam or misleading',
      'Inappropriate content',
      'Fraud / scam risk',
      'Wrong location or date',
      'Other',
    ];
    String selected = reasons.first;
    final notes = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                context.eos.spacing.lg,
                context.eos.spacing.sm,
                context.eos.spacing.lg,
                MediaQuery.viewInsetsOf(context).bottom + context.eos.spacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Report event', style: context.eosText.titleLarge),
                  SizedBox(height: context.eos.spacing.sm),
                  for (final r in reasons)
                    RadioListTile<String>(
                      value: r,
                      groupValue: selected,
                      title: Text(r),
                      onChanged: (v) => setState(() => selected = v ?? selected),
                    ),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Additional details (optional)'),
                  ),
                  SizedBox(height: context.eos.spacing.md),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Submit report'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(eventsApiProvider).reportEvent(
            eventId: event.id,
            title: 'Attendee report: $selected',
            category: selected,
            description: notes.text.trim().isEmpty ? null : notes.text.trim(),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: $e')),
      );
    } finally {
      notes.dispose();
    }
  }

  String _when(PublicEvent event) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final start = event.startsAt;
    final end = event.endsAt;
    final h = start.hour > 12 ? start.hour - 12 : (start.hour == 0 ? 12 : start.hour);
    final ampm = start.hour >= 12 ? 'PM' : 'AM';
    final date = '${months[start.month - 1]} ${start.day}, ${start.year}';
    final time =
        '$h:${start.minute.toString().padLeft(2, '0')} $ampm – ${end.hour}:${end.minute.toString().padLeft(2, '0')}';
    return '$date · $time';
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.saved,
    required this.onSave,
    required this.onShare,
    required this.onCalendar,
    required this.onContact,
    required this.onReport,
  });

  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onCalendar;
  final VoidCallback onContact;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.eos.spacing.xs,
      runSpacing: context.eos.spacing.xs,
      children: [
        ActionChip(
          avatar: Icon(saved ? Icons.bookmark : Icons.bookmark_border, size: 18),
          label: Text(saved ? 'Saved' : 'Save'),
          onPressed: onSave,
        ),
        ActionChip(avatar: const Icon(Icons.ios_share, size: 18), label: const Text('Share'), onPressed: onShare),
        ActionChip(
          avatar: const Icon(Icons.event_available_outlined, size: 18),
          label: const Text('Calendar'),
          onPressed: onCalendar,
        ),
        ActionChip(
          avatar: const Icon(Icons.mail_outline, size: 18),
          label: const Text('Contact'),
          onPressed: onContact,
        ),
        ActionChip(
          avatar: const Icon(Icons.flag_outlined, size: 18),
          label: const Text('Report'),
          onPressed: onReport,
        ),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.event});
  final PublicEvent event;

  @override
  Widget build(BuildContext context) {
    return EosSection(
      title: 'Location',
      subtitle: 'Preview map and get directions',
      child: EosSurfaceCard(
        onTap: () => EventDetailActions.openMapPreview(event),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: EosRadius.input,
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  EventDetailActions.staticMapUrl(event),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: context.eosColors.surfaceContainerHighest,
                    child: const Center(child: Icon(Icons.map_outlined, size: 40)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(context.eos.spacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      event.hasCoordinates
                          ? '${event.venue}\n${event.city}'
                          : '${event.venue} · ${event.city}',
                      style: context.eosText.bodyMedium,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => EventDetailActions.openDirections(event),
                    icon: const Icon(Icons.directions_outlined, size: 18),
                    label: const Text('Directions'),
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

class _AgendaSection extends ConsumerWidget {
  const _AgendaSection({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicEventProgramProvider(eventId));
    return async.when(
      loading: () => EosSection(
        title: 'Agenda',
        child: const SizedBox(height: 64, child: Center(child: CircularProgressIndicator())),
      ),
      error: (_, _) => EosSection(
        title: 'Agenda',
        child: EosSurfaceCard(
          child: Text('Agenda unavailable right now.', style: context.eosText.bodyMedium),
        ),
      ),
      data: (program) {
        if (program.items.isEmpty) {
          return EosSection(
            title: 'Agenda',
            child: EosSurfaceCard(
              child: Text('No agenda items published yet.', style: context.eosText.bodyMedium),
            ),
          );
        }
        final current = program.day.current;
        final next = program.day.next;
        return EosSection(
          title: 'Agenda',
          subtitle: '${program.items.length} items',
          child: Column(
            children: [
              if (current != null || next != null)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: EosSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (current != null)
                          Text('Now: ${current.title}', style: context.eosText.titleSmall),
                        if (next != null)
                          Text('Next: ${next.title}', style: context.eosText.bodySmall),
                        if (program.day.countdownSeconds != null)
                          Text(
                            '${program.day.countdownLabel ?? 'Countdown'}: '
                            '${formatProgramCountdown(program.day.countdownSeconds)}',
                            style: context.eosText.labelSmall,
                          ),
                      ],
                    ),
                  ),
                ),
              for (final item in program.items.take(6))
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: EosSurfaceCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.title, style: context.eosText.titleSmall),
                      subtitle: Text(
                        '${_fmtTime(item.startTime)} – ${_fmtTime(item.endTime)}'
                        '${item.ownerName.isNotEmpty ? ' · ${item.ownerName}' : ''}'
                        ' · ${item.status}',
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push(AttendeeRoutes.live(eventId)),
                  icon: const Icon(Icons.sensors, size: 18),
                  label: const Text('Open Live Event'),
                ),
              ),
              SizedBox(height: context.eos.spacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AttendeeRoutes.people(eventId)),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('People & networking'),
                ),
              ),
              SizedBox(height: context.eos.spacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AttendeeRoutes.eventServices(eventId)),
                  icon: const Icon(Icons.handyman_outlined, size: 18),
                  label: const Text('Event services'),
                ),
              ),
              SizedBox(height: context.eos.spacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AttendeeRoutes.eventRecap(eventId)),
                  icon: const Icon(Icons.auto_stories_outlined, size: 18),
                  label: const Text('Event recap'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:${t.minute.toString().padLeft(2, '0')} $ampm';
  }
}

class _SpeakersSection extends StatelessWidget {
  const _SpeakersSection({required this.speakers});
  final List<EventSpeaker> speakers;

  @override
  Widget build(BuildContext context) {
    return EosSection(
      title: 'Speakers',
      child: Column(
        children: [
          for (final s in speakers)
            Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
              child: EosSurfaceCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: s.imageUrl != null && s.imageUrl!.isNotEmpty ? NetworkImage(s.imageUrl!) : null,
                    child: s.imageUrl == null || s.imageUrl!.isEmpty
                        ? Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?')
                        : null,
                  ),
                  title: Text(s.name),
                  subtitle: Text(
                    [
                      if (s.title != null && s.title!.trim().isNotEmpty) s.title!.trim(),
                      if (s.bio != null && s.bio!.trim().isNotEmpty) s.bio!.trim(),
                    ].join(' · '),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SponsorsSection extends StatelessWidget {
  const _SponsorsSection({required this.sponsors});
  final List<EventSponsor> sponsors;

  @override
  Widget build(BuildContext context) {
    return EosSection(
      title: 'Sponsors',
      child: Wrap(
        spacing: context.eos.spacing.sm,
        runSpacing: context.eos.spacing.sm,
        children: [
          for (final s in sponsors)
            ActionChip(
              avatar: s.logoUrl != null && s.logoUrl!.isNotEmpty
                  ? CircleAvatar(backgroundImage: NetworkImage(s.logoUrl!), radius: 10)
                  : const Icon(Icons.handshake_outlined, size: 18),
              label: Text(s.tier != null && s.tier!.isNotEmpty ? '${s.name} · ${s.tier}' : s.name),
              onPressed: s.websiteUrl == null || s.websiteUrl!.isEmpty
                  ? null
                  : () async {
                      final raw = s.websiteUrl!.trim();
                      final uri = Uri.parse(raw.startsWith('http') ? raw : 'https://$raw');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
            ),
        ],
      ),
    );
  }
}

class _FaqsSection extends StatelessWidget {
  const _FaqsSection({required this.faqs});
  final List<EventFaq> faqs;

  @override
  Widget build(BuildContext context) {
    return EosSection(
      title: 'FAQs',
      child: Column(
        children: [
          for (final faq in faqs)
            Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(faq.question, style: context.eosText.titleSmall),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                      child: Text(faq.answer, style: context.eosText.bodyMedium),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.eosColors.primary),
        SizedBox(width: context.eos.spacing.sm),
        Text(label, style: context.eosText.labelMedium),
        const Spacer(),
        Flexible(child: Text(value, style: context.eosText.bodyMedium, textAlign: TextAlign.end)),
        if (onTap != null) ...[
          SizedBox(width: context.eos.spacing.xs),
          Icon(Icons.open_in_new, size: 14, color: context.eosColors.primary),
        ],
      ],
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _TierSummaryRow extends StatelessWidget {
  const _TierSummaryRow({required this.tier});
  final TicketTier tier;

  @override
  Widget build(BuildContext context) {
    final soldOut = tier.remaining <= 0;
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tier.name, style: context.eosText.titleSmall),
                    Text(tier.description, style: context.eosText.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ngnFromMinor(tier.priceMinor.toString()),
                    style: context.eosText.labelLarge?.copyWith(color: context.eosColors.primary),
                  ),
                  Text(
                    soldOut ? 'Sold out' : '${tier.remaining} left',
                    style: context.eosText.labelSmall?.copyWith(
                      color: soldOut ? EosColors.critical : context.eosColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (tier.salesStartAt != null || tier.salesEndAt != null) ...[
            SizedBox(height: context.eos.spacing.xs),
            Text(
              [
                if (tier.salesStartAt != null) 'Sales open ${_shortDate(tier.salesStartAt!)}',
                if (tier.salesEndAt != null) 'Sales close ${_shortDate(tier.salesEndAt!)}',
              ].join(' · '),
              style: context.eosText.labelSmall,
            ),
          ],
          if (tier.hasBenefitsContent) ...[
            SizedBox(height: context.eos.spacing.sm),
            if (tier.accessLevel != null && tier.accessLevel!.trim().isNotEmpty)
              Text('Access: ${tier.accessLevel}', style: context.eosText.labelMedium),
            if (tier.benefits.isNotEmpty)
              Text('Includes: ${tier.benefits.join(', ')}', style: context.eosText.bodySmall),
            if (tier.perks.isNotEmpty) Text('Perks: ${tier.perks.join(', ')}', style: context.eosText.bodySmall),
            if (tier.restrictions.isNotEmpty)
              Text('Restrictions: ${tier.restrictions.join(', ')}', style: context.eosText.bodySmall),
          ],
        ],
      ),
    );
  }

  String _shortDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: context.eosColors.surfaceContainerHighest,
            borderRadius: EosRadius.card,
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        Container(height: 20, width: 180, color: context.eosColors.surfaceContainerHighest),
        SizedBox(height: context.eos.spacing.sm),
        Container(height: 14, width: double.infinity, color: context.eosColors.surfaceContainerHighest),
        SizedBox(height: context.eos.spacing.sm),
        Container(height: 14, width: 240, color: context.eosColors.surfaceContainerHighest),
        SizedBox(height: context.eos.spacing.xl),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry, required this.offline});
  final String message;
  final VoidCallback onRetry;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: EosSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(offline ? Icons.wifi_off : Icons.error_outline, color: context.eosColors.primary),
              SizedBox(height: context.eos.spacing.sm),
              Text(offline ? 'You are offline' : 'Could not load event', style: context.eosText.titleMedium),
              SizedBox(height: context.eos.spacing.xs),
              Text(message, style: context.eosText.bodySmall, textAlign: TextAlign.center),
              SizedBox(height: context.eos.spacing.md),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
