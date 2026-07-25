import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../eos/eos.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/models/attendee_pass_status.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_pass_providers.dart';
import '../widgets/attendee_digital_pass_card.dart';
import '../widgets/attendee_flow_scaffold.dart';
import '../widgets/attendee_pass_status_chip.dart';

/// Dedicated Event Entry experience — eligibility, venue, attendance timeline.
class AttendeeEventEntryScreen extends ConsumerStatefulWidget {
  const AttendeeEventEntryScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<AttendeeEventEntryScreen> createState() => _AttendeeEventEntryScreenState();
}

class _AttendeeEventEntryScreenState extends ConsumerState<AttendeeEventEntryScreen> {
  late String _activeTicketId;

  @override
  void initState() {
    super.initState();
    _activeTicketId = widget.ticketId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendeePassLiveWatchProvider.notifier).state = true;
      ref.read(attendeePassLiveSyncProvider);
    });
  }

  @override
  void dispose() {
    // Live watch cleared in deactivate to keep ref safe.
    super.dispose();
  }

  @override
  void deactivate() {
    ref.read(attendeePassLiveWatchProvider.notifier).state = false;
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(attendeePassLiveSyncProvider);
    final offline = ref.watch(attendeeOfflineProvider);
    final async = ref.watch(attendeeEventsProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Passes',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.passes),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(attendeeTicketsSyncProvider);
          await ref.read(attendeeEventsProvider.future);
        },
        child: async.when(
          loading: () => ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: const [AttendeePassSkeleton(), SizedBox(height: 16), AttendeePassSkeleton()],
          ),
          error: (e, _) => ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              EosAttentionBanner(headline: 'Entry unavailable', message: '$e', severity: 'CRITICAL'),
              TextButton(
                onPressed: () => ref.invalidate(attendeeTicketsSyncProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (events) {
            AttendeeEventView? current;
            for (final e in events) {
              if (e.ticket.id == _activeTicketId) {
                current = e;
                break;
              }
            }
            current ??= events.where((e) => e.ticket.id == widget.ticketId).firstOrNull;
            if (current == null) {
              return ListView(
                padding: EdgeInsets.all(context.eos.spacing.lg),
                children: [
                  EosSurfaceCard(
                    child: Text('Pass not found.', style: context.eosText.bodyMedium),
                  ),
                ],
              );
            }
            final pass = current;
            final siblings = siblingPassesFor(events, pass);
            final live = pass.liveStatus;
            final timeline = buildAttendanceTimeline(pass);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [
                Text('Event entry', style: context.eosText.headlineMedium),
                SizedBox(height: context.eos.spacing.xs),
                Text(
                  'Present your pass to staff. Status updates automatically after check-in.',
                  style: context.eosText.bodySmall,
                ),
                if (offline) ...[
                  SizedBox(height: context.eos.spacing.sm),
                  const EosAttentionBanner(
                    headline: 'Offline',
                    message: 'Showing the last saved pass. Live check-in updates resume when you reconnect.',
                    severity: 'WARNING',
                  ),
                ],
                SizedBox(height: context.eos.spacing.md),
                AttendeePassSwitcherBar(
                  siblings: siblings,
                  currentId: pass.ticket.id,
                  onSelect: (id) {
                    setState(() => _activeTicketId = id);
                    context.replace(AttendeeRoutes.entry(id));
                  },
                ),
                _EligibilityBanner(live: live, checkedIn: pass.checkedIn),
                SizedBox(height: context.eos.spacing.md),
                AttendeeDigitalPassCard(
                  event: pass,
                  showActions: false,
                  compactQr: false,
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Venue & arrival', style: context.eosText.titleMedium),
                SizedBox(height: context.eos.spacing.sm),
                EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(context, 'Venue', pass.venue),
                      if (pass.city.trim().isNotEmpty) _kv(context, 'City', pass.city),
                      if (pass.venueAddress?.trim().isNotEmpty == true)
                        _kv(context, 'Address', pass.venueAddress!),
                      if (pass.gateInfo?.trim().isNotEmpty == true)
                        _kv(context, 'Gate', pass.gateInfo!),
                      if (pass.arrivalInstructions?.trim().isNotEmpty == true)
                        _kv(context, 'Arrival', pass.arrivalInstructions!)
                      else if (pass.entryInstructions?.trim().isNotEmpty == true)
                        _kv(context, 'Entry', pass.entryInstructions!)
                      else
                        _kv(
                          context,
                          'Arrival',
                          'Arrive with this digital pass ready. Staff will scan your QR at the entrance.',
                        ),
                      if (pass.supportContactEmail?.trim().isNotEmpty == true ||
                          pass.supportContactPhone?.trim().isNotEmpty == true) ...[
                        SizedBox(height: context.eos.spacing.sm),
                        Text('Support contact', style: context.eosText.labelMedium),
                        if (pass.supportContactEmail?.trim().isNotEmpty == true)
                          TextButton.icon(
                            onPressed: () => _launch('mailto:${pass.supportContactEmail}'),
                            icon: const Icon(Icons.email_outlined, size: 18),
                            label: Text(pass.supportContactEmail!),
                          ),
                        if (pass.supportContactPhone?.trim().isNotEmpty == true)
                          TextButton.icon(
                            onPressed: () => _launch('tel:${pass.supportContactPhone}'),
                            icon: const Icon(Icons.phone_outlined, size: 18),
                            label: Text(pass.supportContactPhone!),
                          ),
                      ],
                      SizedBox(height: context.eos.spacing.sm),
                      OutlinedButton.icon(
                        onPressed: () => _openDirections(pass),
                        icon: const Icon(Icons.directions_outlined, size: 18),
                        label: const Text('Directions'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Attendance history', style: context.eosText.titleMedium),
                SizedBox(height: context.eos.spacing.sm),
                EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pass.checkedInAt != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                          child: Text(
                            'Check-in time: ${formatAttendeeDateTime(pass.checkedInAt!)}',
                            style: context.eosText.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      for (final item in timeline)
                        Padding(
                          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                item.kind == 'checked_in'
                                    ? Icons.verified_outlined
                                    : Icons.circle_outlined,
                                size: 18,
                              ),
                              SizedBox(width: context.eos.spacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title, style: context.eosText.titleSmall),
                                    Text(item.subtitle, style: context.eosText.bodySmall),
                                    Text(
                                      formatAttendeeDateTime(item.at),
                                      style: context.eosText.labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(),
                      Text(
                        'Summary: ${pass.liveStatusLabel} · '
                        '${pass.checkedIn ? 'Attended' : 'Not checked in yet'}',
                        style: context.eosText.bodySmall,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.eos.spacing.lg),
                if (pass.checkedIn || pass.liveStatus.isCheckedInState || pass.isOngoing)
                  FilledButton.icon(
                    onPressed: () => context.push(AttendeeRoutes.live(pass.eventId)),
                    icon: const Icon(Icons.sensors, size: 18),
                    label: const Text('Join Live Event'),
                  ),
                if (pass.checkedIn || pass.liveStatus.isCheckedInState || pass.isOngoing)
                  SizedBox(height: context.eos.spacing.sm),
                OutlinedButton(
                  onPressed: () => context.push(AttendeeRoutes.passDetail(pass.ticket.id)),
                  child: const Text('Open full digital pass'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(k, style: context.eosText.labelMedium)),
          Expanded(child: Text(v, style: context.eosText.bodySmall)),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openDirections(AttendeeEventView event) async {
    final q = Uri.encodeComponent(
      [event.venueAddress, event.venue, event.city].where((s) => (s ?? '').trim().isNotEmpty).join(', '),
    );
    await _launch('https://www.google.com/maps/search/?api=1&query=$q');
  }
}

class _EligibilityBanner extends StatelessWidget {
  const _EligibilityBanner({required this.live, required this.checkedIn});

  final AttendeePassLiveStatus live;
  final bool checkedIn;

  @override
  Widget build(BuildContext context) {
    if (checkedIn || live.isCheckedInState) {
      return EosAttentionBanner(
        headline: 'Already checked in',
        message: live.description,
        severity: 'INFO',
      );
    }
    if (live.allowsEntry || live == AttendeePassLiveStatus.readyForEntry) {
      return EosAttentionBanner(
        headline: 'Entry eligible',
        message: live.description,
        severity: 'INFO',
      );
    }
    if (live == AttendeePassLiveStatus.expired ||
        live == AttendeePassLiveStatus.cancelled ||
        live == AttendeePassLiveStatus.refunded) {
      return EosAttentionBanner(
        headline: live.label,
        message: live.description,
        severity: 'CRITICAL',
      );
    }
    return EosAttentionBanner(
      headline: live.label,
      message: live.description,
      severity: 'WARNING',
    );
  }
}
