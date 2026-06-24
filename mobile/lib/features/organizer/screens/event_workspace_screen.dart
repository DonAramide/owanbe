import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../command_center_v3/tabs/analytics_tab_v3.dart';
import '../command_center_v3/tabs/attendees_tab_v3.dart';
import '../command_center_v3/tabs/finance_tab_v3.dart';
import '../command_center_v3/tabs/marketplace_tab_v3.dart';
import '../command_center_v3/tabs/operations_tab_v3.dart';
import '../command_center_v3/tabs/overview_tab_v3.dart';
import '../command_center_v3/tabs/settings_tab_v3.dart';
import '../command_center_v3/tabs/tickets_tab_v3.dart';
import '../command_center_v3/tabs/vendors_tab_v3.dart';
import '../command_center_v3/workspace_tabs.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_shared.dart';

/// Per-event Command Center V3 — planning-first, access-mode aware.
class EventWorkspaceScreen extends ConsumerStatefulWidget {
  const EventWorkspaceScreen({
    super.key,
    required this.eventId,
    this.initialTab = 0,
    this.initialTabKey,
  });

  final String eventId;
  final int initialTab;
  final String? initialTabKey;

  @override
  ConsumerState<EventWorkspaceScreen> createState() => _EventWorkspaceScreenState();
}

class _EventWorkspaceScreenState extends ConsumerState<EventWorkspaceScreen> {
  EventWorkspaceTab? _tab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedOrganizerEventIdProvider.notifier).state = widget.eventId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(organizerEventProvider(widget.eventId));

    return Scaffold(
      backgroundColor: context.eosCanvas,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/organizer')),
        title: eventAsync.when(
          data: (e) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e?.title ?? 'Event command center', style: context.eosText.titleMedium),
              if (e != null)
                Text(
                  e.isPrivateCelebration ? 'Celebration planning' : 'Public event',
                  style: context.eosText.labelSmall,
                ),
            ],
          ),
          loading: () => const Text('Event command center'),
          error: (_, _) => const Text('Event command center'),
        ),
        actions: [
          eventAsync.whenOrNull(
            data: (e) {
              if (e == null) return null;
              return Row(
                children: [
                  EosFinanceChip(label: organizerStatusLabel(e.status)),
                  if (e.status == OrganizerEventStatus.live) ...[
                    SizedBox(width: context.eos.spacing.xs),
                    const EosLiveIndicator(compact: true),
                  ],
                  SizedBox(width: context.eos.spacing.sm),
                ],
              );
            },
          ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: eventAsync.when(
        data: (event) {
          if (event == null) return const Center(child: Text('Event not found'));
          final tabs = workspaceTabsFor(event);
          _tab ??= resolveWorkspaceTab(
            event,
            tabKey: widget.initialTabKey,
            legacyIndex: widget.initialTab,
          );
          final active = tabs.contains(_tab!) ? _tab! : EventWorkspaceTab.overview;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.eos.spacing.lg,
                  context.eos.spacing.md,
                  context.eos.spacing.lg,
                  0,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tab in tabs)
                        Padding(
                          padding: EdgeInsets.only(right: context.eos.spacing.xs),
                          child: FilterChip(
                            label: Text(tab.label),
                            selected: active == tab,
                            onSelected: (_) {
                              setState(() => _tab = tab);
                              ref.read(eventWorkspaceTabProvider.notifier).state =
                                  workspaceTabIndex(event, tab);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(child: _bodyForTab(active, event.id)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _bodyForTab(EventWorkspaceTab tab, String eventId) {
    void navigate(EventWorkspaceTab t) => setState(() => _tab = t);
    return switch (tab) {
      EventWorkspaceTab.overview => OverviewTabV3(eventId: eventId, onNavigateTab: navigate),
      EventWorkspaceTab.tickets => TicketsTabV3(eventId: eventId),
      EventWorkspaceTab.attendees => AttendeesTabV3(eventId: eventId),
      EventWorkspaceTab.vendors => VendorsTabV3(eventId: eventId),
      EventWorkspaceTab.marketplace => MarketplaceTabV3(eventId: eventId),
      EventWorkspaceTab.finance => FinanceTabV3(eventId: eventId),
      EventWorkspaceTab.operations => OperationsTabV3(eventId: eventId),
      EventWorkspaceTab.analytics => AnalyticsTabV3(eventId: eventId, onNavigateTab: navigate),
      EventWorkspaceTab.settings => SettingsTabV3(eventId: eventId),
    };
  }
}
