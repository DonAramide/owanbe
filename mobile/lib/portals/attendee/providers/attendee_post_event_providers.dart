import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../core/api/post_event_api.dart';

final eventFeedbackProvider =
    FutureProvider.autoDispose.family<AttendeeFeedbackEnvelope, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) {
    return AttendeeFeedbackEnvelope(canSubmit: false);
  }
  return ref.read(postEventApiProvider).fetchFeedback(session: session, eventId: eventId);
});

Future<void> refreshEventFeedback(WidgetRef ref, String eventId) async {
  ref.invalidate(eventFeedbackProvider(eventId));
  await ref.read(eventFeedbackProvider(eventId).future);
}
