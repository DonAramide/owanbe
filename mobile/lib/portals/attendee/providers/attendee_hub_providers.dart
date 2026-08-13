import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/guest_invitations_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../core/api/ticket_commerce_api.dart';
import '../../../features/home/providers/living_home_providers.dart';
import '../../../features/public/data/recently_viewed_events_store.dart';
import '../../../features/public/data/saved_events_store.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/models/public_models.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/public_providers.dart';
import '../../../features/public/providers/ticket_commerce_providers.dart';
import '../../../portals/attendee/commerce/purchase_notifications_provider.dart';
import '../../../portals/customer/models/home_hub_models.dart';

final guestInvitationsApiProvider = Provider<GuestInvitationsApi>((ref) => GuestInvitationsApi());

/// After RSVP confirm/decline, refresh invitations + ticket passes so My Events updates.
void invalidateAttendeePassesAfterRsvp(WidgetRef ref) {
  ref.invalidate(attendeeGuestInvitationsProvider);
  ref.invalidate(attendeeTicketsSyncProvider);
  ref.invalidate(attendeeEventsProvider);
  ref.invalidate(myEventsBundleProvider);
}

/// Pending + answered RSVP invitations for the signed-in attendee.
final attendeeGuestInvitationsProvider =
    FutureProvider.autoDispose<List<GuestInvitationItem>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  try {
    return await ref.read(guestInvitationsApiProvider).fetchMine(session);
  } catch (_) {
    return const [];
  }
});

final attendeePendingRsvpProvider = Provider.autoDispose<AsyncValue<List<GuestInvitationItem>>>((ref) {
  return ref.watch(attendeeGuestInvitationsProvider).whenData(
        (items) => items.where((i) => i.isPending).toList(),
      );
});

/// Ticket invitations not yet reflected as owned entitlements (guest claim / pending).
final attendeePendingTicketInvitationsProvider =
    FutureProvider.autoDispose<List<CustomerInvitationCard>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null || (session.email == null || session.email!.isEmpty)) {
    return const [];
  }
  final ownedIds = (await ref.watch(attendeeTicketsSyncProvider.future)).map((t) => t.id).toSet();
  try {
    final api = ref.read(identityApiProvider);
    final found = await api.lookupInvitations(email: session.email);
    return found
        .where((e) => !ownedIds.contains(e.id))
        .map(
          (e) => CustomerInvitationCard(
            id: e.id,
            eventTitle: e.eventTitle,
            eventId: e.eventId,
            startsAt: e.startsAt,
            venue: e.eventVenue,
            city: e.eventCity,
            kind: CustomerInvitationKind.ticket,
          ),
        )
        .toList();
  } catch (_) {
    return const [];
  }
});

enum MyEventsFilter {
  all,
  upcoming,
  ongoing,
  past,
  saved,
  registered,
  cancelled,
  history,
}

class MyEventsBundle {
  const MyEventsBundle({
    required this.registered,
    required this.saved,
    required this.recentlyViewed,
    required this.orders,
  });

  final List<AttendeeEventView> registered;
  final List<PublicEvent> saved;
  final List<PublicEvent> recentlyViewed;
  final List<TicketOrderSummary> orders;
}

final myEventsBundleProvider = FutureProvider.autoDispose<MyEventsBundle>((ref) async {
  final registered = await ref.watch(attendeeEventsProvider.future);
  final savedIds = ref.watch(savedEventIdsProvider);
  final recentIds = ref.watch(recentlyViewedEventIdsProvider);
  final catalog = await ref.watch(publicEventsProvider.future);

  PublicEvent? byId(String id) {
    for (final e in catalog) {
      if (e.id == id) return e;
    }
    return null;
  }

  final saved = <PublicEvent>[
    for (final id in savedIds)
      if (byId(id) != null) byId(id)!,
  ];
  final recent = <PublicEvent>[
    for (final id in recentIds)
      if (byId(id) != null) byId(id)!,
  ];

  List<TicketOrderSummary> orders = const [];
  final session = ref.watch(authSessionProvider);
  if (session != null) {
    try {
      orders = await ref.read(ticketCommerceApiProvider).fetchMyOrders(session);
    } catch (_) {}
  }

  return MyEventsBundle(
    registered: registered,
    saved: saved,
    recentlyViewed: recent,
    orders: orders,
  );
});

/// Unified activity timeline for the attendee command center.
class AttendeeActivityItem {
  const AttendeeActivityItem({
    required this.title,
    required this.subtitle,
    required this.at,
    required this.kind,
  });

  final String title;
  final String subtitle;
  final DateTime at;
  final String kind;
}

final attendeeActivityTimelineProvider = Provider.autoDispose<List<AttendeeActivityItem>>((ref) {
  final items = <AttendeeActivityItem>[];

  final events = ref.watch(attendeeEventsProvider).valueOrNull ?? const [];
  for (final e in events.take(12)) {
    items.add(
      AttendeeActivityItem(
        title: e.checkedIn ? 'Checked in · ${e.eventTitle}' : 'Ticket ready · ${e.eventTitle}',
        subtitle: '${e.tierName} · ${e.lifecycleLabel}',
        at: e.ticket.purchasedAt,
        kind: 'ticket',
      ),
    );
  }

  final notices = ref.watch(purchaseNotificationsProvider);
  for (final n in notices) {
    items.add(
      AttendeeActivityItem(
        title: n.title,
        subtitle: n.body,
        at: n.createdAt,
        kind: 'notification',
      ),
    );
  }

  final messages = ref.watch(homeMessagePreviewsProvider).valueOrNull ?? const [];
  for (final m in messages) {
    items.add(
      AttendeeActivityItem(
        title: m.sender,
        subtitle: m.preview,
        at: m.sentAt,
        kind: 'message',
      ),
    );
  }

  items.sort((a, b) => b.at.compareTo(a.at));
  return items;
});
