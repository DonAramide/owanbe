import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/event_services_api.dart';
import '../../../core/api/networking_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../core/api/post_event_api.dart';
import '../../../eos/eos.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/models/attendee_pass_status.dart';
import '../../../features/public/models/public_models.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../features/public/providers/public_providers.dart';
import '../../../features/public/widgets/discover_event_rail.dart';
import '../../../features/public/widgets/event_detail_gallery.dart';
import '../../../features/public/widgets/public_event_hero.dart';
import '../../../portals/customer/models/program_models.dart';
import '../data/attendee_personal_schedule_store.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_event_commerce_provider.dart';
import '../providers/attendee_event_services_providers.dart';
import '../providers/attendee_networking_providers.dart';
import '../providers/attendee_post_event_providers.dart';
import '../widgets/attendee_flow_scaffold.dart';
import '../widgets/attendee_networking_widgets.dart';

/// Phase 10 — Post-event hub: recap, feedback, memories, networking, recommendations.
class AttendeeEventRecapScreen extends ConsumerStatefulWidget {
  const AttendeeEventRecapScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AttendeeEventRecapScreen> createState() => _AttendeeEventRecapScreenState();
}

class _AttendeeEventRecapScreenState extends ConsumerState<AttendeeEventRecapScreen> {
  final _feedbackController = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  bool _seededFeedback = false;
  String? _confirmMessage;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(attendeeEventCommerceProvider(widget.eventId));
    ref.invalidate(attendeeTicketsSyncProvider);
    ref.invalidate(publicEventProgramProvider(widget.eventId));
    ref.invalidate(networkingConnectionsProvider(widget.eventId));
    ref.invalidate(myServiceBookingsProvider(widget.eventId));
    ref.invalidate(eventFeedbackProvider(widget.eventId));
    ref.invalidate(publicEventCatalogProvider);
    await Future.wait([
      ref.read(attendeeEventCommerceProvider(widget.eventId).future),
      ref.read(eventFeedbackProvider(widget.eventId).future),
    ]);
  }

  void _seedFeedbackForm(AttendeeFeedbackEnvelope envelope) {
    if (_seededFeedback) return;
    final existing = envelope.feedback;
    if (existing != null) {
      _rating = existing.rating;
      _feedbackController.text = existing.comment ?? '';
    }
    _seededFeedback = true;
  }

  Future<void> _submitFeedback() async {
    final session = ref.read(authSessionProvider);
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to leave feedback')),
      );
      return;
    }
    if (_rating < 1 || _rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a rating from 1 to 5 stars')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(postEventApiProvider).upsertFeedback(
            session: session,
            eventId: widget.eventId,
            rating: _rating,
            comment: _feedbackController.text.trim(),
          );
      await refreshEventFeedback(ref, widget.eventId);
      if (!mounted) return;
      setState(() => _confirmMessage = 'Thanks — your feedback was saved.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted')),
      );
    } on PostEventApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commerceAsync = ref.watch(attendeeEventCommerceProvider(widget.eventId));
    final myEvent = ref
        .watch(attendeeEventsProvider)
        .valueOrNull
        ?.where((e) => e.eventId == widget.eventId)
        .firstOrNull;
    final offline = ref.watch(attendeeOfflineProvider);
    final feedbackAsync = ref.watch(eventFeedbackProvider(widget.eventId));
    final connectionsAsync = ref.watch(networkingConnectionsProvider(widget.eventId));
    final bookingsAsync = ref.watch(myServiceBookingsProvider(widget.eventId));
    final scheduleIds = ref.watch(attendeePersonalScheduleProvider(widget.eventId));
    final programAsync = ref.watch(publicEventProgramProvider(widget.eventId));

    return AttendeeFlowScaffold(
      backLabel: 'My Events',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.myEvents),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: commerceAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: const [
              EosSurfaceCard(child: SizedBox(height: 160)),
              SizedBox(height: 12),
              NetworkingListSkeleton(count: 3),
            ],
          ),
          error: (e, _) => ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              EosAttentionBanner(
                headline: 'Could not load recap',
                message: '$e',
                severity: 'CRITICAL',
              ),
              TextButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
          data: (commerce) {
            if (commerce == null) {
              return ListView(
                padding: EdgeInsets.all(context.eos.spacing.lg),
                children: [
                  EosSurfaceCard(
                    child: Text(
                      'Event not found or no longer available.',
                      style: context.eosText.bodyMedium,
                    ),
                  ),
                ],
              );
            }

            final event = commerce.event;
            final gallery = event.resolvedGallery;
            final photos = gallery.where((g) => !g.isVideo).toList();
            final videos = gallery.where((g) => g.isVideo).toList();
            final connections = connectionsAsync.valueOrNull ?? const <NetworkingConnection>[];
            final accepted = connections
                .where((c) => c.connectionStatus == NetworkingConnectionStatus.connected)
                .toList();
            final bookings = bookingsAsync.valueOrNull ?? const <EventServiceBooking>[];
            final activeBookings = bookings
                .where((b) =>
                    b.serviceStatus != AttendeeServiceStatus.cancelled &&
                    b.serviceStatus != AttendeeServiceStatus.expired)
                .toList();

            feedbackAsync.whenData(_seedFeedbackForm);

            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(context.eos.spacing.lg),
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 920 : double.infinity),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (offline) ...[
                            const EosAttentionBanner(
                              headline: 'Offline',
                              message: 'Showing cached recap data where available.',
                              severity: 'WARNING',
                            ),
                            SizedBox(height: context.eos.spacing.md),
                          ],
                          Semantics(
                            header: true,
                            child: Text('Event recap', style: context.eosText.headlineMedium),
                          ),
                          SizedBox(height: context.eos.spacing.xs),
                          Text(
                            'Relive the celebration, leave feedback, and keep the connections going.',
                            style: context.eosText.bodySmall,
                          ),
                          SizedBox(height: context.eos.spacing.lg),
                          PublicEventHero(
                            event: event,
                            onCta: myEvent != null
                                ? () => context.push(AttendeeRoutes.passDetail(myEvent.ticket.id))
                                : null,
                            ctaLabel: myEvent != null ? 'View pass' : 'Get tickets',
                          ),
                          SizedBox(height: context.eos.spacing.md),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                avatar: const Icon(Icons.check_circle, size: 18),
                                label: Text(
                                  myEvent?.lifecycleLabel ??
                                      (event.endsAt.isBefore(DateTime.now())
                                          ? 'Completed'
                                          : 'Event'),
                                ),
                              ),
                              Chip(
                                avatar: Icon(
                                  myEvent?.checkedIn == true
                                      ? Icons.how_to_reg
                                      : Icons.confirmation_number_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  myEvent?.checkedIn == true ? 'Checked in' : 'Registered',
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.eos.spacing.md),
                          _HubStatsCard(
                            event: event,
                            myEvent: myEvent,
                            connectionsCount: accepted.length,
                            bookingsCount: activeBookings.length,
                            galleryCount: gallery.length,
                            scheduleCount: scheduleIds.length,
                          ),
                          SizedBox(height: context.eos.spacing.lg),
                          _QuickActions(
                            eventId: widget.eventId,
                            ticketId: myEvent?.ticket.id,
                          ),
                          SizedBox(height: context.eos.spacing.xl),
                          _RecapSection(
                            eventId: widget.eventId,
                            myEvent: myEvent,
                            scheduleIds: scheduleIds,
                            programAsync: programAsync,
                            bookings: activeBookings,
                            connections: accepted,
                            galleryCount: gallery.length,
                          ),
                          SizedBox(height: context.eos.spacing.xl),
                          _FeedbackSection(
                            envelopeAsync: feedbackAsync,
                            rating: _rating,
                            controller: _feedbackController,
                            submitting: _submitting,
                            confirmMessage: _confirmMessage,
                            onRating: (v) => setState(() => _rating = v),
                            onSubmit: _submitFeedback,
                            onRetry: () => ref.invalidate(eventFeedbackProvider(widget.eventId)),
                          ),
                          SizedBox(height: context.eos.spacing.xl),
                          _MemoriesSection(gallery: gallery, photos: photos, videos: videos),
                          SizedBox(height: context.eos.spacing.xl),
                          _NetworkingSection(
                            eventId: widget.eventId,
                            connections: accepted,
                            async: connectionsAsync,
                            onRetry: () =>
                                ref.invalidate(networkingConnectionsProvider(widget.eventId)),
                          ),
                          SizedBox(height: context.eos.spacing.xl),
                          _BecauseYouAttendedSection(eventId: widget.eventId),
                          SizedBox(height: context.eos.spacing.xl),
                          _PersonalHistoryShortcuts(),
                          SizedBox(height: context.eos.spacing.xxl),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HubStatsCard extends StatelessWidget {
  const _HubStatsCard({
    required this.event,
    required this.myEvent,
    required this.connectionsCount,
    required this.bookingsCount,
    required this.galleryCount,
    required this.scheduleCount,
  });

  final PublicEvent event;
  final AttendeeEventView? myEvent;
  final int connectionsCount;
  final int bookingsCount;
  final int galleryCount;
  final int scheduleCount;

  @override
  Widget build(BuildContext context) {
    final checkIn = myEvent?.checkedInAt;
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.title, style: context.eosText.titleLarge),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            formatAttendeeDateRange(event.startsAt, event.endsAt),
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.md),
          _StatRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Ticket used',
            value: myEvent?.tierName ?? '—',
          ),
          _StatRow(
            icon: Icons.how_to_reg_outlined,
            label: 'Attendance',
            value: myEvent?.checkedIn == true ? 'Checked in' : 'Registered (not checked in)',
          ),
          _StatRow(
            icon: Icons.schedule,
            label: 'Check-in time',
            value: checkIn != null ? _fmtDateTime(checkIn) : 'Not recorded',
          ),
          _StatRow(
            icon: Icons.groups_outlined,
            label: 'Connections',
            value: '$connectionsCount',
          ),
          _StatRow(
            icon: Icons.handyman_outlined,
            label: 'Services booked',
            value: '$bookingsCount',
          ),
          _StatRow(
            icon: Icons.photo_library_outlined,
            label: 'Gallery items',
            value: '$galleryCount',
          ),
          _StatRow(
            icon: Icons.event_note_outlined,
            label: 'Sessions on your schedule',
            value: '$scheduleCount',
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime d) {
    final local = d.toLocal();
    final h = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '$h:${local.minute.toString().padLeft(2, '0')} $ampm';
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.eosColors.primary),
          SizedBox(width: context.eos.spacing.sm),
          Expanded(child: Text(label, style: context.eosText.bodyMedium)),
          Flexible(
            child: Text(
              value,
              style: context.eosText.titleSmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.eventId, this.ticketId});
  final String eventId;
  final String? ticketId;

  @override
  Widget build(BuildContext context) {
    return EosSection(
      title: 'Quick actions',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (ticketId != null)
            FilledButton.tonalIcon(
              onPressed: () => context.push(AttendeeRoutes.passDetail(ticketId!)),
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: const Text('Pass'),
            ),
          OutlinedButton.icon(
            onPressed: () => context.push(AttendeeRoutes.eventDetail(eventId)),
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text('Event detail'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push(AttendeeRoutes.people(eventId)),
            icon: const Icon(Icons.groups_outlined, size: 18),
            label: const Text('People'),
          ),
                          OutlinedButton.icon(
                            onPressed: () => context.push(AttendeeRoutes.people(eventId, tab: 3)),
                            icon: const Icon(Icons.celebration_outlined, size: 18),
                            label: const Text('Community wall'),
                          ),
          OutlinedButton.icon(
            onPressed: () => context.push(AttendeeRoutes.serviceBookings(eventId)),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Bookings'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push(AttendeeRoutes.personalHistory),
            icon: const Icon(Icons.history, size: 18),
            label: const Text('My history'),
          ),
        ],
      ),
    );
  }
}

