import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/public_models.dart';
import '../providers/public_providers.dart';
import '../widgets/public_event_hero.dart';
import '../widgets/public_shell_mixin.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(publicEventProvider(eventId));

    return buildPublicShell(
      context: context,
      ref: ref,
      child: eventAsync.when(
        data: (event) {
          if (event == null) {
            return Center(child: Text('Event not found', style: context.eosText.titleMedium));
          }
          return SingleChildScrollView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PublicEventHero(
                  event: event,
                  onCta: () => context.push('/events/$eventId/tickets'),
                ),
                SizedBox(height: context.eos.spacing.xl),
                EosSection(
                  title: 'About this event',
                  child: Text(event.description, style: context.eosText.bodyLarge),
                ),
                EosSection(
                  title: 'Good to know',
                  child: EosSurfaceCard(
                    child: Column(
                      children: [
                        _InfoRow(icon: Icons.schedule, label: 'Duration', value: _duration(event)),
                        Divider(height: context.eos.spacing.lg),
                        _InfoRow(icon: Icons.people_outline, label: 'Attending', value: '${event.attendeeCount ?? 0}+'),
                        Divider(height: context.eos.spacing.lg),
                        _InfoRow(icon: Icons.category_outlined, label: 'Category', value: event.category),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.push('/events/$eventId/tickets'),
                    child: const Text('Select tickets'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  String _duration(PublicEvent event) {
    final diff = event.endsAt.difference(event.startsAt);
    final hours = diff.inHours;
    return hours > 0 ? '~$hours hours' : '${diff.inMinutes} min';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.eosColors.primary),
        SizedBox(width: context.eos.spacing.sm),
        Text(label, style: context.eosText.labelMedium),
        const Spacer(),
        Text(value, style: context.eosText.bodyMedium),
      ],
    );
  }
}
