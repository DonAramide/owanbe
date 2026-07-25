import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../features/workspace/widgets/workspace_experience_shell.dart';
import '../../../identity/workspace_models.dart';
import '../../../portals/attendee/widgets/attendee_discover_tab.dart';
import '../../../portals/attendee/widgets/attendee_schedule_tab.dart';
import '../../../portals/attendee/widgets/attendee_tickets_tab.dart';
import '../../../portals/attendee/widgets/attendee_top_bar.dart';

/// Attendee Workspace — immersive guest experience isolated from the public marketplace.
class AttendeeDashboardScreen extends ConsumerStatefulWidget {
  const AttendeeDashboardScreen({super.key});

  @override
  ConsumerState<AttendeeDashboardScreen> createState() => _AttendeeDashboardScreenState();
}

class _AttendeeDashboardScreenState extends ConsumerState<AttendeeDashboardScreen> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) {
    return WorkspaceExperienceShell(
      workspace: ExperienceWorkspace.attendee,
      child: EosAppShell(
        brandLabel: 'Owambe',
        brandSubtitle: 'Attendee Workspace',
        destinations: EosRoleDestinations.attendee,
        selectedIndex: _tab,
        onSelected: (index) => setState(() => _tab = index),
        topBar: const AttendeeTopBar(),
        body: IndexedStack(
          index: _tab,
          sizing: StackFit.expand,
          children: [
            const SizedBox.expand(child: AttendeeDiscoverTab()),
            SizedBox.expand(
              child: AttendeeTicketsTab(
                onDiscover: () => setState(() => _tab = 0),
                onSchedule: () => setState(() => _tab = 2),
              ),
            ),
            const SizedBox.expand(child: AttendeeScheduleTab()),
          ],
        ),
      ),
    );
  }
}
