import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../../../theme/theme_mode_provider.dart';
import '../models/attendee_event_models.dart';
import '../providers/attendee_events_provider.dart';
import '../widgets/attendee_event_card.dart';

class AttendeeDashboardScreen extends ConsumerStatefulWidget {
  const AttendeeDashboardScreen({super.key});

  @override
  ConsumerState<AttendeeDashboardScreen> createState() => _AttendeeDashboardScreenState();
}

class _AttendeeDashboardScreenState extends ConsumerState<AttendeeDashboardScreen> {
  int _tab = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => seedDemoAttendeeTicketsIfEmpty(ref));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return EosAppShell(
      brandLabel: 'Owanbe',
      brandSubtitle: 'My celebrations',
      destinations: EosRoleDestinations.attendee,
      selectedIndex: _tab,
      onSelected: (i) {
        if (i == 0) {
          context.go('/events');
          return;
        }
        setState(() => _tab = i);
      },
      topBar: _AttendeeTopBar(
        name: session?.displayName ?? 'Guest',
        onSignOut: () {
          ref.read(authSessionProvider.notifier).signOut();
          context.go('/');
        },
      ),
      body: switch (_tab) {
        2 => const _ScheduleTab(),
        _ => const _AttendeeHomeTab(),
      },
    );
  }
}

class _AttendeeTopBar extends ConsumerWidget {
  const _AttendeeTopBar({required this.name, required this.onSignOut});

  final String name;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Material(
      color: context.eosColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant))),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg, vertical: context.eos.spacing.sm),
          child: Row(
            children: [
              Text('My events', style: context.eosText.titleLarge),
              const Spacer(),
              IconButton(
                tooltip: isDark ? 'Light mode' : 'Dark mode',
                onPressed: () => ref.read(themeModeProvider.notifier).toggleLightDark(),
                icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              ),
              EosAttendeeChip(name: name, compact: true),
              IconButton(onPressed: onSignOut, icon: const Icon(Icons.logout)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendeeHomeTab extends ConsumerWidget {
  const _AttendeeHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(attendeeEventsProvider);
    final statsAsync = ref.watch(attendeeDashboardStatsProvider);

    return EosPageScaffold(
      title: 'My celebrations',
      subtitle: 'Events you are attending — full details, tickets, and check-in',
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.go('/events'),
          icon: const Icon(Icons.explore_outlined, size: 18),
          label: const Text('Discover events'),
        ),
      ],
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EosSurfaceCard(child: Text('$e')),
        data: (events) {
          if (events.isEmpty) {
            return EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('No events yet', style: context.eosText.titleMedium),
                  SizedBox(height: context.eos.spacing.sm),
                  Text(
                    'When you buy a ticket or accept an invitation, the full event details will appear here — just like the organizer dashboard, but for celebrations you attend.',
                    style: context.eosText.bodyMedium,
                  ),
                  SizedBox(height: context.eos.spacing.md),
                  FilledButton(
                    onPressed: () => context.go('/events'),
                    child: const Text('Discover events'),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statsAsync.when(
                data: (stats) => Wrap(
                  spacing: context.eos.spacing.md,
                  runSpacing: context.eos.spacing.md,
                  children: [
                    _kpi(context, 'My tickets', '${stats.totalTickets}', Icons.confirmation_number_outlined),
                    _kpi(context, 'Upcoming', '${stats.upcoming}', Icons.event_outlined),
                    _kpi(context, 'Checked in', '${stats.checkedIn}', Icons.how_to_reg_outlined),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              SizedBox(height: context.eos.spacing.lg),
              if (statsAsync.valueOrNull?.nextEvent != null) ...[
                EosAttentionBanner(
                  headline: 'Next up',
                  message:
                      '${statsAsync.valueOrNull!.nextEvent!.eventTitle} · ${formatAttendeeDateRange(statsAsync.valueOrNull!.nextEvent!.startsAt, statsAsync.valueOrNull!.nextEvent!.endsAt)}',
                  severity: 'INFO',
                  actionLabel: 'View details',
                  onAction: () => context.push('/events/${statsAsync.valueOrNull!.nextEvent!.eventId}'),
                ),
                SizedBox(height: context.eos.spacing.lg),
              ],
              EosSection(
                title: 'Events you are attending',
                subtitle: 'Tap a card for the full event page, venue map, and your QR ticket',
                child: Column(
                  children: [
                    for (final event in events) ...[
                      AttendeeEventCard(
                        event: event,
                        onOpenDetail: () => context.push('/events/${event.eventId}'),
                        onShowQr: () => showAttendeeQrSheet(context, event),
                      ),
                      SizedBox(height: context.eos.spacing.md),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpi(BuildContext context, String title, String value, IconData icon) {
    return SizedBox(
      width: 220,
      child: EosKpiCard(title: title, value: value, icon: icon),
    );
  }
}

class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(attendeeEventsProvider);

    return EosPageScaffold(
      title: 'Schedule',
      subtitle: 'Your celebration timeline',
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
        data: (events) {
          if (events.isEmpty) {
            return EosSurfaceCard(
              child: Text('No upcoming events on your schedule.', style: context.eosText.bodyMedium),
            );
          }
          return Column(
            children: [
              for (final event in events)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: EosFeedItem(
                    title: event.eventTitle,
                    subtitle: '${event.venue}, ${event.city} · ${event.tierName}',
                    timestamp: formatAttendeeDateRange(event.startsAt, event.endsAt),
                    leading: Icon(Icons.celebration_outlined, color: context.eosColors.primary),
                    onTap: () => context.push('/events/${event.eventId}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
