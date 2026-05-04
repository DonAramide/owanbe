// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [entityType, cursor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entityType};
  @override
  SyncCursorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursorRow(
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursorRow extends DataClass implements Insertable<SyncCursorRow> {
  final String entityType;
  final String? cursor;
  const SyncCursorRow({required this.entityType, this.cursor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_type'] = Variable<String>(entityType);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      entityType: Value(entityType),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
    );
  }

  factory SyncCursorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursorRow(
      entityType: serializer.fromJson<String>(json['entityType']),
      cursor: serializer.fromJson<String?>(json['cursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityType': serializer.toJson<String>(entityType),
      'cursor': serializer.toJson<String?>(cursor),
    };
  }

  SyncCursorRow copyWith({
    String? entityType,
    Value<String?> cursor = const Value.absent(),
  }) => SyncCursorRow(
    entityType: entityType ?? this.entityType,
    cursor: cursor.present ? cursor.value : this.cursor,
  );
  SyncCursorRow copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursorRow(
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorRow(')
          ..write('entityType: $entityType, ')
          ..write('cursor: $cursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entityType, cursor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursorRow &&
          other.entityType == this.entityType &&
          other.cursor == this.cursor);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursorRow> {
  final Value<String> entityType;
  final Value<String?> cursor;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.entityType = const Value.absent(),
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String entityType,
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entityType = Value(entityType);
  static Insertable<SyncCursorRow> custom({
    Expression<String>? entityType,
    Expression<String>? cursor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityType != null) 'entity_type': entityType,
      if (cursor != null) 'cursor': cursor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? entityType,
    Value<String?>? cursor,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      entityType: entityType ?? this.entityType,
      cursor: cursor ?? this.cursor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('entityType: $entityType, ')
          ..write('cursor: $cursor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxActionsTable extends OutboxActions
    with TableInfo<$OutboxActionsTable, OutboxActionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientMutationIdMeta = const VerificationMeta(
    'clientMutationId',
  );
  @override
  late final GeneratedColumn<String> clientMutationId = GeneratedColumn<String>(
    'client_mutation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 8,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _actionTypeMeta = const VerificationMeta(
    'actionType',
  );
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dependsOnOutboxIdMeta = const VerificationMeta(
    'dependsOnOutboxId',
  );
  @override
  late final GeneratedColumn<int> dependsOnOutboxId = GeneratedColumn<int>(
    'depends_on_outbox_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientMutationId,
    actionType,
    payloadJson,
    state,
    attempts,
    lastError,
    dependsOnOutboxId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxActionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_mutation_id')) {
      context.handle(
        _clientMutationIdMeta,
        clientMutationId.isAcceptableOrUnknown(
          data['client_mutation_id']!,
          _clientMutationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientMutationIdMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(
        _actionTypeMeta,
        actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('depends_on_outbox_id')) {
      context.handle(
        _dependsOnOutboxIdMeta,
        dependsOnOutboxId.isAcceptableOrUnknown(
          data['depends_on_outbox_id']!,
          _dependsOnOutboxIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxActionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxActionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientMutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_mutation_id'],
      )!,
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      dependsOnOutboxId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}depends_on_outbox_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxActionsTable createAlias(String alias) {
    return $OutboxActionsTable(attachedDatabase, alias);
  }
}

class OutboxActionRow extends DataClass implements Insertable<OutboxActionRow> {
  final int id;

  /// Same value sent as `Idempotency-Key` / `client_msg_id` on the wire.
  final String clientMutationId;
  final String actionType;
  final String payloadJson;
  final String state;
  final int attempts;
  final String? lastError;

  /// Optional ordering: set to another outbox `id` that must complete first.
  final int? dependsOnOutboxId;
  final DateTime createdAt;
  const OutboxActionRow({
    required this.id,
    required this.clientMutationId,
    required this.actionType,
    required this.payloadJson,
    required this.state,
    required this.attempts,
    this.lastError,
    this.dependsOnOutboxId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_mutation_id'] = Variable<String>(clientMutationId);
    map['action_type'] = Variable<String>(actionType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['state'] = Variable<String>(state);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || dependsOnOutboxId != null) {
      map['depends_on_outbox_id'] = Variable<int>(dependsOnOutboxId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxActionsCompanion toCompanion(bool nullToAbsent) {
    return OutboxActionsCompanion(
      id: Value(id),
      clientMutationId: Value(clientMutationId),
      actionType: Value(actionType),
      payloadJson: Value(payloadJson),
      state: Value(state),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      dependsOnOutboxId: dependsOnOutboxId == null && nullToAbsent
          ? const Value.absent()
          : Value(dependsOnOutboxId),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxActionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxActionRow(
      id: serializer.fromJson<int>(json['id']),
      clientMutationId: serializer.fromJson<String>(json['clientMutationId']),
      actionType: serializer.fromJson<String>(json['actionType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      state: serializer.fromJson<String>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      dependsOnOutboxId: serializer.fromJson<int?>(json['dependsOnOutboxId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientMutationId': serializer.toJson<String>(clientMutationId),
      'actionType': serializer.toJson<String>(actionType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'state': serializer.toJson<String>(state),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'dependsOnOutboxId': serializer.toJson<int?>(dependsOnOutboxId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxActionRow copyWith({
    int? id,
    String? clientMutationId,
    String? actionType,
    String? payloadJson,
    String? state,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    Value<int?> dependsOnOutboxId = const Value.absent(),
    DateTime? createdAt,
  }) => OutboxActionRow(
    id: id ?? this.id,
    clientMutationId: clientMutationId ?? this.clientMutationId,
    actionType: actionType ?? this.actionType,
    payloadJson: payloadJson ?? this.payloadJson,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    dependsOnOutboxId: dependsOnOutboxId.present
        ? dependsOnOutboxId.value
        : this.dependsOnOutboxId,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxActionRow copyWithCompanion(OutboxActionsCompanion data) {
    return OutboxActionRow(
      id: data.id.present ? data.id.value : this.id,
      clientMutationId: data.clientMutationId.present
          ? data.clientMutationId.value
          : this.clientMutationId,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      dependsOnOutboxId: data.dependsOnOutboxId.present
          ? data.dependsOnOutboxId.value
          : this.dependsOnOutboxId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxActionRow(')
          ..write('id: $id, ')
          ..write('clientMutationId: $clientMutationId, ')
          ..write('actionType: $actionType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('dependsOnOutboxId: $dependsOnOutboxId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientMutationId,
    actionType,
    payloadJson,
    state,
    attempts,
    lastError,
    dependsOnOutboxId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxActionRow &&
          other.id == this.id &&
          other.clientMutationId == this.clientMutationId &&
          other.actionType == this.actionType &&
          other.payloadJson == this.payloadJson &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.dependsOnOutboxId == this.dependsOnOutboxId &&
          other.createdAt == this.createdAt);
}

class OutboxActionsCompanion extends UpdateCompanion<OutboxActionRow> {
  final Value<int> id;
  final Value<String> clientMutationId;
  final Value<String> actionType;
  final Value<String> payloadJson;
  final Value<String> state;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<int?> dependsOnOutboxId;
  final Value<DateTime> createdAt;
  const OutboxActionsCompanion({
    this.id = const Value.absent(),
    this.clientMutationId = const Value.absent(),
    this.actionType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.dependsOnOutboxId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OutboxActionsCompanion.insert({
    this.id = const Value.absent(),
    required String clientMutationId,
    required String actionType,
    required String payloadJson,
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.dependsOnOutboxId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : clientMutationId = Value(clientMutationId),
       actionType = Value(actionType),
       payloadJson = Value(payloadJson);
  static Insertable<OutboxActionRow> custom({
    Expression<int>? id,
    Expression<String>? clientMutationId,
    Expression<String>? actionType,
    Expression<String>? payloadJson,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<int>? dependsOnOutboxId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientMutationId != null) 'client_mutation_id': clientMutationId,
      if (actionType != null) 'action_type': actionType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (dependsOnOutboxId != null) 'depends_on_outbox_id': dependsOnOutboxId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OutboxActionsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientMutationId,
    Value<String>? actionType,
    Value<String>? payloadJson,
    Value<String>? state,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<int?>? dependsOnOutboxId,
    Value<DateTime>? createdAt,
  }) {
    return OutboxActionsCompanion(
      id: id ?? this.id,
      clientMutationId: clientMutationId ?? this.clientMutationId,
      actionType: actionType ?? this.actionType,
      payloadJson: payloadJson ?? this.payloadJson,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      dependsOnOutboxId: dependsOnOutboxId ?? this.dependsOnOutboxId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientMutationId.present) {
      map['client_mutation_id'] = Variable<String>(clientMutationId.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (dependsOnOutboxId.present) {
      map['depends_on_outbox_id'] = Variable<int>(dependsOnOutboxId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxActionsCompanion(')
          ..write('id: $id, ')
          ..write('clientMutationId: $clientMutationId, ')
          ..write('actionType: $actionType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('dependsOnOutboxId: $dependsOnOutboxId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LocalBookingsTable extends LocalBookings
    with TableInfo<$LocalBookingsTable, LocalBookingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBookingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<int> localId = GeneratedColumn<int>(
    'local_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientUserIdMeta = const VerificationMeta(
    'clientUserId',
  );
  @override
  late final GeneratedColumn<String> clientUserId = GeneratedColumn<String>(
    'client_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vendorIdMeta = const VerificationMeta(
    'vendorId',
  );
  @override
  late final GeneratedColumn<String> vendorId = GeneratedColumn<String>(
    'vendor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _guestCountMeta = const VerificationMeta(
    'guestCount',
  );
  @override
  late final GeneratedColumn<int> guestCount = GeneratedColumn<int>(
    'guest_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMinorMeta = const VerificationMeta(
    'totalMinor',
  );
  @override
  late final GeneratedColumn<int> totalMinor = GeneratedColumn<int>(
    'total_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _eventStartsAtUtcMeta = const VerificationMeta(
    'eventStartsAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> eventStartsAtUtc =
      GeneratedColumn<DateTime>(
        'event_starts_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverUpdatedAtUtcMeta =
      const VerificationMeta('serverUpdatedAtUtc');
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAtUtc =
      GeneratedColumn<DateTime>(
        'server_updated_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    serverId,
    tenantId,
    clientUserId,
    vendorId,
    packageId,
    status,
    currency,
    guestCount,
    totalMinor,
    version,
    dirty,
    eventStartsAtUtc,
    serverUpdatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_bookings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBookingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('client_user_id')) {
      context.handle(
        _clientUserIdMeta,
        clientUserId.isAcceptableOrUnknown(
          data['client_user_id']!,
          _clientUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientUserIdMeta);
    }
    if (data.containsKey('vendor_id')) {
      context.handle(
        _vendorIdMeta,
        vendorId.isAcceptableOrUnknown(data['vendor_id']!, _vendorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vendorIdMeta);
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('guest_count')) {
      context.handle(
        _guestCountMeta,
        guestCount.isAcceptableOrUnknown(data['guest_count']!, _guestCountMeta),
      );
    } else if (isInserting) {
      context.missing(_guestCountMeta);
    }
    if (data.containsKey('total_minor')) {
      context.handle(
        _totalMinorMeta,
        totalMinor.isAcceptableOrUnknown(data['total_minor']!, _totalMinorMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMinorMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('event_starts_at_utc')) {
      context.handle(
        _eventStartsAtUtcMeta,
        eventStartsAtUtc.isAcceptableOrUnknown(
          data['event_starts_at_utc']!,
          _eventStartsAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('server_updated_at_utc')) {
      context.handle(
        _serverUpdatedAtUtcMeta,
        serverUpdatedAtUtc.isAcceptableOrUnknown(
          data['server_updated_at_utc']!,
          _serverUpdatedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  LocalBookingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBookingRow(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      clientUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_user_id'],
      )!,
      vendorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vendor_id'],
      )!,
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      guestCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}guest_count'],
      )!,
      totalMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_minor'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      eventStartsAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_starts_at_utc'],
      ),
      serverUpdatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at_utc'],
      ),
    );
  }

  @override
  $LocalBookingsTable createAlias(String alias) {
    return $LocalBookingsTable(attachedDatabase, alias);
  }
}

class LocalBookingRow extends DataClass implements Insertable<LocalBookingRow> {
  final int localId;
  final String? serverId;
  final String tenantId;
  final String clientUserId;
  final String vendorId;
  final String packageId;
  final String status;
  final String currency;
  final int guestCount;
  final int totalMinor;
  final int version;
  final bool dirty;
  final DateTime? eventStartsAtUtc;
  final DateTime? serverUpdatedAtUtc;
  const LocalBookingRow({
    required this.localId,
    this.serverId,
    required this.tenantId,
    required this.clientUserId,
    required this.vendorId,
    required this.packageId,
    required this.status,
    required this.currency,
    required this.guestCount,
    required this.totalMinor,
    required this.version,
    required this.dirty,
    this.eventStartsAtUtc,
    this.serverUpdatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<int>(localId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['tenant_id'] = Variable<String>(tenantId);
    map['client_user_id'] = Variable<String>(clientUserId);
    map['vendor_id'] = Variable<String>(vendorId);
    map['package_id'] = Variable<String>(packageId);
    map['status'] = Variable<String>(status);
    map['currency'] = Variable<String>(currency);
    map['guest_count'] = Variable<int>(guestCount);
    map['total_minor'] = Variable<int>(totalMinor);
    map['version'] = Variable<int>(version);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || eventStartsAtUtc != null) {
      map['event_starts_at_utc'] = Variable<DateTime>(eventStartsAtUtc);
    }
    if (!nullToAbsent || serverUpdatedAtUtc != null) {
      map['server_updated_at_utc'] = Variable<DateTime>(serverUpdatedAtUtc);
    }
    return map;
  }

  LocalBookingsCompanion toCompanion(bool nullToAbsent) {
    return LocalBookingsCompanion(
      localId: Value(localId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      tenantId: Value(tenantId),
      clientUserId: Value(clientUserId),
      vendorId: Value(vendorId),
      packageId: Value(packageId),
      status: Value(status),
      currency: Value(currency),
      guestCount: Value(guestCount),
      totalMinor: Value(totalMinor),
      version: Value(version),
      dirty: Value(dirty),
      eventStartsAtUtc: eventStartsAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(eventStartsAtUtc),
      serverUpdatedAtUtc: serverUpdatedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAtUtc),
    );
  }

  factory LocalBookingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBookingRow(
      localId: serializer.fromJson<int>(json['localId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      clientUserId: serializer.fromJson<String>(json['clientUserId']),
      vendorId: serializer.fromJson<String>(json['vendorId']),
      packageId: serializer.fromJson<String>(json['packageId']),
      status: serializer.fromJson<String>(json['status']),
      currency: serializer.fromJson<String>(json['currency']),
      guestCount: serializer.fromJson<int>(json['guestCount']),
      totalMinor: serializer.fromJson<int>(json['totalMinor']),
      version: serializer.fromJson<int>(json['version']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      eventStartsAtUtc: serializer.fromJson<DateTime?>(
        json['eventStartsAtUtc'],
      ),
      serverUpdatedAtUtc: serializer.fromJson<DateTime?>(
        json['serverUpdatedAtUtc'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<int>(localId),
      'serverId': serializer.toJson<String?>(serverId),
      'tenantId': serializer.toJson<String>(tenantId),
      'clientUserId': serializer.toJson<String>(clientUserId),
      'vendorId': serializer.toJson<String>(vendorId),
      'packageId': serializer.toJson<String>(packageId),
      'status': serializer.toJson<String>(status),
      'currency': serializer.toJson<String>(currency),
      'guestCount': serializer.toJson<int>(guestCount),
      'totalMinor': serializer.toJson<int>(totalMinor),
      'version': serializer.toJson<int>(version),
      'dirty': serializer.toJson<bool>(dirty),
      'eventStartsAtUtc': serializer.toJson<DateTime?>(eventStartsAtUtc),
      'serverUpdatedAtUtc': serializer.toJson<DateTime?>(serverUpdatedAtUtc),
    };
  }

  LocalBookingRow copyWith({
    int? localId,
    Value<String?> serverId = const Value.absent(),
    String? tenantId,
    String? clientUserId,
    String? vendorId,
    String? packageId,
    String? status,
    String? currency,
    int? guestCount,
    int? totalMinor,
    int? version,
    bool? dirty,
    Value<DateTime?> eventStartsAtUtc = const Value.absent(),
    Value<DateTime?> serverUpdatedAtUtc = const Value.absent(),
  }) => LocalBookingRow(
    localId: localId ?? this.localId,
    serverId: serverId.present ? serverId.value : this.serverId,
    tenantId: tenantId ?? this.tenantId,
    clientUserId: clientUserId ?? this.clientUserId,
    vendorId: vendorId ?? this.vendorId,
    packageId: packageId ?? this.packageId,
    status: status ?? this.status,
    currency: currency ?? this.currency,
    guestCount: guestCount ?? this.guestCount,
    totalMinor: totalMinor ?? this.totalMinor,
    version: version ?? this.version,
    dirty: dirty ?? this.dirty,
    eventStartsAtUtc: eventStartsAtUtc.present
        ? eventStartsAtUtc.value
        : this.eventStartsAtUtc,
    serverUpdatedAtUtc: serverUpdatedAtUtc.present
        ? serverUpdatedAtUtc.value
        : this.serverUpdatedAtUtc,
  );
  LocalBookingRow copyWithCompanion(LocalBookingsCompanion data) {
    return LocalBookingRow(
      localId: data.localId.present ? data.localId.value : this.localId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      clientUserId: data.clientUserId.present
          ? data.clientUserId.value
          : this.clientUserId,
      vendorId: data.vendorId.present ? data.vendorId.value : this.vendorId,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      status: data.status.present ? data.status.value : this.status,
      currency: data.currency.present ? data.currency.value : this.currency,
      guestCount: data.guestCount.present
          ? data.guestCount.value
          : this.guestCount,
      totalMinor: data.totalMinor.present
          ? data.totalMinor.value
          : this.totalMinor,
      version: data.version.present ? data.version.value : this.version,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      eventStartsAtUtc: data.eventStartsAtUtc.present
          ? data.eventStartsAtUtc.value
          : this.eventStartsAtUtc,
      serverUpdatedAtUtc: data.serverUpdatedAtUtc.present
          ? data.serverUpdatedAtUtc.value
          : this.serverUpdatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBookingRow(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('tenantId: $tenantId, ')
          ..write('clientUserId: $clientUserId, ')
          ..write('vendorId: $vendorId, ')
          ..write('packageId: $packageId, ')
          ..write('status: $status, ')
          ..write('currency: $currency, ')
          ..write('guestCount: $guestCount, ')
          ..write('totalMinor: $totalMinor, ')
          ..write('version: $version, ')
          ..write('dirty: $dirty, ')
          ..write('eventStartsAtUtc: $eventStartsAtUtc, ')
          ..write('serverUpdatedAtUtc: $serverUpdatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    serverId,
    tenantId,
    clientUserId,
    vendorId,
    packageId,
    status,
    currency,
    guestCount,
    totalMinor,
    version,
    dirty,
    eventStartsAtUtc,
    serverUpdatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBookingRow &&
          other.localId == this.localId &&
          other.serverId == this.serverId &&
          other.tenantId == this.tenantId &&
          other.clientUserId == this.clientUserId &&
          other.vendorId == this.vendorId &&
          other.packageId == this.packageId &&
          other.status == this.status &&
          other.currency == this.currency &&
          other.guestCount == this.guestCount &&
          other.totalMinor == this.totalMinor &&
          other.version == this.version &&
          other.dirty == this.dirty &&
          other.eventStartsAtUtc == this.eventStartsAtUtc &&
          other.serverUpdatedAtUtc == this.serverUpdatedAtUtc);
}

class LocalBookingsCompanion extends UpdateCompanion<LocalBookingRow> {
  final Value<int> localId;
  final Value<String?> serverId;
  final Value<String> tenantId;
  final Value<String> clientUserId;
  final Value<String> vendorId;
  final Value<String> packageId;
  final Value<String> status;
  final Value<String> currency;
  final Value<int> guestCount;
  final Value<int> totalMinor;
  final Value<int> version;
  final Value<bool> dirty;
  final Value<DateTime?> eventStartsAtUtc;
  final Value<DateTime?> serverUpdatedAtUtc;
  const LocalBookingsCompanion({
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.clientUserId = const Value.absent(),
    this.vendorId = const Value.absent(),
    this.packageId = const Value.absent(),
    this.status = const Value.absent(),
    this.currency = const Value.absent(),
    this.guestCount = const Value.absent(),
    this.totalMinor = const Value.absent(),
    this.version = const Value.absent(),
    this.dirty = const Value.absent(),
    this.eventStartsAtUtc = const Value.absent(),
    this.serverUpdatedAtUtc = const Value.absent(),
  });
  LocalBookingsCompanion.insert({
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    required String tenantId,
    required String clientUserId,
    required String vendorId,
    required String packageId,
    required String status,
    required String currency,
    required int guestCount,
    required int totalMinor,
    this.version = const Value.absent(),
    this.dirty = const Value.absent(),
    this.eventStartsAtUtc = const Value.absent(),
    this.serverUpdatedAtUtc = const Value.absent(),
  }) : tenantId = Value(tenantId),
       clientUserId = Value(clientUserId),
       vendorId = Value(vendorId),
       packageId = Value(packageId),
       status = Value(status),
       currency = Value(currency),
       guestCount = Value(guestCount),
       totalMinor = Value(totalMinor);
  static Insertable<LocalBookingRow> custom({
    Expression<int>? localId,
    Expression<String>? serverId,
    Expression<String>? tenantId,
    Expression<String>? clientUserId,
    Expression<String>? vendorId,
    Expression<String>? packageId,
    Expression<String>? status,
    Expression<String>? currency,
    Expression<int>? guestCount,
    Expression<int>? totalMinor,
    Expression<int>? version,
    Expression<bool>? dirty,
    Expression<DateTime>? eventStartsAtUtc,
    Expression<DateTime>? serverUpdatedAtUtc,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (serverId != null) 'server_id': serverId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (clientUserId != null) 'client_user_id': clientUserId,
      if (vendorId != null) 'vendor_id': vendorId,
      if (packageId != null) 'package_id': packageId,
      if (status != null) 'status': status,
      if (currency != null) 'currency': currency,
      if (guestCount != null) 'guest_count': guestCount,
      if (totalMinor != null) 'total_minor': totalMinor,
      if (version != null) 'version': version,
      if (dirty != null) 'dirty': dirty,
      if (eventStartsAtUtc != null) 'event_starts_at_utc': eventStartsAtUtc,
      if (serverUpdatedAtUtc != null)
        'server_updated_at_utc': serverUpdatedAtUtc,
    });
  }

  LocalBookingsCompanion copyWith({
    Value<int>? localId,
    Value<String?>? serverId,
    Value<String>? tenantId,
    Value<String>? clientUserId,
    Value<String>? vendorId,
    Value<String>? packageId,
    Value<String>? status,
    Value<String>? currency,
    Value<int>? guestCount,
    Value<int>? totalMinor,
    Value<int>? version,
    Value<bool>? dirty,
    Value<DateTime?>? eventStartsAtUtc,
    Value<DateTime?>? serverUpdatedAtUtc,
  }) {
    return LocalBookingsCompanion(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      tenantId: tenantId ?? this.tenantId,
      clientUserId: clientUserId ?? this.clientUserId,
      vendorId: vendorId ?? this.vendorId,
      packageId: packageId ?? this.packageId,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      guestCount: guestCount ?? this.guestCount,
      totalMinor: totalMinor ?? this.totalMinor,
      version: version ?? this.version,
      dirty: dirty ?? this.dirty,
      eventStartsAtUtc: eventStartsAtUtc ?? this.eventStartsAtUtc,
      serverUpdatedAtUtc: serverUpdatedAtUtc ?? this.serverUpdatedAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<int>(localId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (clientUserId.present) {
      map['client_user_id'] = Variable<String>(clientUserId.value);
    }
    if (vendorId.present) {
      map['vendor_id'] = Variable<String>(vendorId.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (guestCount.present) {
      map['guest_count'] = Variable<int>(guestCount.value);
    }
    if (totalMinor.present) {
      map['total_minor'] = Variable<int>(totalMinor.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (eventStartsAtUtc.present) {
      map['event_starts_at_utc'] = Variable<DateTime>(eventStartsAtUtc.value);
    }
    if (serverUpdatedAtUtc.present) {
      map['server_updated_at_utc'] = Variable<DateTime>(
        serverUpdatedAtUtc.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBookingsCompanion(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('tenantId: $tenantId, ')
          ..write('clientUserId: $clientUserId, ')
          ..write('vendorId: $vendorId, ')
          ..write('packageId: $packageId, ')
          ..write('status: $status, ')
          ..write('currency: $currency, ')
          ..write('guestCount: $guestCount, ')
          ..write('totalMinor: $totalMinor, ')
          ..write('version: $version, ')
          ..write('dirty: $dirty, ')
          ..write('eventStartsAtUtc: $eventStartsAtUtc, ')
          ..write('serverUpdatedAtUtc: $serverUpdatedAtUtc')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $OutboxActionsTable outboxActions = $OutboxActionsTable(this);
  late final $LocalBookingsTable localBookings = $LocalBookingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncCursors,
    outboxActions,
    localBookings,
  ];
}

typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String entityType,
      Value<String?> cursor,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> entityType,
      Value<String?> cursor,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCursorsTable,
          SyncCursorRow,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursorRow,
            BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursorRow>,
          ),
          SyncCursorRow,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entityType = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                entityType: entityType,
                cursor: cursor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entityType,
                Value<String?> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                entityType: entityType,
                cursor: cursor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCursorsTable,
      SyncCursorRow,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursorRow,
        BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursorRow>,
      ),
      SyncCursorRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxActionsTableCreateCompanionBuilder =
    OutboxActionsCompanion Function({
      Value<int> id,
      required String clientMutationId,
      required String actionType,
      required String payloadJson,
      Value<String> state,
      Value<int> attempts,
      Value<String?> lastError,
      Value<int?> dependsOnOutboxId,
      Value<DateTime> createdAt,
    });
typedef $$OutboxActionsTableUpdateCompanionBuilder =
    OutboxActionsCompanion Function({
      Value<int> id,
      Value<String> clientMutationId,
      Value<String> actionType,
      Value<String> payloadJson,
      Value<String> state,
      Value<int> attempts,
      Value<String?> lastError,
      Value<int?> dependsOnOutboxId,
      Value<DateTime> createdAt,
    });

class $$OutboxActionsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxActionsTable> {
  $$OutboxActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientMutationId => $composableBuilder(
    column: $table.clientMutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dependsOnOutboxId => $composableBuilder(
    column: $table.dependsOnOutboxId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxActionsTable> {
  $$OutboxActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientMutationId => $composableBuilder(
    column: $table.clientMutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dependsOnOutboxId => $composableBuilder(
    column: $table.dependsOnOutboxId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxActionsTable> {
  $$OutboxActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientMutationId => $composableBuilder(
    column: $table.clientMutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get dependsOnOutboxId => $composableBuilder(
    column: $table.dependsOnOutboxId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxActionsTable,
          OutboxActionRow,
          $$OutboxActionsTableFilterComposer,
          $$OutboxActionsTableOrderingComposer,
          $$OutboxActionsTableAnnotationComposer,
          $$OutboxActionsTableCreateCompanionBuilder,
          $$OutboxActionsTableUpdateCompanionBuilder,
          (
            OutboxActionRow,
            BaseReferences<_$AppDatabase, $OutboxActionsTable, OutboxActionRow>,
          ),
          OutboxActionRow,
          PrefetchHooks Function()
        > {
  $$OutboxActionsTableTableManager(_$AppDatabase db, $OutboxActionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientMutationId = const Value.absent(),
                Value<String> actionType = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int?> dependsOnOutboxId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OutboxActionsCompanion(
                id: id,
                clientMutationId: clientMutationId,
                actionType: actionType,
                payloadJson: payloadJson,
                state: state,
                attempts: attempts,
                lastError: lastError,
                dependsOnOutboxId: dependsOnOutboxId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientMutationId,
                required String actionType,
                required String payloadJson,
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int?> dependsOnOutboxId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OutboxActionsCompanion.insert(
                id: id,
                clientMutationId: clientMutationId,
                actionType: actionType,
                payloadJson: payloadJson,
                state: state,
                attempts: attempts,
                lastError: lastError,
                dependsOnOutboxId: dependsOnOutboxId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxActionsTable,
      OutboxActionRow,
      $$OutboxActionsTableFilterComposer,
      $$OutboxActionsTableOrderingComposer,
      $$OutboxActionsTableAnnotationComposer,
      $$OutboxActionsTableCreateCompanionBuilder,
      $$OutboxActionsTableUpdateCompanionBuilder,
      (
        OutboxActionRow,
        BaseReferences<_$AppDatabase, $OutboxActionsTable, OutboxActionRow>,
      ),
      OutboxActionRow,
      PrefetchHooks Function()
    >;
typedef $$LocalBookingsTableCreateCompanionBuilder =
    LocalBookingsCompanion Function({
      Value<int> localId,
      Value<String?> serverId,
      required String tenantId,
      required String clientUserId,
      required String vendorId,
      required String packageId,
      required String status,
      required String currency,
      required int guestCount,
      required int totalMinor,
      Value<int> version,
      Value<bool> dirty,
      Value<DateTime?> eventStartsAtUtc,
      Value<DateTime?> serverUpdatedAtUtc,
    });
typedef $$LocalBookingsTableUpdateCompanionBuilder =
    LocalBookingsCompanion Function({
      Value<int> localId,
      Value<String?> serverId,
      Value<String> tenantId,
      Value<String> clientUserId,
      Value<String> vendorId,
      Value<String> packageId,
      Value<String> status,
      Value<String> currency,
      Value<int> guestCount,
      Value<int> totalMinor,
      Value<int> version,
      Value<bool> dirty,
      Value<DateTime?> eventStartsAtUtc,
      Value<DateTime?> serverUpdatedAtUtc,
    });

class $$LocalBookingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBookingsTable> {
  $$LocalBookingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientUserId => $composableBuilder(
    column: $table.clientUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vendorId => $composableBuilder(
    column: $table.vendorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get guestCount => $composableBuilder(
    column: $table.guestCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalMinor => $composableBuilder(
    column: $table.totalMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eventStartsAtUtc => $composableBuilder(
    column: $table.eventStartsAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAtUtc => $composableBuilder(
    column: $table.serverUpdatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBookingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBookingsTable> {
  $$LocalBookingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUserId => $composableBuilder(
    column: $table.clientUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vendorId => $composableBuilder(
    column: $table.vendorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get guestCount => $composableBuilder(
    column: $table.guestCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalMinor => $composableBuilder(
    column: $table.totalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eventStartsAtUtc => $composableBuilder(
    column: $table.eventStartsAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAtUtc => $composableBuilder(
    column: $table.serverUpdatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBookingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBookingsTable> {
  $$LocalBookingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get clientUserId => $composableBuilder(
    column: $table.clientUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vendorId =>
      $composableBuilder(column: $table.vendorId, builder: (column) => column);

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get guestCount => $composableBuilder(
    column: $table.guestCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalMinor => $composableBuilder(
    column: $table.totalMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<DateTime> get eventStartsAtUtc => $composableBuilder(
    column: $table.eventStartsAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAtUtc => $composableBuilder(
    column: $table.serverUpdatedAtUtc,
    builder: (column) => column,
  );
}

class $$LocalBookingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBookingsTable,
          LocalBookingRow,
          $$LocalBookingsTableFilterComposer,
          $$LocalBookingsTableOrderingComposer,
          $$LocalBookingsTableAnnotationComposer,
          $$LocalBookingsTableCreateCompanionBuilder,
          $$LocalBookingsTableUpdateCompanionBuilder,
          (
            LocalBookingRow,
            BaseReferences<_$AppDatabase, $LocalBookingsTable, LocalBookingRow>,
          ),
          LocalBookingRow,
          PrefetchHooks Function()
        > {
  $$LocalBookingsTableTableManager(_$AppDatabase db, $LocalBookingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBookingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBookingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBookingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> clientUserId = const Value.absent(),
                Value<String> vendorId = const Value.absent(),
                Value<String> packageId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> guestCount = const Value.absent(),
                Value<int> totalMinor = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> eventStartsAtUtc = const Value.absent(),
                Value<DateTime?> serverUpdatedAtUtc = const Value.absent(),
              }) => LocalBookingsCompanion(
                localId: localId,
                serverId: serverId,
                tenantId: tenantId,
                clientUserId: clientUserId,
                vendorId: vendorId,
                packageId: packageId,
                status: status,
                currency: currency,
                guestCount: guestCount,
                totalMinor: totalMinor,
                version: version,
                dirty: dirty,
                eventStartsAtUtc: eventStartsAtUtc,
                serverUpdatedAtUtc: serverUpdatedAtUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                required String tenantId,
                required String clientUserId,
                required String vendorId,
                required String packageId,
                required String status,
                required String currency,
                required int guestCount,
                required int totalMinor,
                Value<int> version = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> eventStartsAtUtc = const Value.absent(),
                Value<DateTime?> serverUpdatedAtUtc = const Value.absent(),
              }) => LocalBookingsCompanion.insert(
                localId: localId,
                serverId: serverId,
                tenantId: tenantId,
                clientUserId: clientUserId,
                vendorId: vendorId,
                packageId: packageId,
                status: status,
                currency: currency,
                guestCount: guestCount,
                totalMinor: totalMinor,
                version: version,
                dirty: dirty,
                eventStartsAtUtc: eventStartsAtUtc,
                serverUpdatedAtUtc: serverUpdatedAtUtc,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBookingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBookingsTable,
      LocalBookingRow,
      $$LocalBookingsTableFilterComposer,
      $$LocalBookingsTableOrderingComposer,
      $$LocalBookingsTableAnnotationComposer,
      $$LocalBookingsTableCreateCompanionBuilder,
      $$LocalBookingsTableUpdateCompanionBuilder,
      (
        LocalBookingRow,
        BaseReferences<_$AppDatabase, $LocalBookingsTable, LocalBookingRow>,
      ),
      LocalBookingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$OutboxActionsTableTableManager get outboxActions =>
      $$OutboxActionsTableTableManager(_db, _db.outboxActions);
  $$LocalBookingsTableTableManager get localBookings =>
      $$LocalBookingsTableTableManager(_db, _db.localBookings);
}
