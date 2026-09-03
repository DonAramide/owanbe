import 'vendors_api.dart';

/// Organizer availability browser: one upcoming window (not one call per day).
({DateTime from, DateTime to}) organizerAvailabilityDisplayRange({
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final from = DateTime(n.year, n.month, n.day);
  final to = from.add(const Duration(days: 90));
  return (from: from, to: to);
}

bool availabilityStatusIsUnavailable(String? status) {
  return (status ?? '').toUpperCase() == 'UNAVAILABLE';
}

enum AvailabilityDayKind { available, booked, vendorUnavailable }

class AvailabilityDayRow {
  const AvailabilityDayRow({
    required this.day,
    required this.kind,
    required this.windows,
    this.unavailableWindows = const [],
  });

  final DateTime day;
  final AvailabilityDayKind kind;
  final List<BookedRange> windows;
  final List<BookedRange> unavailableWindows;

  bool get booked => kind == AvailabilityDayKind.booked;
  bool get vendorUnavailable => kind == AvailabilityDayKind.vendorUnavailable;
  bool get isOccupied =>
      kind == AvailabilityDayKind.booked || kind == AvailabilityDayKind.vendorUnavailable;
}

DateTime _localDateOnly(DateTime d) {
  final local = d.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool bookedRangeOverlapsLocalDay(BookedRange range, DateTime day) {
  final start = _localDateOnly(day);
  final end = DateTime(start.year, start.month, start.day + 1);
  return range.startsAt.isBefore(end) && range.endsAt.isAfter(start);
}

/// Calendar days in [from, to]. Occupied times come only from API ranges.
/// Whole-window availabilityStatus is ignored — overlay is per [unavailableRanges].
List<AvailabilityDayRow> availabilityDayRows({
  required DateTime from,
  required DateTime to,
  required List<BookedRange> bookedRanges,
  List<BookedRange> unavailableRanges = const [],
}) {
  final rows = <AvailabilityDayRow>[];
  var cursor = _localDateOnly(from);
  final last = _localDateOnly(to);
  while (!cursor.isAfter(last)) {
    final blocked = [
      for (final range in unavailableRanges)
        if (bookedRangeOverlapsLocalDay(range, cursor)) range,
    ];
    final windows = [
      for (final range in bookedRanges)
        if (bookedRangeOverlapsLocalDay(range, cursor)) range,
    ];
    final AvailabilityDayKind kind;
    if (blocked.isNotEmpty) {
      kind = AvailabilityDayKind.vendorUnavailable;
    } else if (windows.isNotEmpty) {
      kind = AvailabilityDayKind.booked;
    } else {
      kind = AvailabilityDayKind.available;
    }
    rows.add(
      AvailabilityDayRow(
        day: cursor,
        kind: kind,
        windows: windows,
        unavailableWindows: blocked,
      ),
    );
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return rows;
}

/// Keep occupied days plus immediate AVAILABLE neighbours so a 90-day range stays readable.
List<AvailabilityDayRow> compactAvailabilityDayRows(List<AvailabilityDayRow> rows) {
  if (rows.isEmpty) return rows;
  final keep = List<bool>.filled(rows.length, false);
  var anyOccupied = false;
  for (var i = 0; i < rows.length; i++) {
    if (!rows[i].isOccupied) continue;
    anyOccupied = true;
    keep[i] = true;
    if (i > 0) keep[i - 1] = true;
    if (i + 1 < rows.length) keep[i + 1] = true;
  }
  if (!anyOccupied) return const [];
  return [for (var i = 0; i < rows.length; i++) if (keep[i]) rows[i]];
}

List<BookedRange> nextBookedWindows(List<BookedRange> ranges, {int limit = 2}) {
  final sorted = [...ranges]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  if (sorted.length <= limit) return sorted;
  return sorted.sublist(0, limit);
}

String formatClock12(DateTime d) {
  final local = d.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final suffix = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:${_twoDigits(local.minute)} $suffix';
}

String formatTimeRange12(DateTime start, DateTime end) {
  return '${formatClock12(start)} – ${formatClock12(end)}';
}

String formatAvailabilityDayLabel(DateTime d) {
  final local = d.toLocal();
  final month = _titleMonth(local.month);
  return '${local.day} $month';
}

String formatAvailabilityMonthHeading(DateTime d) {
  final local = d.toLocal();
  return '${_titleMonth(local.month)} ${local.year}';
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

const _monthsTitle = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _titleMonth(int month) => _monthsTitle[month - 1];
