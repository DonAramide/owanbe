import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/models/attendee_pass_status.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../commerce/attendee_pass_actions.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_pass_providers.dart';
import '../widgets/attendee_digital_pass_card.dart';
import '../widgets/attendee_flow_scaffold.dart';
import '../widgets/attendee_pass_status_chip.dart';

/// Digital passes list — QR + live admission status (Phase 6A).
class AttendeeMyPassesScreen extends ConsumerWidget {
  const AttendeeMyPassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attendeeEventsProvider);
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Dashboard',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.dashboard),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(attendeeTicketsSyncProvider);
          await ref.read(attendeeEventsProvider.future);
        },
        child: async.when(
          loading: () => ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              Text('My Passes', style: context.eosText.headlineMedium),
              SizedBox(height: context.eos.spacing.lg),
              const AttendeePassSkeleton(),
              SizedBox(height: context.eos.spacing.md),
              const AttendeePassSkeleton(),
            ],
          ),
          error: (e, _) => ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              EosAttentionBanner(headline: 'Passes unavailable', message: '$e', severity: 'CRITICAL'),
              TextButton(
                onPressed: () => ref.invalidate(attendeeTicketsSyncProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (events) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              Text('My Passes', style: context.eosText.headlineMedium),
              SizedBox(height: context.eos.spacing.xs),
              Text(
                'Digital event passes for check-in. Status updates when staff validate your ticket.',
                style: context.eosText.bodySmall,
              ),
              if (offline) ...[
                SizedBox(height: context.eos.spacing.sm),
                const EosAttentionBanner(
                  headline: 'Offline',
                  message: 'Showing saved passes on this device. Sync resumes when you reconnect.',
                  severity: 'WARNING',
                ),
              ],
              SizedBox(height: context.eos.spacing.lg),
              if (events.isEmpty)
                EosSurfaceCard(
                  child: Text(
                    'No passes yet. Buy a ticket or accept an invitation to get a digital pass.',
                    style: context.eosText.bodyMedium,
                  ),
                )
              else
                for (final event in events) ...[
                  AttendeeDigitalPassCard(event: event),
                  SizedBox(height: context.eos.spacing.md),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full pass detail with switcher + attendance summary.
class AttendeePassDetailScreen extends ConsumerStatefulWidget {
  const AttendeePassDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<AttendeePassDetailScreen> createState() => _AttendeePassDetailScreenState();
}

class _AttendeePassDetailScreenState extends ConsumerState<AttendeePassDetailScreen> {
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
            children: const [AttendeePassSkeleton()],
          ),
          error: (e, _) => ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              EosAttentionBanner(headline: 'Pass unavailable', message: '$e', severity: 'CRITICAL'),
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
            final timeline = buildAttendanceTimeline(pass);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [
                Text('Digital event pass', style: context.eosText.headlineMedium),
                if (offline) ...[
                  SizedBox(height: context.eos.spacing.sm),
                  const EosAttentionBanner(
                    headline: 'Offline',
                    message: 'QR and ticket details remain available from your last sync.',
                    severity: 'WARNING',
                  ),
                ],
                SizedBox(height: context.eos.spacing.md),
                AttendeePassSwitcherBar(
                  siblings: siblings,
                  currentId: pass.ticket.id,
                  onSelect: (id) {
                    setState(() => _activeTicketId = id);
                    context.replace(AttendeeRoutes.passDetail(id));
                  },
                ),
                AttendeeDigitalPassCard(event: pass, showActions: false),
                SizedBox(height: context.eos.spacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.push(AttendeeRoutes.entry(pass.ticket.id)),
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Event entry'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => AttendeePassActions.shareTicket(pass),
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('Share'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => AttendeePassActions.downloadTicket(context, pass),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Save offline'),
                    ),
                  ],
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Attendance timeline', style: context.eosText.titleMedium),
                SizedBox(height: context.eos.spacing.sm),
                EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in timeline)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.timeline, size: 20),
                          title: Text(item.title),
                          subtitle: Text('${item.subtitle}\n${formatAttendeeDateTime(item.at)}'),
                          isThreeLine: true,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