class _RecapSection extends StatelessWidget {
  const _RecapSection({
    required this.eventId,
    required this.myEvent,
    required this.scheduleIds,
    required this.programAsync,
    required this.bookings,
    required this.connections,
    required this.galleryCount,
  });

  final String eventId;
  final AttendeeEventView? myEvent;
  final Set<String> scheduleIds;
  final AsyncValue<ProgramSnapshot> programAsync;
  final List<EventServiceBooking> bookings;
  final List<NetworkingConnection> connections;
  final int galleryCount;

  @override
  Widget build(BuildContext context) {
    final timeline = myEvent != null ? buildAttendanceTimeline(myEvent!) : const [];
    final sessions = programAsync.maybeWhen(
      data: (program) => program.items.where((i) => scheduleIds.contains(i.id)).toList(),
      orElse: () => const <ProgramItem>[],
    );

    return EosSection(
      title: 'Your recap',
      subtitle: 'Composed from your ticket, schedule, services, and connections — nothing duplicated.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance summary', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.sm),
          if (myEvent == null)
            EosSurfaceCard(
              child: Text(
                'No ticket found for this event on your account.',
                style: context.eosText.bodyMedium,
              ),
            )
          else
            EosSurfaceCard(
              child: Column(
                children: [
                  for (final item in timeline)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item.kind == 'checked_in'
                            ? Icons.how_to_reg
                            : item.kind == 'completed'
                                ? Icons.flag_outlined
                                : Icons.confirmation_number_outlined,
                      ),
                      title: Text(item.title),
                      subtitle: Text(item.subtitle),
                    ),
                ],
              ),
            ),
          SizedBox(height: context.eos.spacing.lg),
          Text('Sessions on your schedule', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'Personal picks from Live Hub — not verified session attendance.',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.sm),
          if (programAsync.isLoading)
            const NetworkingListSkeleton(count: 1)
          else if (sessions.isEmpty)
            EosSurfaceCard(
              child: Text(
                scheduleIds.isEmpty
                    ? 'You did not save sessions to your personal schedule.'
                    : 'Saved session details are unavailable offline.',
                style: context.eosText.bodyMedium,
              ),
            )
          else
            Column(
              children: [
                for (final s in sessions)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                    child: EosSurfaceCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.title),
                        subtitle: Text(s.ownerName.isNotEmpty ? s.ownerName : 'Session'),
                      ),
                    ),
                  ),
              ],
            ),
          SizedBox(height: context.eos.spacing.lg),
          Text('Services booked', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.sm),
          if (bookings.isEmpty)
            EosSurfaceCard(
              child: Text('No service bookings for this event.', style: context.eosText.bodyMedium),
            )
          else
            Column(
              children: [
                for (final b in bookings.take(5))
                  Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                    child: EosSurfaceCard(
                      onTap: () => context.push(AttendeeRoutes.serviceBookings(eventId)),
                        child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(b.booking.itemName),
                        subtitle: Text(
                          '${b.booking.vendorName} · ${serviceStatusLabel(b.serviceStatus)}',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          SizedBox(height: context.eos.spacing.lg),
          Text('Connections made', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.sm),
            EosSurfaceCard(
            onTap: () => context.push(AttendeeRoutes.people(eventId, tab: 2)),
            child: Text(
              connections.isEmpty
                  ? 'No accepted connections yet — open People to reconnect.'
                  : '${connections.length} connection${connections.length == 1 ? '' : 's'} · tap to view',
              style: context.eosText.bodyMedium,
            ),
          ),
          SizedBox(height: context.eos.spacing.lg),
          Text('Gallery preview', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.sm),
          EosSurfaceCard(
            child: Text(
              galleryCount == 0
                  ? 'No official media published yet.'
                  : '$galleryCount media item${galleryCount == 1 ? '' : 's'} in Event Memories below.',
              style: context.eosText.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection({
    required this.envelopeAsync,
    required this.rating,
    required this.controller,
    required this.submitting,
    required this.confirmMessage,
    required this.onRating,
    required this.onSubmit,
    required this.onRetry,
  });

  final AsyncValue<AttendeeFeedbackEnvelope> envelopeAsync;
  final int rating;
  final TextEditingController controller;
  final bool submitting;
  final String? confirmMessage;
  final ValueChanged<int> onRating;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EosSection(
      title: 'Feedback',
      subtitle: 'One overall rating and optional written note — no surveys.',
      child: envelopeAsync.when(
        loading: () => const NetworkingListSkeleton(count: 1),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EosAttentionBanner(headline: 'Feedback unavailable', message: '$e', severity: 'CRITICAL'),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
        data: (envelope) {
          final existing = envelope.feedback;
          final canEdit = envelope.canSubmit && (existing == null || existing.editable);
          return EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (confirmMessage != null) ...[
                  EosAttentionBanner(
                    headline: 'Submitted',
                    message: confirmMessage!,
                    severity: 'INFO',
                  ),
                  SizedBox(height: context.eos.spacing.md),
                ] else if (existing != null) ...[
                  EosAttentionBanner(
                    headline: 'Feedback on file',
                    message: canEdit
                        ? 'You can update your rating until the feedback window closes.'
                        : 'Feedback is locked for this event.',
                    severity: 'INFO',
                  ),
                  SizedBox(height: context.eos.spacing.md),
                ],
                Text('Overall rating', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                Semantics(
                  label: 'Event rating $rating of 5',
                  child: Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          tooltip: '$i star${i == 1 ? '' : 's'}',
                          onPressed: canEdit ? () => onRating(i) : null,
                          icon: Icon(
                            i <= rating ? Icons.star : Icons.star_border,
                            color: EosColors.warning,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: context.eos.spacing.md),
                TextField(
                  controller: controller,
                  enabled: canEdit && !submitting,
                  maxLines: 4,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Written feedback (optional)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                SizedBox(height: context.eos.spacing.md),
                if (canEdit)
                  FilledButton.icon(
                    onPressed: submitting ? null : onSubmit,
                    icon: submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined, size: 18),
                    label: Text(existing == null ? 'Submit feedback' : 'Update feedback'),
                  )
                else if (existing == null)
                  Text(
                    'Feedback is closed for this event.',
                    style: context.eosText.bodySmall,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MemoriesSection extends StatelessWidget {
  const _MemoriesSection({
    required this.gallery,
    required this.photos,
    required this.videos,
  });

  final List<EventGalleryItem> gallery;
  final List<EventGalleryItem> photos;
  final List<EventGalleryItem> videos;

  @override
  Widget build(BuildContext context) {
    return EosSection(
      title: 'Event Memories',
      subtitle: 'Official photos and videos from the event gallery.',
      child: gallery.isEmpty
          ? EosSurfaceCard(
              child: Text(
                'No official memories published yet. Check back when the organiser adds media.',
                style: context.eosText.bodyMedium,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photos.isNotEmpty) ...[
                  Text('${photos.length} photo${photos.length == 1 ? '' : 's'}',
                      style: context.eosText.titleSmall),
                  SizedBox(height: context.eos.spacing.sm),
                ],
                if (videos.isNotEmpty) ...[
                  Text('${videos.length} video${videos.length == 1 ? '' : 's'}',
                      style: context.eosText.titleSmall),
                  SizedBox(height: context.eos.spacing.sm),
                ],
                EventDetailGallerySection(items: gallery),
                SizedBox(height: context.eos.spacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          openEventGalleryViewer(context, items: gallery, initialIndex: 0),
                      icon: const Icon(Icons.fullscreen, size: 18),
                      label: const Text('Open gallery'),
                    ),
                    if (gallery.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _openMediaUrl(context, gallery.first.url),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open / download'),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _openMediaUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open media URL')),
      );
    }
  }
}

class _NetworkingSection extends StatelessWidget {
  const _NetworkingSection({
    required this.eventId,
    required this.connections,
    required this.async,
    required this.onRetry,
  });

  final String eventId;
  final List<NetworkingConnection> connections;
  final AsyncValue<List<NetworkingConnection>> async;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EosSection(
      title: 'Continue networking',
      subtitle: 'Reconnect with people you met — messaging is not available in this phase.',
      child: async.when(
        loading: () => const NetworkingListSkeleton(count: 1),
        error: (e, _) => Column(
          children: [
            EosAttentionBanner(headline: 'Connections unavailable', message: '$e', severity: 'WARNING'),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
        data: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (connections.isEmpty)
              EosSurfaceCard(
                child: Text(
                  'No accepted connections yet. Open People to discover attendees or revisit the Community Wall.',
                  style: context.eosText.bodyMedium,
                ),
              )
            else
              Column(
                children: [
                  for (final c in connections.take(6))
                    Padding(
                      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                      child: EosSurfaceCard(
                        onTap: () =>
                            context.push(AttendeeRoutes.peerProfile(eventId, c.otherUserId)),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage:
                                c.avatarUrl != null && c.avatarUrl!.isNotEmpty
                                    ? NetworkImage(c.avatarUrl!)
                                    : null,
                            child: c.avatarUrl == null || c.avatarUrl!.isEmpty
                                ? Text(c.displayName.isNotEmpty
                                    ? c.displayName[0].toUpperCase()
                                    : '?')
                                : null,
                          ),
                          title: Text(c.displayName),
                          subtitle: Text(c.company ?? 'Connection'),
                        ),
                      ),
                    ),
                ],
              ),
            SizedBox(height: context.eos.spacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => context.push(AttendeeRoutes.people(eventId)),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('Continue networking'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push(AttendeeRoutes.people(eventId, tab: 3)),
                  icon: const Icon(Icons.celebration_outlined, size: 18),
                  label: const Text('Community Wall'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BecauseYouAttendedSection extends ConsumerWidget {
  const _BecauseYouAttendedSection({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similar = ref.watch(eventDetailSimilarProvider(eventId));
    final fromOrg = ref.watch(eventDetailFromOrganizerProvider(eventId));
    final recommended = ref.watch(eventDetailRecommendedProvider(eventId));
    final catalog = ref.watch(publicEventCatalogProvider);

    final relatedCategories = catalog.maybeWhen(
      data: (all) {
        final seed = all.where((e) => e.id == eventId).firstOrNull;
        if (seed == null) return const <PublicEvent>[];
        final now = DateTime.now();
        return all
            .where((e) =>
                e.id != eventId &&
                e.category == seed.category &&
                e.startsAt.isAfter(now))
            .take(6)
            .toList();
      },
      orElse: () => const <PublicEvent>[],
    );

    void open(PublicEvent e) => context.push(AttendeeRoutes.eventDetail(e.id));

    return EosSection(
      title: 'Because you attended',
      subtitle: 'Similar celebrations, same organisers, related categories, and upcoming picks.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DiscoverAsyncRail(
            title: 'Similar events',
            asyncEvents: similar,
            onEventTap: open,
          ),
          DiscoverAsyncRail(
            title: 'Same organisers',
            asyncEvents: fromOrg,
            onEventTap: open,
          ),
          DiscoverEventRail(
            title: 'Related categories',
            subtitle: 'Upcoming in the same category',
            events: relatedCategories,
            onEventTap: open,
          ),
          DiscoverAsyncRail(
            title: 'Recommended for you',
            asyncEvents: recommended,
            onEventTap: open,
          ),
        ],
      ),
    );
  }
}

class _PersonalHistoryShortcuts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EosSection(
      title: 'Personal history',
      subtitle: 'Your broader attendance trail across Owanbe.',
      child: EosSurfaceCard(
        onTap: () => context.push(AttendeeRoutes.personalHistory),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history),
          title: const Text('Open personal history'),
          subtitle: const Text('Past events, tickets, attendance, bookings, connections'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
