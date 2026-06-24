import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../eos/eos.dart';
import '../../../../shared/models/event_access_mode.dart';
import '../../data/organizer_persistence.dart';
import '../../models/organizer_models.dart';
import '../../providers/organizer_providers.dart';
import '../widgets/cc_v3_health_cards.dart';

class SettingsTabV3 extends ConsumerWidget {
  const SettingsTabV3({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(organizerEventProvider(eventId));

    return eventAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (event) {
        if (event == null) return const Center(child: Text('Event not found'));
        return SingleChildScrollView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CcV3SectionHeader(title: 'Event settings', subtitle: 'Details, permissions, and preferences'),
              _SettingsTile(
                icon: Icons.celebration_outlined,
                title: 'Event details',
                subtitle: '${event.title} · ${event.category}',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Theme & invitation design',
                subtitle: 'Colors, templates, and celebration style',
                onTap: () => context.push('/events/$eventId/invitations'),
              ),
              _SettingsTile(
                icon: Icons.people_outline,
                title: 'Guest permissions',
                subtitle: 'Who can RSVP, plus-one rules, visibility',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.storefront_outlined,
                title: 'Vendor permissions',
                subtitle: 'Marketplace access and contract approvals',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Budget controls',
                subtitle: 'Spending limits and release approvals',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notification preferences',
                subtitle: 'SMS, email, and push for vendors & guests',
                onTap: () {},
              ),
              SizedBox(height: context.eos.spacing.lg),
              EosSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Event access', style: context.eosText.titleSmall),
                    Text(event.eventAccessMode.label, style: context.eosText.bodyMedium),
                    SizedBox(height: context.eos.spacing.sm),
                    Text('Venue', style: context.eosText.titleSmall),
                    Text('${event.venue}, ${event.city}', style: context.eosText.bodyMedium),
                    if (event.tags.isNotEmpty) ...[
                      SizedBox(height: context.eos.spacing.sm),
                      Wrap(
                        spacing: context.eos.spacing.xs,
                        children: [for (final t in event.tags) Chip(label: Text(t))],
                      ),
                    ],
                  ],
                ),
              ),
              if (event.status == OrganizerEventStatus.draft) ...[
                SizedBox(height: context.eos.spacing.lg),
                FilledButton(
                  onPressed: () => publishEvent(ref, eventId),
                  child: const Text('Publish event'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: EosSurfaceCard(
        onTap: onTap,
        child: ListTile(
          leading: Icon(icon, color: EosColors.plum),
          title: Text(title, style: context.eosText.titleSmall),
          subtitle: Text(subtitle, style: context.eosText.bodySmall),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
