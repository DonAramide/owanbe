import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/models/attendee_pass_status.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../portals/customer/models/program_models.dart';

class AttendeeLiveUpdate {
  const AttendeeLiveUpdate({
    required this.id,
    required this.type,
    required this.headline,
    required this.detail,
    required this.timestamp,
    this.severity = 'info',
  });

  final String id;
  final String type;
  final String headline;
  final String detail;
  final DateTime timestamp;
  final String severity;

  factory AttendeeLiveUpdate.fromJson(Map<String, dynamic> json) {
    return AttendeeLiveUpdate(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? json['activityKind'] ?? 'general').toString(),
      headline: (json['headline'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      timestamp: DateTime.tryParse((json['timestamp'] ?? json['createdAt'] ?? '').toString())
              ?.toLocal() ??
          DateTime.now(),
      severity: (json['severity'] ?? 'info').toString(),
    );
  }

  bool get isEmergency =>
      severity == 'critical' || type.toLowerCase().contains('emergency');

  bool get isAlert =>
      isEmergency || severity == 'warning' || type.toLowerCase().contains('alert');
}

/// Polling gate for Live Hub.
final attendeeLiveWatchProvider = StateProvider.autoDispose.family<bool, String>((ref, eventId) => false);

final attendeeLiveSyncProvider = Provider.autoDispose.family<void, String>((ref, eventId) {
  final watching = ref.watch(attendeeLiveWatchProvider(eventId));
  if (!watching) return;
  final timer = Timer.periodic(const Duration(seconds: 10), (_) {
    unawaited(ref.refresh(publicEventProgramProvider(eventId).future));
    unawaited(ref.refresh(attendeeLiveUpdatesProvider(eventId).future));
  });
  ref.onDispose(timer.cancel);
});

final attendeeLiveUpdatesProvider =
    FutureProvider.autoDispose.family<List<AttendeeLiveUpdate>, String>((ref, eventId) async {
  final api = ref.watch(eventsApiProvider);
  List<Map<String, dynamic>> fromFeed = const [];
  try {
    fromFeed = await api.fetchLiveUpdates(eventId);
  } catch (_) {
    fromFeed = const [];
  }
  final feedItems = fromFeed.map(AttendeeLiveUpdate.fromJson).toList();

  // Merge program recentActivity (already public) so announcements MVP works even if feed empty.
  try {
    final program = await ref.watch(publicEventProgramProvider(eventId).future);
    final fromProgram = program.recentActivity.map(
      (a) => AttendeeLiveUpdate(
        id: 'activity_${a.id}',
        type: a.activityKind,
        headline: a.headline,
        detail: a.detail,
        timestamp: a.createdAt,
        severity: a.activityKind.contains('delayed') ? 'warning' : 'info',
      ),
    );
    final byId = <String, AttendeeLiveUpdate>{};
    for (final u in [...feedItems, ...fromProgram]) {
      byId[u.id] = u;
    }
    final merged = byId.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged;
  } catch (_) {
    return feedItems;
  }
});

final attendeeLiveEventTicketProvider =
    Provider.autoDispose.family<AsyncValue<AttendeeEventView?>, String>((ref, eventId) {
  return ref.watch(attendeeEventsProvider).whenData((events) {
    final matches = events.where((e) => e.eventId == eventId).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) {
      if (a.checkedIn != b.checkedIn) return a.checkedIn ? -1 : 1;
      return a.ticket.purchasedAt.compareTo(b.ticket.purchasedAt);
    });
    return matches.first;
  });
});

class LiveAgendaBuckets {
  const LiveAgendaBuckets({
    required this.current,
    required this.upcoming,
    required this.completed,
    required this.all,
    required this.day,
    required this.progressPct,
  });

  final ProgramItem? current;
  final List<ProgramItem> upcoming;
  final List<ProgramItem> completed;
  final List<ProgramItem> all;
  final ProgramDaySnapshot day;
  final double progressPct;
}

LiveAgendaBuckets buildLiveAgendaBuckets(ProgramSnapshot program, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final items = [...program.items]..sort((a, b) => a.startTime.compareTo(b.startTime));
  ProgramItem? current = program.day.current;
  if (current == null) {
    for (final i in items) {
      if (i.status == 'skipped') continue;
      if (i.status == 'in_progress' ||
          (!clock.isBefore(i.startTime) && clock.isBefore(i.endTime))) {
        current = i;
        break;
      }
    }
  }
  final completed = items
      .where(
        (i) =>
            i.status == 'completed' ||
            i.status == 'skipped' ||
            (!i.endTime.isAfter(clock) && i.id != current?.id),
      )
      .toList();
  final upcoming = items
      .where((i) => !completed.any((c) => c.id == i.id) && i.id != current?.id)
      .toList();
  final done = completed.length;
  final total = items.isEmpty ? 1 : items.length;
  return LiveAgendaBuckets(
    current: current,
    upcoming: upcoming,
    completed: completed,
    all: items,
    day: program.day,
    progressPct: (done / total).clamp(0.0, 1.0),
  );
}

String sessionProgressLabel(ProgramItem item, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  switch (item.status) {
    case 'completed':
      return 'Completed';
    case 'skipped':
      return 'Skipped';
    case 'delayed':
      return 'Delayed';
    case 'in_progress':
      return 'In progress';
    case 'ready':
      return 'Ready';
    default:
      if (!clock.isBefore(item.startTime) && clock.isBefore(item.endTime)) return 'In progress';
      if (!item.endTime.isAfter(clock)) return 'Completed';
      return 'Upcoming';
  }
}

double sessionElapsedFraction(ProgramItem item, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final total = item.endTime.difference(item.startTime).inSeconds;
  if (total <= 0) return item.status == 'completed' ? 1 : 0;
  if (clock.isBefore(item.startTime)) return 0;
  if (!clock.isBefore(item.endTime) || item.status == 'completed') return 1;
  return (clock.difference(item.startTime).inSeconds / total).clamp(0.0, 1.0);
}

String? sessionRoomHint(ProgramItem item) {
  final d = item.description.trim();
  if (d.toLowerCase().startsWith('room:') || d.toLowerCase().startsWith('venue:')) {
    return d.split('\n').first;
  }
  if (d.isEmpty) return null;
  // Short description often carries location context.
  if (d.length <= 48 && !d.contains('.')) return d;
  return null;
}

List<ProgramItem> personalSessions({
  required List<ProgramItem> all,
  required Set<String> selectedIds,
}) {
  return all.where((i) => selectedIds.contains(i.id)).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
}

AttendeePassLiveStatus? livePassStatusFor(AttendeeEventView? ticket) {
  if (ticket == null) return null;
  return ticket.liveStatus;
}
