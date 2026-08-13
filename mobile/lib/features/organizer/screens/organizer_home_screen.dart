import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/workspace_models.dart';
import '../../../features/workspace/widgets/workspace_experience_shell.dart';
import '../../../portals/customer/router/customer_routes.dart';
import '../../../theme/theme_mode_provider.dart';
import '../../operations/screens/operations_shell.dart';
import '../providers/organizer_event_list_filters.dart';
import '../providers/organizer_providers.dart';
import 'attendee_management_screen.dart';
import 'event_analytics_screen.dart';
import 'event_management_screen.dart';
import 'organizer_dashboard_screen.dart';
import 'organizer_profile_edit_sheet.dart';
import 'ticket_management_screen.dart';
import 'vendor_management_screen.dart';
import '../team/organization_team_screen.dart';
import '../automation/automations_screen.dart';
import '../marketing/marketing_screen.dart';

class OrganizerHomeScreen extends ConsumerWidget {
  const OrganizerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final tab = ref.watch(organizerShellTabProvider);

    return WorkspaceExperienceShell(
      workspace: ExperienceWorkspace.organizer,
      child: EosAppShell(
        brandLabel: 'Owambe',
        brandSubtitle: 'Organizer Workspace',
        destinations: EosRoleDestinations.organizer,
        selectedIndex: tab,
        onSelected: (v) => ref.read(organizerShellTabProvider.notifier).select(v),
        topBar: _OrganizerTopBar(
          name: session?.displayName ?? 'Organizer',
          onCreateEvent: () => context.push('/organizer/events/new'),
          onBrowseMarketplace: () => context.push(CustomerRoutes.vendors),
          onEditProfile: () => showOrganizerProfileEditor(context, ref),
          onSignOut: () {
            ref.read(authSessionProvider.notifier).signOut();
            context.go(ExperienceNavigation.afterSignOut());
          },
        ),
        body: _bodyForTab(tab),
      ),
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
        7 => const OrganizationTeamScreen(),
        8 => const AutomationsScreen(),
        9 => const MarketingScreen(),
        _ => const OrganizerDashboardScreen(),
      };
}

class _OrganizerTopBar extends ConsumerWidget {
  const _OrganizerTopBar({
    required this.name,
    required this.onCreateEvent,
    required this.onBrowseMarketplace,
    required this.onEditProfile,
    required this.onSignOut,
  });

  final String name;
  final VoidCallback onCreateEvent;
  final VoidCallback onBrowseMarketplace;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return EosAdaptiveTopBarChrome(
      search: EosSearchField(
        hint: 'Search events, vendors, attendees…',
        onChanged: (v) => ref.read(organizerEventSearchQueryProvider.notifier).state = v,
        onSubmitted: (v) {
          ref.read(organizerEventSearchQueryProvider.notifier).state = v;
          ref.read(organizerShellTabProvider.notifier).select(1);
        },
      ),
      primaryActions: [
        EosAdaptiveChromeAction(
          label: 'Marketplace',
          icon: Icons.storefront_outlined,
          onPressed: onBrowseMarketplace,
        ),
        EosAdaptiveChromeAction(
          label: 'Create event',
          icon: Icons.add,
          onPressed: onCreateEvent,
          filled: true,
        ),
      ],
      iconActions: [
        IconButton(
          tooltip: 'Edit Organizer Profile',
          onPressed: onEditProfile,
          icon: const Icon(Icons.manage_accounts_outlined),
        ),
        IconButton(
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () => ref.read(themeModeProvider.notifier).toggleLightDark(),
          icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        ),
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WorkspaceContextActions(),
          IconButton(tooltip: 'Sign out ($name)', onPressed: onSignOut, icon: const Icon(Icons.logout)),
        ],
      ),
    );
  }
}
