import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_workspace_reminder_models.dart';
import 'customer_event_command_providers.dart';

final customerWorkspaceRemindersProvider =
    FutureProvider.autoDispose.family<CustomerWorkspaceRemindersSnapshot, String>((ref, eventId) async {
  final snap = await ref.watch(customerEventCommandProvider(eventId).future);
  return buildCustomerWorkspaceRemindersSnapshot(snap);
});
