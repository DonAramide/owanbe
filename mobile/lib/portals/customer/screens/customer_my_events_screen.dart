import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import '../../../eos/eos.dart';

import '../providers/customer_home_providers.dart';

import '../router/customer_routes.dart';

import '../widgets/empty_state_card.dart';

import '../widgets/home/home_active_event_card.dart';

import '../widgets/section_header.dart';

import '../models/home_hub_models.dart';



class CustomerMyEventsScreen extends ConsumerWidget {

  const CustomerMyEventsScreen({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final events = ref.watch(customerOwnedEventsProvider);



    return ColoredBox(

      color: context.eosCanvas,

      child: events.when(

        loading: () => const Center(child: CircularProgressIndicator()),

        error: (error, _) => ListView(

          padding: EdgeInsets.all(context.eos.spacing.lg),

          children: [

            EmptyStateCard(

              title: 'Could not load events',

              message: error.toString(),

              actionLabel: 'Create event',

              onAction: () => context.go(CustomerRoutes.createEvent),

            ),

          ],

        ),

        data: (owned) {

          final active = owned

              .map(CustomerEventSummary.fromOrganizerEvent)

              .toList()

            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));



          if (active.isEmpty) {

            return ListView(

              padding: EdgeInsets.all(context.eos.spacing.lg),

              children: [

                const SectionHeader(

                  title: 'My events',

                  subtitle: 'Every celebration you are planning lives here.',

                ),

                EmptyStateCard(

                  title: 'No events yet',

                  message:

                      'When you create an event, it becomes your command center for guests, vendors, and the big day.',

                  actionLabel: 'Create event',

                  onAction: () => context.go(CustomerRoutes.createEvent),

                ),

              ],

            );

          }



          return ListView(

            padding: EdgeInsets.all(context.eos.spacing.lg),

            children: [

              const SectionHeader(

                title: 'My events',

                subtitle: 'Tap an event to open your command center.',

              ),

              SizedBox(

                height: 216,

                child: ListView.separated(

                  scrollDirection: Axis.horizontal,

                  itemCount: active.length,

                  separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.md),

                  itemBuilder: (context, index) {

                    final event = active[index];

                    return HomeActiveEventCard(

                      event: event,

                      onTap: () => context.push(CustomerRoutes.eventDetail(event.id)),

                    );

                  },

                ),

              ),

            ],

          );

        },

      ),

    );

  }

}

