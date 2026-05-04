import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'app_database.g.dart';

/// Keyset / opaque cursor per entity stream (e.g. `bookings`, `messages:threadId`).
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get entityType => text()();
  TextColumn get cursor => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {entityType};
}

/// Durable mutation queue for offline-first sync.
@DataClassName('OutboxActionRow')
class OutboxActions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Same value sent as `Idempotency-Key` / `client_msg_id` on the wire.
  TextColumn get clientMutationId =>
      text().withLength(min: 8, max: 128).unique()();

  TextColumn get actionType => text()();
  TextColumn get payloadJson => text()();

  TextColumn get state =>
      text().withDefault(const Constant('pending'))(); // pending|in_flight|completed|failed

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  /// Optional ordering: set to another outbox `id` that must complete first.
  IntColumn get dependsOnOutboxId => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Cached booking rows (subset of server schema; extend as needed).
@DataClassName('LocalBookingRow')
class LocalBookings extends Table {
  IntColumn get localId => integer().autoIncrement()();

  TextColumn get serverId => text().nullable().unique()();
  TextColumn get tenantId => text()();
  TextColumn get clientUserId => text()();
  TextColumn get vendorId => text()();
  TextColumn get packageId => text()();

  TextColumn get status => text()();
  TextColumn get currency => text()();
  IntColumn get guestCount => integer()();
  IntColumn get totalMinor => integer()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  DateTimeColumn get eventStartsAtUtc => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAtUtc => dateTime().nullable()();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'owanbe.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [SyncCursors, OutboxActions, LocalBookings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}
