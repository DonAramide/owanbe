import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/owambe_api_auth.dart';

/// Active event operating context injected into Event OS modules (Phase 2).
///
/// [eventId] is always supplied by the route or launcher.
/// [tenantId] and [organizerId] are resolved from the authenticated session.
class EventOperatingContext {
  const EventOperatingContext({
    required this.eventId,
    required this.tenantId,
    this.organizerId,
    this.workspaceId,
  });

  final String eventId;
  final String tenantId;
  final String? organizerId;

  /// Event workspace entity id — same as [eventId] for organizer flows.
  final String? workspaceId;
}

/// Resolves operating context for a given event module route.
final eventOperatingContextProvider = Provider.family<EventOperatingContext, String>(
  (ref, eventId) {
    final session = ref.watch(authSessionProvider);
    return EventOperatingContext(
      eventId: eventId,
      tenantId: OwambeApiAuth.resolveTenantId(),
      organizerId: session?.userId,
      workspaceId: eventId,
    );
  },
);
