import '../models/public_models.dart';

import '../../organizer/data/organizer_event_store.dart';
import '../../organizer/models/organizer_models.dart';

/// Phase 1 catalog — reads published events from [OrganizerEventStore].
class PublicEventCatalog {
  Future<List<PublicEvent>> listEvents({String? query, String? category}) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    var items = OrganizerEventStore.instance
        .publishedForPublic()
        .map((e) => e.toPublicEvent())
        .toList();
    if (category != null && category.isNotEmpty && category != 'all') {
      items = items.where((e) => e.category.toLowerCase() == category.toLowerCase()).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      items = items
          .where(
            (e) =>
                e.title.toLowerCase().contains(q) ||
                e.city.toLowerCase().contains(q) ||
                e.category.toLowerCase().contains(q),
          )
          .toList();
    }
    return items;
  }

  Future<PublicEvent?> getEvent(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final org = OrganizerEventStore.instance.byId(id);
    if (org != null &&
        (org.status == OrganizerEventStatus.published ||
            org.status == OrganizerEventStatus.live ||
            org.status == OrganizerEventStatus.completed)) {
      return org.toPublicEvent();
    }
    return null;
  }

  List<String> categories() {
    final cats = OrganizerEventStore.instance
        .publishedForPublic()
        .map((e) => e.category)
        .toSet()
        .toList();
    return ['all', ...cats];
  }
}
