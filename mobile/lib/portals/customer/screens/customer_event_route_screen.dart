import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/public/screens/event_detail_screen.dart';
import '../providers/customer_event_command_providers.dart';
import 'customer_event_command_center_screen.dart';

/// Routes `/events/:eventId` to the command center for owned events, or public detail otherwise.
class CustomerEventRouteScreen extends ConsumerWidget {
  const CustomerEventRouteScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(customerEventOwnershipProvider(eventId));

    return owned.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => EventDetailScreen(eventId: eventId),
      data: (isOwned) => isOwned
          ? CustomerEventCommandCenterScreen(eventId: eventId)
          : EventDetailScreen(eventId: eventId),
    );
  }
}
