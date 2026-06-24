import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../operations/providers/operations_providers.dart';
import '../../finance/organizer_finance_providers.dart';
import '../../providers/organizer_providers.dart';
import '../models/event_command_center_v3_models.dart';

final eventCommandCenterV3Provider = Provider.autoDispose.family<AsyncValue<EventCommandCenterV3Snapshot>, String>(
  (ref, eventId) {
    final eventAsync = ref.watch(organizerEventProvider(eventId));
    final financeAsync = ref.watch(organizerEventFinanceSummaryProvider(eventId));
    final feedAsync = ref.watch(operationsFeedProvider(eventId));

    return eventAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
      data: (event) {
        if (event == null) return AsyncValue.error('Event not found', StackTrace.current);
        final finance = financeAsync.valueOrNull;
        final feed = feedAsync.valueOrNull ?? [];
        return AsyncValue.data(
          buildCommandCenterV3Snapshot(event: event, finance: finance, feed: feed),
        );
      },
    );
  },
);
