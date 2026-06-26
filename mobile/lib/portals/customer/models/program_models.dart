class ProgramItem {
  const ProgramItem({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.ownerType,
    this.ownerId,
    required this.ownerName,
    this.vendorId,
    required this.status,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final String ownerType;
  final String? ownerId;
  final String ownerName;
  final String? vendorId;
  final String status;
  final int sortOrder;

  factory ProgramItem.fromJson(Map<String, dynamic> json) => ProgramItem(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        startTime: DateTime.parse(json['startTime'] as String).toLocal(),
        endTime: DateTime.parse(json['endTime'] as String).toLocal(),
        durationMinutes: json['durationMinutes'] as int? ?? 15,
        ownerType: json['ownerType'] as String? ?? 'planner',
        ownerId: json['ownerId'] as String?,
        ownerName: json['ownerName'] as String? ?? '',
        vendorId: json['vendorId'] as String?,
        status: json['status'] as String? ?? 'planned',
        sortOrder: json['sortOrder'] as int? ?? 0,
      );
}

class ProgramDaySnapshot {
  const ProgramDaySnapshot({
    this.current,
    this.next,
    this.countdownSeconds,
    this.countdownLabel,
  });

  final ProgramItem? current;
  final ProgramItem? next;
  final int? countdownSeconds;
  final String? countdownLabel;

  factory ProgramDaySnapshot.fromJson(Map<String, dynamic> json) => ProgramDaySnapshot(
        current: json['current'] != null
            ? ProgramItem.fromJson(json['current'] as Map<String, dynamic>)
            : null,
        next: json['next'] != null ? ProgramItem.fromJson(json['next'] as Map<String, dynamic>) : null,
        countdownSeconds: json['countdownSeconds'] as int?,
        countdownLabel: json['countdownLabel'] as String?,
      );
}

class ProgramActivity {
  const ProgramActivity({
    required this.id,
    required this.activityKind,
    required this.headline,
    required this.detail,
    this.programItemId,
    required this.createdAt,
  });

  final String id;
  final String activityKind;
  final String headline;
  final String detail;
  final String? programItemId;
  final DateTime createdAt;

  factory ProgramActivity.fromJson(Map<String, dynamic> json) => ProgramActivity(
        id: json['id'] as String,
        activityKind: json['activityKind'] as String,
        headline: json['headline'] as String,
        detail: json['detail'] as String? ?? '',
        programItemId: json['programItemId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

class ProgramSnapshot {
  const ProgramSnapshot({
    required this.items,
    required this.day,
    required this.recentActivity,
  });

  final List<ProgramItem> items;
  final ProgramDaySnapshot day;
  final List<ProgramActivity> recentActivity;

  factory ProgramSnapshot.fromJson(Map<String, dynamic> json) => ProgramSnapshot(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => ProgramItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        day: ProgramDaySnapshot.fromJson(json['day'] as Map<String, dynamic>? ?? const {}),
        recentActivity: (json['recentActivity'] as List<dynamic>? ?? const [])
            .map((e) => ProgramActivity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

String formatProgramTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ampm';
}

String formatProgramCountdown(int? seconds) {
  if (seconds == null) return '—';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m >= 60) {
    final h = m ~/ 60;
    final rm = m % 60;
    return '${h}h ${rm}m';
  }
  return '${m}m ${s}s';
}
