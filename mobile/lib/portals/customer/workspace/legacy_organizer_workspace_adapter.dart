import 'package:flutter/material.dart';

import 'event_module_registry.dart';
import 'event_workspace.dart';

/// Compatibility wrapper — legacy Organizer routes load the canonical [EventWorkspace].
///
/// Do not render Command Center V3 tabs independently.
class LegacyOrganizerWorkspaceAdapter extends StatefulWidget {
  const LegacyOrganizerWorkspaceAdapter({
    super.key,
    required this.eventId,
    this.initialTab = 0,
    this.initialTabKey,
  });

  final String eventId;
  final int initialTab;
  final String? initialTabKey;

  @override
  State<LegacyOrganizerWorkspaceAdapter> createState() => _LegacyOrganizerWorkspaceAdapterState();
}

class _LegacyOrganizerWorkspaceAdapterState extends State<LegacyOrganizerWorkspaceAdapter> {
  var _handledLegacyNav = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeOpenLegacyModule();
  }

  void _maybeOpenLegacyModule() {
    if (_handledLegacyNav) return;
    final tabKey = widget.initialTabKey?.trim();
    final hasTabKey = tabKey != null && tabKey.isNotEmpty && tabKey != 'overview';
    final hasLegacyIndex = widget.initialTab > 0;
    if (!hasTabKey && !hasLegacyIndex) return;

    _handledLegacyNav = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (hasTabKey) {
        EventModuleRegistry.openLegacyTab(context, widget.eventId, tabKey!);
      } else {
        EventModuleRegistry.openLegacyTabIndex(context, widget.eventId, widget.initialTab);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return EventWorkspace(eventId: widget.eventId);
  }
}
