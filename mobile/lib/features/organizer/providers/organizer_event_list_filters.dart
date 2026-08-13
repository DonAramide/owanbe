import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../models/organizer_models.dart';
import '../widgets/organizer_shared.dart';
import 'organizer_providers.dart';

enum OrganizerEventSort {
  createdDesc,
  startsAsc,
  startsDesc,
  titleAsc,
  titleDesc,
}

extension OrganizerEventSortX on OrganizerEventSort {
  String get apiValue => switch (this) {
        OrganizerEventSort.createdDesc => 'created_desc',
        OrganizerEventSort.startsAsc => 'starts_asc',
        OrganizerEventSort.startsDesc => 'starts_desc',
        OrganizerEventSort.titleAsc => 'title_asc',
        OrganizerEventSort.titleDesc => 'title_desc',
      };

  String get label => switch (this) {
        OrganizerEventSort.createdDesc => 'Recently created',
        OrganizerEventSort.startsAsc => 'Start date (soonest)',
        OrganizerEventSort.startsDesc => 'Start date (latest)',
        OrganizerEventSort.titleAsc => 'Title A–Z',
        OrganizerEventSort.titleDesc => 'Title Z–A',
      };
}

/// Optional status filter — `null` means all statuses.
final organizerEventStatusFilterProvider = StateProvider<OrganizerEventStatus?>((ref) => null);

final organizerEventSearchQueryProvider = StateProvider<String>((ref) => '');

final organizerEventSortProvider = StateProvider<OrganizerEventSort>((ref) => OrganizerEventSort.createdDesc);

/// Events list respecting search, status, and sort (server query with client fallback).
final filteredOrganizerEventsProvider = FutureProvider.autoDispose<List<OrganizerEvent>>((ref) async {
  ref.watch(organizerRevisionProvider);
  final q = ref.watch(organizerEventSearchQueryProvider).trim();
  final status = ref.watch(organizerEventStatusFilterProvider);
  final sort = ref.watch(organizerEventSortProvider);
  final api = ref.read(eventsApiProvider);

  try {
    return await api.listOrganizerEvents(
      q: q.isEmpty ? null : q,
      status: status == null ? null : organizerStatusLabel(status),
      sort: sort.apiValue,
    );
  } catch (_) {
    final all = await ref.read(organizerEventsProvider.future);
    var list = all.toList();
    if (q.isNotEmpty) {
      final lower = q.toLowerCase();
      list = list
          .where(
            (e) =>
                e.title.toLowerCase().contains(lower) ||
                e.city.toLowerCase().contains(lower),
          )
          .toList();
    }
    if (status != null) {
      list = list.where((e) => e.status == status).toList();
    }
    list.sort((a, b) {
      switch (sort) {
        case OrganizerEventSort.startsAsc:
          return a.startsAt.compareTo(b.startsAt);
        case OrganizerEventSort.startsDesc:
          return b.startsAt.compareTo(a.startsAt);
        case OrganizerEventSort.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case OrganizerEventSort.titleDesc:
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
        case OrganizerEventSort.createdDesc:
          final ac = a.createdAt ?? a.startsAt;
          final bc = b.createdAt ?? b.startsAt;
          return bc.compareTo(ac);
      }
    });
    return list;
  }
});
