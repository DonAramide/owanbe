import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../../operations/screens/operations_shell.dart';
import '../providers/organizer_providers.dart';
import 'attendee_management_screen.dart';
import 'event_analytics_screen.dart';
import 'event_management_screen.dart';
import 'organizer_dashboard_screen.dart';
import 'ticket_management_screen.dart';
import 'vendor_management_screen.dart';

class OrganizerHomeScreen extends ConsumerWidget {
  const OrganizerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final tab = ref.watch(organizerShellTabProvider);

    return EosAppShell(
      brandLabel: 'Owanbe',
      brandSubtitle: 'Organizer Portal',
      destinations: EosRoleDestinations.organizer,
      selectedIndex: tab,
      onSelected: (v) => ref.read(organizerShellTabProvider.notifier).select(v),
      topBar: _OrganizerTopBar(
        name: session?.displayName ?? 'Organizer',
        onCreateEvent: () => context.push('/organizer/events/new'),
        onSignOut: () {
          ref.read(authSessionProvider.notifier).signOut();
          context.go('/');
        },
      ),
      body: _bodyForTab(tab),
    );
  }

  Widget _bodyForTab(int index) => switch (index) {
        0 => const OrganizerDashboardScreen(),
        1 => const EventManagementScreen(),
        2 => const TicketManagementScreen(),
        3 => const VendorManagementScreen(),
        4 => const AttendeeManagementScreen(),
        5 => const EventAnalyticsScreen(),
        6 => const OperationsShell(),
        _ => const OrganizerDashboardScreen(),
      };
}

class _OrganizerTopBar extends StatelessWidget {
  const _OrganizerTopBar({
    required this.name,
    required this.onCreateEvent,
    required this.onSignOut,
  });

  final String name;
  final VoidCallback onCreateEvent;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.eosColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant))),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg, vertical: context.eos.spacing.sm),
          child: Row(
            children: [
              Expanded(child: EosSearchField(hint: 'Search events, vendors, attendees…')),
              SizedBox(width: context.eos.spacing.sm),
              FilledButton.icon(
                onPressed: onCreateEvent,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create event'),
              ),
              SizedBox(width: context.eos.spacing.sm),
              Text(name, style: context.eosText.titleSmall),
              IconButton(onPressed: onSignOut, icon: const Icon(Icons.logout)),
            ],
          ),
        ),
      ),
    );
  }
}
