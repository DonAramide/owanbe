import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../providers/operations_providers.dart';
import '../widgets/operations_shared.dart';
import 'check_in_center_screen.dart';
import 'event_command_center_screen.dart';
import 'event_health_screen.dart';
import 'incident_center_screen.dart';
import 'live_event_feed_screen.dart';
import 'operations_dashboard_screen.dart';
import 'qr_scan_screen.dart';
import 'vendor_ops_monitor_screen.dart';

class OperationsShell extends ConsumerWidget {
  const OperationsShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(operationsShellTabProvider);
    final eventId = ref.watch(liveOpsEventIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.eos.spacing.lg,
            context.eos.spacing.md,
            context.eos.spacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const EosLiveIndicator(),
                  SizedBox(width: context.eos.spacing.sm),
                  Expanded(
                    child: Text(
                      'Live Event Operations',
                      style: context.eosText.titleLarge,
                    ),
                  ),
                  if (eventId != null)
                    TextButton(
                      onPressed: () => ref.read(operationsShellTabProvider.notifier).select(6),
                      child: const Text('Command center'),
                    ),
                ],
              ),
              SizedBox(height: context.eos.spacing.sm),
              const LiveOpsEventPicker(),
              SizedBox(height: context.eos.spacing.sm),
              const OpsModuleChipBar(),
            ],
          ),
        ),
        Expanded(child: _bodyForTab(tab, eventId)),
      ],
    );
  }

  Widget _bodyForTab(int index, String? eventId) {
    if (eventId == null) {
      return const Center(child: Text('Select a live event to begin operations'));
    }
    return switch (index) {
      0 => OperationsDashboardScreen(eventId: eventId),
      1 => CheckInCenterScreen(eventId: eventId),
      2 => QrScanScreen(eventId: eventId),
      3 => LiveEventFeedScreen(eventId: eventId),
      4 => VendorOpsMonitorScreen(eventId: eventId),
      5 => IncidentCenterScreen(eventId: eventId),
      6 => EventCommandCenterScreen(eventId: eventId),
      7 => EventHealthScreen(eventId: eventId),
      _ => OperationsDashboardScreen(eventId: eventId),
    };
  }
}
