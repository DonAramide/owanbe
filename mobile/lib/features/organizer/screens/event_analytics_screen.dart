import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../command_center_v3/tabs/analytics_tab_v3.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_shared.dart';

class EventAnalyticsScreen extends ConsumerWidget {
  const EventAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = ref.watch(selectedOrganizerEventIdProvider);

    return EosPageScaffold(
      title: 'Event analytics',
      subtitle: 'Same intelligence surface as Event Workspace Analytics',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OrganizerEventPicker(),
          SizedBox(height: context.eos.spacing.lg),
          if (eventId == null)
            EosSurfaceCard(child: Text('Select an event', style: context.eosText.bodyMedium))
          else
            AnalyticsTabV3(eventId: eventId, nestedInParentScroll: true),
        ],
      ),
    );
  }
}
