import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/owanbe_rest_outbox_transport.dart';
import '../api/outbox_sync_contract.dart';
import 'app_database.dart';
import 'sync_engine.dart';

/// Single app-wide database instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Non-null when `OWANBE_API_BASE` is set (after [bootstrapSupabase] loads dotenv).
final outboxTransportProvider = Provider<OutboxTransport?>((ref) {
  final raw = dotenv.env['OWANBE_API_BASE']?.trim();
  if (raw == null || raw.isEmpty) return null;

  final base = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  return OwanbeRestOutboxTransport(
    baseUrl: base,
    resolveAuth: () => defaultResolveOwanbeApiAuthFromSupabase(
      tenantIdFromEnv: dotenv.env['OWANBE_TENANT_ID'],
    ),
  );
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final transport = ref.watch(outboxTransportProvider);
  return SyncEngine(db, transport: transport);
});
