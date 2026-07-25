import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/customer_event_providers.dart';
import 'organizer_portfolio_models.dart';

/// Enterprise portfolio workspace — aggregates all organizer events (Phase 6).
final organizerPortfolioWorkspaceProvider =
    FutureProvider.autoDispose<OrganizerPortfolioWorkspace>((ref) async {
  ref.watch(customerEventRevisionProvider);
  final events = await ref.watch(customerEventsProvider.future);
  return buildOrganizerPortfolioWorkspace(events);
});

final organizerPortfolioRefreshProvider = StateProvider<int>((ref) => 0);

void refreshOrganizerPortfolio(WidgetRef ref) {
  ref.read(organizerPortfolioRefreshProvider.notifier).state++;
  ref.invalidate(organizerPortfolioWorkspaceProvider);
  ref.invalidate(customerEventsProvider);
}
