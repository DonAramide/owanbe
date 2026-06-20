import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../data/vendor_persistence.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_shared.dart';

class EventParticipationScreen extends ConsumerWidget {
  const EventParticipationScreen({super.key});

  static const _stages = ParticipationLifecycle.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(participationLifecycleFilterProvider);
    final participations = ref.watch(vendorParticipationsByLifecycleProvider(filter));

    return EosPageScaffold(
      title: 'Event participation',
      subtitle: 'Invited → Applied → Approved → Completed',
      floatingHeader: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final stage in _stages)
              Padding(
                padding: EdgeInsets.only(right: context.eos.spacing.xs),
                child: FilterChip(
                  label: Text(lifecycleTitle(stage)),
                  selected: filter == stage,
                  onSelected: (_) => ref.read(participationLifecycleFilterProvider.notifier).state = stage,
                ),
              ),
          ],
        ),
      ),
      body: participations.when(
        data: (list) {
          if (list.isEmpty) {
            return EosSurfaceCard(
              child: Padding(
                padding: EdgeInsets.all(context.eos.spacing.lg),
                child: Text(
                  _emptyMessage(filter),
                  style: context.eosText.bodyMedium,
                ),
              ),
            );
          }
          return Column(
            children: [
              if (filter == ParticipationLifecycle.invited)
                EosAttentionBanner(
                  headline: 'Organizer invitations',
                  message: 'Accept invites or apply to newly published events.',
                  severity: 'INFO',
                ),
              for (final p in list)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: VendorParticipationCard(
                    participation: p,
                    trailing: _actions(context, ref, p),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }

  String _emptyMessage(ParticipationLifecycle stage) => switch (stage) {
        ParticipationLifecycle.invited => 'No invitations right now. Published events appear here when organizers invite you.',
        ParticipationLifecycle.applied => 'No pending applications. Apply from Invited events.',
        ParticipationLifecycle.approved => 'No approved events yet. Accept invites or wait for organizer approval.',
        ParticipationLifecycle.completed => 'Completed events will appear here after you finish participating.',
      };

  Widget? _actions(BuildContext context, WidgetRef ref, VendorEventParticipation p) {
    if (p.lifecycleStage == ParticipationLifecycle.invited) {
      if (p.id.startsWith('disc_')) {
        return FilledButton(
          onPressed: () async {
            await applyToEvent(ref, p.eventId);
            ref.read(participationLifecycleFilterProvider.notifier).state = ParticipationLifecycle.applied;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application submitted')),
              );
            }
          },
          child: const Text('Apply'),
        );
      }
      return FilledButton(
        onPressed: () async {
          await acceptParticipation(ref, p);
          ref.read(participationLifecycleFilterProvider.notifier).state = ParticipationLifecycle.approved;
        },
        child: const Text('Accept'),
      );
    }
    if (p.lifecycleStage == ParticipationLifecycle.approved) {
      return OutlinedButton(
        onPressed: () {
          ref.read(selectedVendorEventIdProvider.notifier).state = p.eventId;
          ref.read(vendorShellTabProvider.notifier).select(3);
        },
        child: const Text('Orders'),
      );
    }
    return null;
  }
}
