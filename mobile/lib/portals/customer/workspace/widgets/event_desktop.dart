import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../../core/utils/money.dart';

import '../../../../eos/eos.dart';

import '../../../../eos/layout/workspace/workspace_definition.dart';

import '../../../../eos/layout/workspace/workspace_widgets.dart';

import '../../models/command_center_models.dart';

import '../../closing/event_closing_actions.dart';
import '../../closing/event_closing_workspace_provider.dart';
import '../../operations/event_operations_models.dart';

import '../../operations/event_operations_workspace_provider.dart';

import '../../planning/event_planning_workspace_provider.dart';

import '../../providers/customer_event_command_providers.dart';

import '../../widgets/command_center/command_activity_feed.dart';

import '../event_module_registry.dart';

import 'event_closing_center.dart';

import 'event_desktop_hero.dart';

import 'event_operations_center.dart';

import 'event_planning_center.dart';

import 'event_workspace_module_sections.dart';



/// Event Operating System desktop — adapts between planning and execution (Phase 4).

class EventDesktop extends ConsumerWidget {

  const EventDesktop({

    super.key,

    required this.eventId,

    required this.snapshot,

  });



  final String eventId;

  final EventCommandCenterSnapshot snapshot;



  int _daysUntil(DateTime startsAt) {

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final eventDay = DateTime(startsAt.year, startsAt.month, startsAt.day);

    return eventDay.difference(today).inDays;

  }



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final event = snapshot.event;

    final daysUntil = _daysUntil(event.startsAt);

    final modeAsync = ref.watch(eventDesktopModeProvider(eventId));
    final isArchived = ref.watch(archivedEventIdsProvider).contains(eventId);



    return RefreshIndicator(

      onRefresh: () async {

        ref.invalidate(customerEventCommandProvider(eventId));

        ref.invalidate(eventPlanningWorkspaceProvider(eventId));

        ref.invalidate(eventOperationsWorkspaceProvider(eventId));

        ref.invalidate(eventClosingWorkspaceProvider(eventId));

        ref.invalidate(eventDesktopModeProvider(eventId));

        await ref.read(customerEventCommandProvider(eventId).future);

      },

      child: ListView(

        physics: const AlwaysScrollableScrollPhysics(),

        padding: EdgeInsets.all(context.eos.spacing.lg),

        children: [

          EventDesktopHero(event: event, daysUntil: daysUntil),

          SizedBox(height: context.eos.spacing.lg),

          modeAsync.when(

            loading: () => _primarySurface(

              context,

              mode: EventDesktopMode.planning,

              eventId: eventId,

              snapshot: snapshot,

            ),

            error: (_, __) => _primarySurface(

              context,

              mode: EventDesktopMode.planning,

              eventId: eventId,

              snapshot: snapshot,

            ),

            data: (mode) => _primarySurface(

              context,

              mode: mode,

              eventId: eventId,

              snapshot: snapshot,

              isArchived: isArchived,

            ),

          ),

          SizedBox(height: context.eos.spacing.xl),

          const Divider(),

          SizedBox(height: context.eos.spacing.md),

          Text('Open a module', style: context.eosText.titleMedium),

          SizedBox(height: context.eos.spacing.xs),

          Text(

            'Jump directly into guests, vendors, tickets, and more.',

            style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),

          ),

          SizedBox(height: context.eos.spacing.lg),

          EventWorkspaceModuleSections(

            eventId: eventId,

            snapshot: snapshot,

            sections: EventModuleRegistry.desktopSections(snapshot.event, snapshot),

          ),

          SizedBox(height: context.eos.spacing.md),

          EventWorkspaceQuickActions(eventId: eventId, snapshot: snapshot),

          SizedBox(height: context.eos.spacing.xl),

          const Divider(),

          SizedBox(height: context.eos.spacing.md),

          Text('Recent activity', style: context.eosText.titleMedium),

          SizedBox(height: context.eos.spacing.md),

          CommandActivityFeed(items: snapshot.feed),

          SizedBox(height: context.eos.spacing.lg),

          WorkspaceRelationshipGraph(

            currentType: WorkspaceEntityType.event,

            entityId: eventId,

          ),

          SizedBox(height: context.eos.spacing.lg),

          LayoutBuilder(

            builder: (context, constraints) {

              final wide = constraints.maxWidth >= 700;

              final kpis = [

                EosKpiCard(

                  title: 'Capacity',

                  value: '${event.totalCapacity > 0 ? event.totalCapacity : event.expectedGuests}',

                  subtitle: 'Expected guests',

                ),

                EosKpiCard(

                  title: 'Tickets sold',

                  value: '${event.ticketsSold}',

                  subtitle: 'Registered passes',

                ),

                EosKpiCard(

                  title: 'Revenue',

                  value: formatRevenue(event.revenueMinor),

                  subtitle: 'Ticket sales',

                ),

              ];

              if (wide) {

                return Row(

                  children: [

                    for (var i = 0; i < kpis.length; i++) ...[

                      if (i > 0) SizedBox(width: context.eos.spacing.md),

                      Expanded(child: kpis[i]),

                    ],

                  ],

                );

              }

              return Column(

                children: [

                  for (final kpi in kpis) ...[

                    kpi,

                    SizedBox(height: context.eos.spacing.sm),

                  ],

                ],

              );

            },

          ),

          SizedBox(height: context.eos.spacing.lg),

        ],

      ),

    );

  }



  Widget _primarySurface(

    BuildContext context, {

    required EventDesktopMode mode,

    required String eventId,

    required EventCommandCenterSnapshot snapshot,

    bool isArchived = false,

  }) {

    return switch (mode) {

      EventDesktopMode.planning => EventPlanningCenter(

          eventId: eventId,

          fallbackSnapshot: snapshot,

        ),

      EventDesktopMode.execution => Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            EventOperationsCenter(

              eventId: eventId,

              fallbackMode: mode,

            ),

            SizedBox(height: context.eos.spacing.lg),

            ExpansionTile(

              tilePadding: EdgeInsets.zero,

              title: Text('Planning details', style: context.eosText.titleSmall),

              subtitle: Text(

                'Background planning view',

                style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),

              ),

              children: [

                EventPlanningCenter(eventId: eventId, fallbackSnapshot: snapshot),

              ],

            ),

          ],

        ),

      EventDesktopMode.closing => EventClosingCenter(

          eventId: eventId,

          fallbackSnapshot: snapshot,

          isArchived: false,

        ),

      EventDesktopMode.archived => EventClosingCenter(

          eventId: eventId,

          fallbackSnapshot: snapshot,

          isArchived: true,

        ),

    };

  }

}


