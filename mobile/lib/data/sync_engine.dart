import 'package:drift/drift.dart';

import '../api/outbox_sync_contract.dart';
import 'app_database.dart';

/// Pulls pending outbox rows and marks them `in_flight`, then delivers them.
///
/// With [transport], sends `Idempotency-Key: clientMutationId` on POSTs that
/// allocate server-side resources (see OpenAPI). Without it, marks rows
/// completed immediately (useful for tests / offline-only prototyping).
class SyncEngine {
  SyncEngine(this._db, {OutboxTransport? transport})
      : _transport = transport;

  final AppDatabase _db;
  final OutboxTransport? _transport;

  static const int _maxAttempts = 12;

  /// Single pass; call from connectivity listener or periodic timer.
  Future<SyncEngineResult> runOnce() async {
    var processed = 0;
    var errors = 0;

    final pending = await (_db.select(_db.outboxActions)
          ..where((t) => t.state.equals('pending'))
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();

    for (final row in pending) {
      if (row.attempts >= _maxAttempts) {
        errors++;
        await (_db.update(_db.outboxActions)..where((t) => t.id.equals(row.id)))
            .write(
          OutboxActionsCompanion(
            state: const Value('failed'),
            lastError: Value(
              row.lastError ?? 'Exceeded max attempts ($_maxAttempts)',
            ),
          ),
        );
        continue;
      }

      if (row.dependsOnOutboxId != null) {
        final dep = await (_db.select(_db.outboxActions)
              ..where((t) => t.id.equals(row.dependsOnOutboxId!)))
            .getSingleOrNull();
        if (dep == null || dep.state != 'completed') {
          continue;
        }
      }

      await (_db.update(_db.outboxActions)..where((t) => t.id.equals(row.id)))
          .write(const OutboxActionsCompanion(state: Value('in_flight')));

      try {
        final OutboxDeliveryResult result;
        final transport = _transport;
        if (transport != null) {
          result = await transport.send(row);
        } else {
          result = const OutboxDeliveryResult.completed();
        }

        switch (result.disposition) {
          case OutboxDeliveryDisposition.completed:
            await (_db.update(_db.outboxActions)..where((t) => t.id.equals(row.id)))
                .write(
              const OutboxActionsCompanion(
                state: Value('completed'),
                lastError: Value.absent(),
              ),
            );
            processed++;
          case OutboxDeliveryDisposition.retryLater:
            final nextAttempts = row.attempts + 1;
            if (nextAttempts >= _maxAttempts) {
              errors++;
              await (_db.update(_db.outboxActions)..where((t) => t.id.equals(row.id)))
                  .write(
                OutboxActionsCompanion(
                  state: const Value('failed'),
                  attempts: Value(nextAttempts),
                  lastError: Value(
                    result.message ?? 'retryLater (max attempts reached)',
                  ),
                ),
              );
            } else {
              errors++;
              await (_db.update(_db.outboxActions)..where((t) => t.id.equals(row.id)))
                  .write(
                OutboxActionsCompanion(
                  state: const Value('pending'),
                  attempts: Value(nextAttempts),
                  lastError: Value(
                    result.message ??
                        'HTTP ${result.httpStatus ?? ''} — will retry',
                  ),
                ),
              );
            }
          case OutboxDeliveryDisposition.failed:
            errors++;
            await (_db.update(_db.outboxActions)..where((t) => t.id.equals(row.id)))
                .write(
              OutboxActionsCompanion(
                state: const Value('failed'),
                lastError: Value(
                  result.message ?? 'failed',
                ),
              ),
            );
        }
      } catch (e) {
        errors++;
        final nextAttempts = row.attempts + 1;
        if (nextAttempts >= _maxAttempts) {
          await (_db.update(_db.outboxActions)..where((t) => t.id.equals(row.id)))
              .write(
            OutboxActionsCompanion(
              state: const Value('failed'),
              attempts: Value(nextAttempts),
              lastError: Value(e.toString()),
            ),
          );
        } else {
          await (_db.update(_db.outboxActions)..where((t) => t.id.equals(row.id)))
              .write(
            OutboxActionsCompanion(
              state: const Value('pending'),
              attempts: Value(nextAttempts),
              lastError: Value(e.toString()),
            ),
          );
        }
      }
    }

    return SyncEngineResult(processed: processed, errors: errors);
  }
}

class SyncEngineResult {
  SyncEngineResult({required this.processed, required this.errors});

  final int processed;
  final int errors;
}
