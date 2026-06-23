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



class CustomerGuestsScreen extends ConsumerWidget {

  const CustomerGuestsScreen({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final events = ref.watch(customerOwnedEventsProvider);



    return ColoredBox(

      color: EosColors.canvas,

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

          final active = owned.map(CustomerEventSummary.fromOrganizerEvent).toList()

            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));



          if (active.isEmpty) {

            return ListView(

              padding: EdgeInsets.all(context.eos.spacing.lg),

              children: [

                const SectionHeader(

                  title: 'Guests',

                  subtitle: 'Manage invitations, RSVPs, and your guest list in one place.',

                ),

                EmptyStateCard(

                  title: 'No events yet',

                  message: 'Create an event first, then add guests and send beautiful invitations.',

                  icon: Icons.groups_outlined,

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

                title: 'Guests',

                subtitle: 'Choose an event to manage its guest list.',

              ),

              SizedBox(

                height: 200,

                child: ListView.separated(

                  scrollDirection: Axis.horizontal,

                  itemCount: active.length,

                  separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.md),

                  itemBuilder: (context, index) {

                    final event = active[index];

                    return HomeActiveEventCard(

                      event: event,

                      onTap: () => context.push(CustomerRoutes.eventGuests(event.id)),

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

