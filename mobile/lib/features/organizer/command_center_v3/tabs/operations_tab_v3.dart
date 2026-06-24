import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../eos/eos.dart';
import '../../data/organizer_persistence.dart';
import '../../models/organizer_models.dart';
import '../../../operations/providers/operations_providers.dart';
import '../../providers/organizer_providers.dart';
import '../providers/event_command_center_v3_providers.dart';
import '../widgets/cc_v3_health_cards.dart';

class OperationsTabV3 extends ConsumerWidget {
  const OperationsTabV3({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(eventCommandCenterV3Provider(eventId));
    final feedAsync = ref.watch(operationsFeedProvider(eventId));

    return snapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (snap) => SingleChildScrollView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CcV3SectionHeader(
              title: 'Event operations center',
              subtitle: 'Tasks, day-of status, and emergency contacts',
            ),
            FilledButton.icon(
              onPressed: () {
                ref.read(liveOpsEventIdProvider.notifier).state = eventId;
                ref.read(organizerShellTabProvider.notifier).select(6);
                context.go('/organizer');
              },
              icon: const Icon(Icons.sensors, size: 18),
              label: const Text('Open live operations'),
            ),
            SizedBox(height: context.eos.spacing.lg),
            const CcV3SectionHeader(title: 'Planning checklist'),
            for (final task in snap.operationsTasks)
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: EosSurfaceCard(
                  child: CheckboxListTile(
                    value: task.done,
                    onChanged: null,
                    title: Text(task.label, style: context.eosText.titleSmall),
                    subtitle: Text(task.category, style: context.eosText.bodySmall),
                    secondary: Icon(
                      task.done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: task.done ? EosColors.success : context.eosColors.outline,
                    ),
                  ),
                ),
              ),
            SizedBox(height: context.eos.spacing.xl),
            const CcV3SectionHeader(title: 'Event day status'),
            feedAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => EosSurfaceCard(child: Text('Live feed unavailable', style: context.eosText.bodyMedium)),
              data: (feed) {
                if (feed.isEmpty) {
                  return EosSurfaceCard(
                    child: Text('Go live to see vendor arrivals and guest check-ins.', style: context.eosText.bodyMedium),
                  );
                }
                return Column(
                  children: feed
                      .take(8)
                      .map(
                        (f) => Padding(
                          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                          child: EosSurfaceCard(
                            child: ListTile(
                              leading: const Icon(Icons.bolt_outlined, color: EosColors.plum),
                              title: Text(f.headline),
                              subtitle: Text(f.detail),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            SizedBox(height: context.eos.spacing.xl),
            const CcV3SectionHeader(title: 'Emergency panel'),
            _EmergencyCard(title: 'Event coordinator', contact: '+234 800 OWANBE'),
            SizedBox(height: context.eos.spacing.sm),
            _EmergencyCard(title: 'Venue contact', contact: snap.event.venueName.isNotEmpty ? snap.event.venueName : snap.event.venue),
            SizedBox(height: context.eos.spacing.sm),
            _EmergencyCard(title: 'Backup caterer', contact: 'Golden Pot Catering'),
            if (snap.event.status != OrganizerEventStatus.live)
              Padding(
                padding: EdgeInsets.only(top: context.eos.spacing.lg),
                child: OutlinedButton(
                  onPressed: () async {
                    await goLiveEvent(ref, eventId);
                    bumpOperationsRevision(ref);
                  },
                  child: const Text('Go live now'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.title, required this.contact});
  final String title;
  final String contact;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: ListTile(
        leading: const Icon(Icons.emergency_outlined, color: EosColors.critical),
        title: Text(title, style: context.eosText.titleSmall),
        subtitle: Text(contact),
        trailing: IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
      ),
    );
  }
}
