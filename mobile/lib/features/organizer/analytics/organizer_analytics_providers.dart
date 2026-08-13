import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import 'organizer_analytics_api.dart';

final organizerAnalyticsApiProvider = Provider<OrganizerAnalyticsApi>((ref) => OrganizerAnalyticsApi());

/// Window for series buckets (7 / 30 / 90). Does not invent missing days.
final organizerAnalyticsDaysProvider = StateProvider.autoDispose.family<int, String>((ref, eventId) => 30);

final organizerAnalyticsProvider =
    FutureProvider.autoDispose.family<EventAnalyticsSnapshot, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  final days = ref.watch(organizerAnalyticsDaysProvider(eventId));
  return ref.read(organizerAnalyticsApiProvider).fetchEventIntelligence(
        eventId: eventId,
        days: days,
        session: session,
      );
});

final organizerAnalyticsPortfolioProvider =
    FutureProvider.autoDispose<List<PortfolioAnalyticsItem>>((ref) async {
  final session = ref.watch(authSessionProvider);
  return ref.read(organizerAnalyticsApiProvider).fetchPortfolio(session: session);
});

void invalidateEventAnalytics(WidgetRef ref, String eventId) {
  ref.invalidate(organizerAnalyticsProvider(eventId));
  ref.invalidate(organizerAnalyticsPortfolioProvider);
}
