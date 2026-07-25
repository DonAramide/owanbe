import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../features/public/providers/public_providers.dart';
import '../../../portals/customer/models/program_models.dart';
import '../data/attendee_personal_schedule_store.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_live_providers.dart';
import '../widgets/attendee_flow_scaffold.dart';
import '../widgets/attendee_pass_status_chip.dart';

/// Attendee Live Event Hub — command centre during a live / ongoing event (Phase 7).
class AttendeeLiveEventHubScreen extends ConsumerStatefulWidget {
  const AttendeeLiveEventHubScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AttendeeLiveEventHubScreen> createState() => _AttendeeLiveEventHubScreenState();
}

class _AttendeeLiveEventHubScreenState extends ConsumerState<AttendeeLiveEventHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _focusSessionId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendeeLiveWatchProvider(widget.eventId).notifier).state = true;
      ref.read(attendeeLiveSyncProvider(widget.eventId));
    });
  }

  @override
  void deactivate() {
    ref.read(attendeeLiveWatchProvider(widget.eventId).notifier).state = false;
    super.deactivate();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(attendeeLiveSyncProvider(widget.eventId));
    final offline = ref.watch(attendeeOfflineProvider);
    final ticketAsync = ref.watch(attendeeLiveEventTicketProvider(widget.eventId));
    final programAsync = ref.watch(publicEventProgramProvider(widget.eventId));
    final updatesAsync = ref.watch(attendeeLiveUpdatesProvider(widget.eventId));
    final eventAsync = ref.watch(publicEventProvider(widget.eventId));
    final selected = ref.watch(attendeePersonalScheduleProvider(widget.eventId));

    return AttendeeFlowScaffold(
      backLabel: 'Back',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.dashboard),
      body: Column(
        children: [
          if (offline)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: EosAttentionBanner(
                headline: 'Offline',
                message: 'Showing the last loaded agenda and announcements. Live refresh resumes when connected.',
                severity: 'WARNING',
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(publicEventProgramProvider(widget.eventId));
                ref.invalidate(attendeeLiveUpdatesProvider(widget.eventId));
                ref.invalidate(attendeeTicketsSyncProvider);
                await Future.wait([
                  ref.read(publicEventProgramProvider(widget.eventId).future),
                  ref.read(attendeeLiveUpdatesProvider(widget.eventId).future),
                ]);
              },
              child: NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(context.eos.spacing.lg),
                      child: _HubHeader(
                        eventId: widget.eventId,
                        ticketAsync: ticketAsync,
                        programAsync: programAsync,
                        eventAsync: eventAsync,
                        updatesAsync: updatesAsync,
                        onOpenPass: () {
                          final t = ticketAsync.valueOrNull;
                          if (t != null) context.push(AttendeeRoutes.entry(t.ticket.id));
                        },
                        onOpenAgenda: () => _tabs.animateTo(1),
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      TabBar(
                        controller: _tabs,
                        isScrollable: true,
                        tabs: const [
                          Tab(text: 'Live'),
                          Tab(text: 'Agenda'),
                          Tab(text: 'My schedule'),
                          Tab(text: 'Updates'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabs,
                  children: [
                    _LiveOverviewTab(
                      eventId: widget.eventId,
                      programAsync: programAsync,
                      ticketAsync: ticketAsync,
                      onFocusSession: (id) {
                        setState(() => _focusSessionId = id);
                        _tabs.animateTo(1);
                      },
                    ),
                    _AgendaTab(
                      eventId: widget.eventId,
                      programAsync: programAsync,
                      selected: selected,
                      focusSessionId: _focusSessionId,
                      onToggle: (id) =>
                          ref.read(attendeePersonalScheduleProvider(widget.eventId).notifier).toggle(id),
                    ),
                    _MyScheduleTab(
                      eventId: widget.eventId,
                      programAsync: programAsync,
                      selected: selected,
                      onToggle: (id) =>
                          ref.read(attendeePersonalScheduleProvider(widget.eventId).notifier).toggle(id),
                      onFocus: (id) {
                        setState(() => _focusSessionId = id);
                        _tabs.animateTo(1);
                      },
                    ),
                    _UpdatesTab(updatesAsync: updatesAsync),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.eventId,
    required this.ticketAsync,
    required this.programAsync,
    required this.eventAsync,
    required this.updatesAsync,
    required this.onOpenPass,
    required this.onOpenAgenda,
  });

  final String eventId;
  final AsyncValue<AttendeeEventView?> ticketAsync;
  final AsyncValue<ProgramSnapshot> programAsync;
  final AsyncValue eventAsync;
  final AsyncValue<List<AttendeeLiveUpdate>> updatesAsync;
  final VoidCallback onOpenPass;
  final VoidCallback onOpenAgenda;

  @override
  Widget build(BuildContext context) {
    final ticket = ticketAsync.valueOrNull;
    final program = programAsync.valueOrNull;
    final buckets = program != null ? buildLiveAgendaBuckets(program) : null;
    final event = eventAsync.asData?.value;
    final title = ticket?.eventTitle ?? event?.title ?? 'Live event';
    final now = DateTime.now();
    final alerts = updatesAsync.valueOrNull?.where((u) => u.isAlert).take(2).toList() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: EosRadius.input,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(ticket?.coverGradientStart ?? event?.coverGradientStart ?? 0xFF4B2C6F),
                  Color(ticket?.coverGradientEnd ?? event?.coverGradientEnd ?? 0xFFD4A853),
                ],
              ),
            ),
            padding: EdgeInsets.all(context.eos.spacing.md),
            alignment: Alignment.bottomLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('LIVE', style: context.eosText.labelSmall?.copyWith(color: Colors.white70)),
                Text(
                  title,
                  style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                'Now ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                style: context.eosText.titleSmall,
              ),
            ),
            if (ticket != null) AttendeePassStatusChip(status: ticket.liveStatus, compact: true),
          ],
        ),
        SizedBox(height: context.eos.spacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatChip(
              label: ticket?.checkedIn == true ? 'Checked in' : 'Not checked in',
              icon: Icons.verified_outlined,
            ),
            _StatChip(
              label: ticket != null ? ticket.liveStatusLabel : 'Guest',
              icon: Icons.how_to_reg_outlined,
            ),
            if (buckets?.current != null)
              _StatChip(label: 'Now: ${buckets!.current!.title}', icon: Icons.play_circle_outline),
            if (buckets?.day.next != null)
              _StatChip(label: 'Next: ${buckets!.day.next!.title}', icon: Icons.skip_next),
          ],
        ),
        if (buckets?.day.countdownSeconds != null) ...[
          SizedBox(height: context.eos.spacing.sm),
          EosSurfaceCard(
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 20),
                SizedBox(width: context.eos.spacing.sm),
                Expanded(
                  child: Text(
                    '${buckets!.day.countdownLabel ?? 'Countdown'}: '
                    '${formatProgramCountdown(buckets.day.countdownSeconds)}',
                    style: context.eosText.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
        for (final a in alerts) ...[
          SizedBox(height: context.eos.spacing.sm),
          EosAttentionBanner(
            headline: a.isEmergency ? 'Emergency' : 'Live alert',
            message: a.headline,
            severity: a.isEmergency ? 'CRITICAL' : 'WARNING',
          ),
        ],
        SizedBox(height: context.eos.spacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: ticket == null ? null : onOpenPass,
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: const Text('Pass / Entry'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenAgenda,
              icon: const Icon(Icons.view_agenda_outlined, size: 18),
              label: const Text('Agenda'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push(AttendeeRoutes.eventDetail(eventId)),
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('Event details'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push(AttendeeRoutes.people(eventId)),
              icon: const Icon(Icons.groups_outlined, size: 18),
              label: const Text('People'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push(AttendeeRoutes.eventServices(eventId)),
              icon: const Icon(Icons.handyman_outlined, size: 18),
              label: const Text('Services'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

class _LiveOverviewTab extends StatelessWidget {
  const _LiveOverviewTab({
    required this.eventId,
    required this.programAsync,
    required this.ticketAsync,
    required this.onFocusSession,
  });

  final String eventId;
  final AsyncValue<ProgramSnapshot> programAsync;
  final AsyncValue<AttendeeEventView?> ticketAsync;
  final ValueChanged<String> onFocusSession;

  @override
  Widget build(BuildContext context) {
    return programAsync.when(
      loading: () => ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: const [_SkeletonCard(), SizedBox(height: 12), _SkeletonCard()],
      ),
      error: (e, _) => ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          EosAttentionBanner(headline: 'Live data unavailable', message: '$e', severity: 'CRITICAL'),
        ],
      ),
      data: (program) {
        final buckets = buildLiveAgendaBuckets(program);
        return ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            Text('Event progress', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: buckets.progressPct),
                  SizedBox(height: context.eos.spacing.sm),
                  Text(
                    '${buckets.completed.length} of ${buckets.all.length} sessions complete',
                    style: context.eosText.bodySmall,
                  ),
                ],
              ),
            ),
            SizedBox(height: context.eos.spacing.lg),
            Text('Current session', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            if (buckets.current == null)
              EosSurfaceCard(
                child: Text('No session is live right now.', style: context.eosText.bodyMedium),
              )
            else
              _SessionCard(
                item: buckets.current!,
                highlight: true,
                onOpen: () => onFocusSession(buckets.current!.id),
              ),
            SizedBox(height: context.eos.spacing.lg),
            Text('Up next', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            if (buckets.upcoming.isEmpty)
              EosSurfaceCard(
                child: Text('No upcoming sessions.', style: context.eosText.bodyMedium),
              )
            else
              _SessionCard(
                item: buckets.upcoming.first,
                onOpen: () => onFocusSession(buckets.upcoming.first.id),
              ),
            SizedBox(height: context.eos.spacing.lg),
            Text('Participation', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticketAsync.valueOrNull?.checkedIn == true
                        ? 'You are checked in — follow the agenda and announcements for live updates.'
                        : 'Check in at Entry to confirm attendance, then return here for live sessions.',
                    style: context.eosText.bodySmall,
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                  Text(
                    'Session updates refresh automatically while this hub is open.',
                    style: context.eosText.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AgendaTab extends StatelessWidget {
  const _AgendaTab({
    required this.eventId,
    required this.programAsync,
    required this.selected,
    required this.focusSessionId,
    required this.onToggle,
  });

  final String eventId;
  final AsyncValue<ProgramSnapshot> programAsync;
  final Set<String> selected;
  final String? focusSessionId;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return programAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (program) {
        final buckets = buildLiveAgendaBuckets(program);
        return ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            Text('Live agenda', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Timeline of sessions — add items to My schedule.',
              style: context.eosText.bodySmall,
            ),
            SizedBox(height: context.eos.spacing.md),
            if (buckets.current != null) ...[
              Text('Now', style: context.eosText.labelMedium),
              SizedBox(height: context.eos.spacing.xs),
              _SessionCard(
                item: buckets.current!,
                highlight: true,
                selected: selected.contains(buckets.current!.id),
                onToggle: () => onToggle(buckets.current!.id),
                focused: focusSessionId == buckets.current!.id,
              ),
              SizedBox(height: context.eos.spacing.md),
            ],
            if (buckets.upcoming.isNotEmpty) ...[
              Text('Upcoming', style: context.eosText.labelMedium),
              SizedBox(height: context.eos.spacing.xs),
              for (final item in buckets.upcoming) ...[
                _SessionCard(
                  item: item,
                  selected: selected.contains(item.id),
                  onToggle: () => onToggle(item.id),
                  focused: focusSessionId == item.id,
                ),
                SizedBox(height: context.eos.spacing.sm),
              ],
              SizedBox(height: context.eos.spacing.md),
            ],
            if (buckets.completed.isNotEmpty) ...[
              Text('Completed', style: context.eosText.labelMedium),
              SizedBox(height: context.eos.spacing.xs),
              for (final item in buckets.completed) ...[
                _SessionCard(
                  item: item,
                  dimmed: true,
                  selected: selected.contains(item.id),
                  onToggle: () => onToggle(item.id),
                  focused: focusSessionId == item.id,
                ),
                SizedBox(height: context.eos.spacing.sm),
              ],
            ],
            if (buckets.all.isEmpty)
              EosSurfaceCard(
                child: Text('No agenda items published yet.', style: context.eosText.bodyMedium),
              ),
          ],
        );
      },
    );
  }
}

class _MyScheduleTab extends StatelessWidget {
  const _MyScheduleTab({
    required this.eventId,
    required this.programAsync,
    required this.selected,
    required this.onToggle,
    required this.onFocus,
  });

  final String eventId;
  final AsyncValue<ProgramSnapshot> programAsync;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onFocus;

  @override
  Widget build(BuildContext context) {
    return programAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (program) {
        final mine = personalSessions(all: program.items, selectedIds: selected);
        final buckets = buildLiveAgendaBuckets(program);
        final nowId = buckets.current?.id;
        final today = mine.where((i) {
          final d = DateTime.now();
          return i.startTime.year == d.year && i.startTime.month == d.month && i.startTime.day == d.day;
        }).toList();
        final upcoming = mine.where((i) => i.id != nowId && i.startTime.isAfter(DateTime.now())).toList();
        final current = mine.where((i) => i.id == nowId).toList();

        return ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            Text('My schedule', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Personal session picks for this event (saved on this device).',
              style: context.eosText.bodySmall,
            ),
            SizedBox(height: context.eos.spacing.md),
            if (mine.isEmpty)
              EosSurfaceCard(
                child: Text(
                  'No sessions saved yet. Open Agenda and tap Add to build your day.',
                  style: context.eosText.bodyMedium,
                ),
              )
            else ...[
              if (current.isNotEmpty) ...[
                Text('Current', style: context.eosText.labelMedium),
                SizedBox(height: context.eos.spacing.xs),
                for (final i in current)
                  _SessionCard(
                    item: i,
                    highlight: true,
                    selected: true,
                    onToggle: () => onToggle(i.id),
                    onOpen: () => onFocus(i.id),
                  ),
                SizedBox(height: context.eos.spacing.md),
              ],
              Text("Today's sessions", style: context.eosText.labelMedium),
              SizedBox(height: context.eos.spacing.xs),
              if (today.isEmpty)
                EosSurfaceCard(child: Text('Nothing scheduled for today.', style: context.eosText.bodySmall))
              else
                for (final i in today) ...[
                  _SessionCard(
                    item: i,
                    selected: true,
                    onToggle: () => onToggle(i.id),
                    onOpen: () => onFocus(i.id),
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                ],
              SizedBox(height: context.eos.spacing.md),
              Text('Upcoming', style: context.eosText.labelMedium),
              SizedBox(height: context.eos.spacing.xs),
              if (upcoming.isEmpty)
                EosSurfaceCard(child: Text('No upcoming personal sessions.', style: context.eosText.bodySmall))
              else
                for (final i in upcoming) ...[
                  _SessionCard(
                    item: i,
                    selected: true,
                    onToggle: () => onToggle(i.id),
                    onOpen: () => onFocus(i.id),
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                ],
            ],
          ],
        );
      },
    );
  }
}

class _UpdatesTab extends StatelessWidget {
  const _UpdatesTab({required this.updatesAsync});
  final AsyncValue<List<AttendeeLiveUpdate>> updatesAsync;

  @override
  Widget build(BuildContext context) {
    return updatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          EosAttentionBanner(headline: 'Updates unavailable', message: '$e', severity: 'CRITICAL'),
        ],
      ),
      data: (items) {
        if (items.isEmpty) {
          return ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              EosSurfaceCard(
                child: Text(
                  'No live announcements yet. Schedule changes and session updates will appear here.',
                  style: context.eosText.bodyMedium,
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            Text('Live announcements', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Schedule, venue, speaker, and emergency alerts for this event.',
              style: context.eosText.bodySmall,
            ),
            SizedBox(height: context.eos.spacing.md),
            for (final u in items) ...[
              EosSurfaceCard(
                accentColor: u.isEmergency
                    ? EosColors.critical
                    : u.isAlert
                        ? EosColors.warning
                        : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(u.headline, style: context.eosText.titleSmall)),
                        Text(_typeLabel(u.type), style: context.eosText.labelSmall),
                      ],
                    ),
                    if (u.detail.trim().isNotEmpty) ...[
                      SizedBox(height: context.eos.spacing.xxs),
                      Text(u.detail, style: context.eosText.bodySmall),
                    ],
                    SizedBox(height: context.eos.spacing.xxs),
                    Text(formatAttendeeDateTime(u.timestamp), style: context.eosText.labelSmall),
                  ],
                ),
              ),
              SizedBox(height: context.eos.spacing.sm),
            ],
          ],
        );
      },
    );
  }

  String _typeLabel(String type) {
    if (type.contains('emergency')) return 'Emergency';
    if (type.contains('venue')) return 'Venue';
    if (type.contains('speaker')) return 'Speaker';
    if (type.contains('schedule') || type.contains('program')) return 'Schedule';
    if (type.contains('alert')) return 'Alert';
    return 'Update';
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.item,
    this.highlight = false,
    this.dimmed = false,
    this.selected = false,
    this.focused = false,
    this.onToggle,
    this.onOpen,
  });

  final ProgramItem item;
  final bool highlight;
  final bool dimmed;
  final bool selected;
  final bool focused;
  final VoidCallback? onToggle;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final progress = sessionElapsedFraction(item);
    final room = sessionRoomHint(item);
    return Opacity(
      opacity: dimmed ? 0.72 : 1,
      child: EosSurfaceCard(
        elevated: highlight || focused,
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.title, style: context.eosText.titleSmall)),
                Chip(label: Text(sessionProgressLabel(item))),
              ],
            ),
            SizedBox(height: context.eos.spacing.xxs),
            Text(
              '${formatProgramTime(item.startTime)} – ${formatProgramTime(item.endTime)}'
              ' · ${item.durationMinutes} min',
              style: context.eosText.bodySmall,
            ),
            if (item.ownerName.trim().isNotEmpty)
              Text('Speaker / host: ${item.ownerName}', style: context.eosText.bodySmall),
            if (room != null) Text(room, style: context.eosText.labelSmall),
            if (item.description.trim().isNotEmpty && room != item.description.trim()) ...[
              SizedBox(height: context.eos.spacing.xxs),
              Text(item.description, style: context.eosText.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (highlight || item.status == 'in_progress') ...[
              SizedBox(height: context.eos.spacing.sm),
              LinearProgressIndicator(value: progress),
            ],
            if (onToggle != null) ...[
              SizedBox(height: context.eos.spacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: selected
                    ? OutlinedButton.icon(
                        onPressed: onToggle,
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        label: const Text('Remove from My schedule'),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: onToggle,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add to My schedule'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 16, width: 160, color: context.eosColors.surfaceContainerHighest),
          SizedBox(height: context.eos.spacing.sm),
          Container(height: 12, width: double.infinity, color: context.eosColors.surfaceContainerHighest),
          SizedBox(height: context.eos.spacing.xs),
          Container(height: 12, width: 200, color: context.eosColors.surfaceContainerHighest),
        ],
      ),
    );
  }
}
