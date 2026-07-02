import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../providers/customer_event_command_providers.dart';
import '../providers/program_providers.dart';
import '../navigation/event_navigator.dart';
import '../widgets/celebration_hero.dart';
import '../workspace/event_module_scaffold.dart';
import '../workspace/widgets/event_error_view.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/program/program_day_widget.dart';
import '../models/home_hub_models.dart';

/// Live operations hub at `/events/:eventId/day`.
class CustomerEventDayScreen extends ConsumerWidget {
  const CustomerEventDayScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(customerEventCommandProvider(eventId));
    final program = ref.watch(eventProgramProvider(eventId));

    return EventModuleScaffold(
      eventId: eventId,
      title: 'Event day',
      subtitle: 'Live operations hub',
      body: snapshot.when(
        loading: () => const EventLoadingSkeleton(),
        error: (_, _) => ListView(
          padding: EosSpacing.pagePadding,
          children: [
            EventErrorView.module(
              moduleLabel: 'event day',
              onRetry: () {
                ref.invalidate(customerEventCommandProvider(eventId));
              },
              onBackToOverview: () => context.eventNav.backToOverview(eventId),
            ),
          ],
        ),
        data: (data) {
          final event = data.event;
          return EventModuleScrollBody(
            hero: CelebrationHero(
              title: event.title,
              subtitle: 'Live now · ${formatEventDate(event.startsAt)}',
              countdownLabel: formatCountdown(event.startsAt, DateTime.now()),
            ),
            primaryKpi: program.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (p) => ProgramDayWidget(
                day: p.day,
                onOpenProgram: () => context.eventNav.openProgram(eventId),
              ),
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EosSection(
                  title: 'Guest check-ins',
                  subtitle: 'Who has arrived',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _DayStat(label: 'Invited', value: '${data.guestInvited}'),
                      _DayStat(label: 'RSVP', value: '${data.guestRsvp}'),
                      _DayStat(label: 'Checked in', value: '${data.guestCheckedIn}'),
                    ],
                  ),
                ),
                EosSection(
                  title: 'Vendor arrivals',
                  subtitle: 'On-site status',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text('${data.vendorAccepted} vendors confirmed'),
                    subtitle: Text('${data.vendorCompleted} completed setup'),
                  ),
                ),
                EosSection(
                  title: 'Celebration wall',
                  subtitle: 'Large-screen display for the venue',
                  child: EosSurfaceCard(
                    onTap: () => context.eventNav.openWallDisplay(eventId),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.tv_outlined, color: EosColors.plum),
                      title: const Text('Open wall display'),
                      subtitle: const Text('Show guest messages on a projector or TV'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
                EosSection(
                  title: 'Emergency',
                  subtitle: 'Key contacts',
                  child: Column(
                    children: const [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.phone_in_talk_outlined),
                        title: Text('Event coordinator'),
                        subtitle: Text('+234 800 OWANBE'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.local_hospital_outlined),
                        title: Text('Venue security'),
                        subtitle: Text('Dial from venue desk'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            activity: data.feed.isEmpty
                ? null
                : EosSection(
                    title: 'Live timeline',
                    subtitle: 'Operations feed',
                    child: Column(
                      children: data.feed.take(8).map(
                            (f) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.bolt_outlined, color: EosColors.plum),
                              title: Text(f.headline),
                              subtitle: Text(f.detail),
                            ),
                          ).toList(),
                    ),
                  ),
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
