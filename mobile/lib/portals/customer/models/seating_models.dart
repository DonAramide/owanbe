class SeatingAssignment {
  const SeatingAssignment({
    required this.id,
    required this.guestRef,
    required this.guestName,
    this.seatIndex,
  });

  final String id;
  final String guestRef;
  final String guestName;
  final int? seatIndex;

  factory SeatingAssignment.fromJson(Map<String, dynamic> json) => SeatingAssignment(
        id: json['id'] as String,
        guestRef: json['guestRef'] as String,
        guestName: json['guestName'] as String,
        seatIndex: json['seatIndex'] as int?,
      );
}

class SeatingTable {
  const SeatingTable({
    required this.id,
    required this.label,
    required this.tableKind,
    required this.capacity,
    required this.isVip,
    required this.positionX,
    required this.positionY,
    required this.rotationDeg,
    required this.sortOrder,
    required this.assignments,
    required this.assignedCount,
  });

  final String id;
  final String label;
  final String tableKind;
  final int capacity;
  final bool isVip;
  final double positionX;
  final double positionY;
  final double rotationDeg;
  final int sortOrder;
  final List<SeatingAssignment> assignments;
  final int assignedCount;

  bool get isFull => assignedCount >= capacity;
  bool get hasSpace => assignedCount < capacity;

  SeatingTable copyWith({
    double? positionX,
    double? positionY,
    double? rotationDeg,
    List<SeatingAssignment>? assignments,
    int? assignedCount,
  }) =>
      SeatingTable(
        id: id,
        label: label,
        tableKind: tableKind,
        capacity: capacity,
        isVip: isVip,
        positionX: positionX ?? this.positionX,
        positionY: positionY ?? this.positionY,
        rotationDeg: rotationDeg ?? this.rotationDeg,
        sortOrder: sortOrder,
        assignments: assignments ?? this.assignments,
        assignedCount: assignedCount ?? this.assignedCount,
      );

  factory SeatingTable.fromJson(Map<String, dynamic> json) => SeatingTable(
        id: json['id'] as String,
        label: json['label'] as String,
        tableKind: json['tableKind'] as String? ?? 'round',
        capacity: json['capacity'] as int? ?? 8,
        isVip: json['isVip'] as bool? ?? false,
        positionX: (json['positionX'] as num?)?.toDouble() ?? 40,
        positionY: (json['positionY'] as num?)?.toDouble() ?? 40,
        rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
        sortOrder: json['sortOrder'] as int? ?? 0,
        assignments: (json['assignments'] as List<dynamic>? ?? const [])
            .map((e) => SeatingAssignment.fromJson(e as Map<String, dynamic>))
            .toList(),
        assignedCount: json['assignedCount'] as int? ?? 0,
      );
}

class SeatingStats {
  const SeatingStats({
    required this.tableCount,
    required this.totalCapacity,
    required this.assignedGuests,
    required this.vipTableCount,
  });

  final int tableCount;
  final int totalCapacity;
  final int assignedGuests;
  final int vipTableCount;

  factory SeatingStats.fromJson(Map<String, dynamic> json) => SeatingStats(
        tableCount: json['tableCount'] as int? ?? 0,
        totalCapacity: json['totalCapacity'] as int? ?? 0,
        assignedGuests: json['assignedGuests'] as int? ?? 0,
        vipTableCount: json['vipTableCount'] as int? ?? 0,
      );
}

class SeatingLayout {
  const SeatingLayout({
    required this.id,
    required this.name,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.tables,
    required this.stats,
  });

  final String id;
  final String name;
  final int canvasWidth;
  final int canvasHeight;
  final List<SeatingTable> tables;
  final SeatingStats stats;

  Set<String> get assignedGuestRefs => {
        for (final t in tables) for (final a in t.assignments) a.guestRef,
      };

  factory SeatingLayout.fromJson(Map<String, dynamic> json) => SeatingLayout(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Main floor',
        canvasWidth: json['canvasWidth'] as int? ?? 900,
        canvasHeight: json['canvasHeight'] as int? ?? 640,
        tables: (json['tables'] as List<dynamic>? ?? const [])
            .map((e) => SeatingTable.fromJson(e as Map<String, dynamic>))
            .toList(),
        stats: SeatingStats.fromJson(json['stats'] as Map<String, dynamic>? ?? const {}),
      );
}

class SeatingExportRow {
  const SeatingExportRow({
    required this.table,
    required this.kind,
    required this.vip,
    required this.guest,
    this.seat,
  });

  final String table;
  final String kind;
  final String vip;
  final String guest;
  final int? seat;

  factory SeatingExportRow.fromJson(Map<String, dynamic> json) => SeatingExportRow(
        table: json['table'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        vip: json['vip'] as String? ?? 'no',
        guest: json['guest'] as String? ?? '',
        seat: json['seat'] as int?,
      );

  List<String> toCsvCells() => [table, kind, vip, guest, seat?.toString() ?? ''];
}

String seatingLayoutToCsv(SeatingLayout layout) {
  final buffer = StringBuffer('Table,Kind,VIP,Guest,Seat\n');
  for (final table in layout.tables) {
    if (table.assignments.isEmpty) {
      buffer.writeln('${table.label},${table.tableKind},${table.isVip ? 'yes' : 'no'},,');
      continue;
    }
    for (final a in table.assignments) {
      buffer.writeln(
        '${table.label},${table.tableKind},${table.isVip ? 'yes' : 'no'},${a.guestName},${a.seatIndex ?? ''}',
      );
    }
  }
  return buffer.toString();
}
