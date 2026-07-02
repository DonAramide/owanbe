import 'package:flutter/material.dart';

import '../../../portals/customer/workspace/legacy_organizer_workspace_adapter.dart';

/// Legacy Organizer Command Center V3 — compatibility wrapper only (Phase 42.3).
///
/// Renders the canonical Customer [EventWorkspace] via [LegacyOrganizerWorkspaceAdapter].
/// Tab UI and duplicate dashboards are no longer mounted.
@Deprecated('Compatibility only — routes redirect to /events/:eventId')
class EventWorkspaceScreen extends StatelessWidget {
  const EventWorkspaceScreen({
    super.key,
    required this.eventId,
    this.initialTab = 0,
    this.initialTabKey,
  });

  final String eventId;
  final int initialTab;
  final String? initialTabKey;

  @override
  Widget build(BuildContext context) {
    return LegacyOrganizerWorkspaceAdapter(
      eventId: eventId,
      initialTab: initialTab,
      initialTabKey: initialTabKey,
    );
  }
}
