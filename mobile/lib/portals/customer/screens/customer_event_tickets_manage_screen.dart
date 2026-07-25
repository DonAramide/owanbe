import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/organizer/command_center_v3/tabs/tickets_tab_v3.dart';
import '../workspace/event_module_scaffold.dart';

/// Organizer ticket management at `/events/:eventId/tickets/manage`.
///
/// Attendee purchase remains at `/events/:eventId/tickets` ([TicketSelectScreen]).
class CustomerEventTicketsManageScreen extends ConsumerWidget {
  const CustomerEventTicketsManageScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EventModuleScaffold(
      eventId: eventId,
      title: 'Ticket management',
      subtitle: 'Tiers, capacity, and sales',
      body: TicketsTabV3(eventId: eventId),
    );
  }
}
