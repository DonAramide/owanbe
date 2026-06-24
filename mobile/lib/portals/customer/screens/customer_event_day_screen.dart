import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../providers/customer_event_command_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/celebration_hero.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';
import '../models/home_hub_models.dart';

/// Live operations hub at `/events/:eventId/day`.
class CustomerEventDayScreen extends ConsumerWidget {
  const CustomerEventDayScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(customerEventCommandProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: EosColors.plum,
        foregroundColor: Colors.white,
        title: const Text('Event day'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: 'Could not load event day',
              message: e.toString(),
              actionLabel: 'Back',
              onAction: () => context.go(CustomerRoutes.eventDetail(eventId)),
            ),
          ],
        ),
        data: (data) {
          final event = data.event;
          return ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              CelebrationHero(
                title: event.title,
                subtitle: 'Live now · ${formatEventDate(event.startsAt)}',
                countdownLabel: formatCountdown(event.startsAt, DateTime.now()),
              ),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(title: 'Guest check-ins', subtitle: 'Who has arrived'),
              EosSurfaceCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _DayStat(label: 'Invited', value: '${data.guestInvited}'),
                    _DayStat(label: 'RSVP', value: '${data.guestRsvp}'),
                    _DayStat(label: 'Checked in', value: '${data.guestCheckedIn}'),
                  ],
                ),
              ),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(title: 'Vendor arrivals', subtitle: 'On-site status'),
              EosSurfaceCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text('${data.vendorAccepted} vendors confirmed'),
                      subtitle: Text('${data.vendorCompleted} completed setup'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(title: 'Celebration wall', subtitle: 'Large-screen display for the venue'),
              EosSurfaceCard(
                onTap: () => context.push(CustomerRoutes.eventWallDisplay(eventId)),
                child: ListTile(
                  leading: const Icon(Icons.tv_outlined, color: EosColors.plum),
                  title: const Text('Open wall display'),
                  subtitle: const Text('Show guest messages on a projector or TV'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(title: 'Live timeline', subtitle: 'Operations feed'),
              ...data.feed.take(8).map(
                    (f) => ListTile(
                      leading: const Icon(Icons.bolt_outlined, color: EosColors.plum),
                      title: Text(f.headline),
                      subtitle: Text(f.detail),
                    ),
                  ),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(title: 'Emergency', subtitle: 'Key contacts'),
              EosSurfaceCard(
                child: Column(
                  children: const [
                    ListTile(
                      leading: Icon(Icons.phone_in_talk_outlined),
                      title: Text('Event coordinator'),
                      subtitle: Text('+234 800 OWANBE'),
                    ),
                    ListTile(
                      leading: Icon(Icons.local_hospital_outlined),
                      title: Text('Venue security'),
                      subtitle: Text('Dial from venue desk'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayStat extends StatelessWidget {
  const _DayStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: context.eosText.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: context.eosText.bodySmall),
      ],
    );
  }
}
