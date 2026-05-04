import 'dart:math';

import 'package:drift/drift.dart';

import 'app_database.dart';

export '../api/outbox_sync_contract.dart' show OwanbeOutboxActionKinds;

String _defaultClientMutationId() =>
    '${DateTime.now().toUtc().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';

/// Enqueues a mutation for the sync engine. Call within a transaction if you
/// also mutate [LocalBookings] to keep atomicity.
Future<int> enqueueOutboxAction(
  AppDatabase db, {
  required String actionType,
  required String payloadJson,
  String? clientMutationId,
  int? dependsOnOutboxId,
}) {
  final id = clientMutationId ?? _defaultClientMutationId();
  return db.into(db.outboxActions).insert(
        OutboxActionsCompanion.insert(
          clientMutationId: id,
          actionType: actionType,
          payloadJson: payloadJson,
          dependsOnOutboxId: dependsOnOutboxId != null
              ? Value(dependsOnOutboxId)
              : const Value.absent(),
        ),
      );
}
