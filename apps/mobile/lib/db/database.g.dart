// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AmalEntriesTable extends AmalEntries
    with TableInfo<$AmalEntriesTable, AmalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AmalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _amalKeyMeta = const VerificationMeta(
    'amalKey',
  );
  @override
  late final GeneratedColumn<String> amalKey = GeneratedColumn<String>(
    'amal_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta(
    'clientUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> clientUpdatedAt =
      GeneratedColumn<DateTime>(
        'client_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    amalKey,
    date,
    valueJson,
    source,
    clientUpdatedAt,
    serverUpdatedAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'amal_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AmalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('amal_key')) {
      context.handle(
        _amalKeyMeta,
        amalKey.isAcceptableOrUnknown(data['amal_key']!, _amalKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_amalKeyMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(
          data['client_updated_at']!,
          _clientUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientUpdatedAtMeta);
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {amalKey, date};
  @override
  AmalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AmalRow(
      amalKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amal_key'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}client_updated_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $AmalEntriesTable createAlias(String alias) {
    return $AmalEntriesTable(attachedDatabase, alias);
  }
}

class AmalRow extends DataClass implements Insertable<AmalRow> {
  final String amalKey;
  final String date;
  final String valueJson;
  final String source;
  final DateTime clientUpdatedAt;
  final DateTime? serverUpdatedAt;
  final bool synced;
  const AmalRow({
    required this.amalKey,
    required this.date,
    required this.valueJson,
    required this.source,
    required this.clientUpdatedAt,
    this.serverUpdatedAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['amal_key'] = Variable<String>(amalKey);
    map['date'] = Variable<String>(date);
    map['value_json'] = Variable<String>(valueJson);
    map['source'] = Variable<String>(source);
    map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  AmalEntriesCompanion toCompanion(bool nullToAbsent) {
    return AmalEntriesCompanion(
      amalKey: Value(amalKey),
      date: Value(date),
      valueJson: Value(valueJson),
      source: Value(source),
      clientUpdatedAt: Value(clientUpdatedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      synced: Value(synced),
    );
  }

  factory AmalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AmalRow(
      amalKey: serializer.fromJson<String>(json['amalKey']),
      date: serializer.fromJson<String>(json['date']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      source: serializer.fromJson<String>(json['source']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'amalKey': serializer.toJson<String>(amalKey),
      'date': serializer.toJson<String>(date),
      'valueJson': serializer.toJson<String>(valueJson),
      'source': serializer.toJson<String>(source),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  AmalRow copyWith({
    String? amalKey,
    String? date,
    String? valueJson,
    String? source,
    DateTime? clientUpdatedAt,
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    bool? synced,
  }) => AmalRow(
    amalKey: amalKey ?? this.amalKey,
    date: date ?? this.date,
    valueJson: valueJson ?? this.valueJson,
    source: source ?? this.source,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    synced: synced ?? this.synced,
  );
  AmalRow copyWithCompanion(AmalEntriesCompanion data) {
    return AmalRow(
      amalKey: data.amalKey.present ? data.amalKey.value : this.amalKey,
      date: data.date.present ? data.date.value : this.date,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      source: data.source.present ? data.source.value : this.source,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AmalRow(')
          ..write('amalKey: $amalKey, ')
          ..write('date: $date, ')
          ..write('valueJson: $valueJson, ')
          ..write('source: $source, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    amalKey,
    date,
    valueJson,
    source,
    clientUpdatedAt,
    serverUpdatedAt,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AmalRow &&
          other.amalKey == this.amalKey &&
          other.date == this.date &&
          other.valueJson == this.valueJson &&
          other.source == this.source &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.synced == this.synced);
}

class AmalEntriesCompanion extends UpdateCompanion<AmalRow> {
  final Value<String> amalKey;
  final Value<String> date;
  final Value<String> valueJson;
  final Value<String> source;
  final Value<DateTime> clientUpdatedAt;
  final Value<DateTime?> serverUpdatedAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const AmalEntriesCompanion({
    this.amalKey = const Value.absent(),
    this.date = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.source = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AmalEntriesCompanion.insert({
    required String amalKey,
    required String date,
    required String valueJson,
    required String source,
    required DateTime clientUpdatedAt,
    this.serverUpdatedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : amalKey = Value(amalKey),
       date = Value(date),
       valueJson = Value(valueJson),
       source = Value(source),
       clientUpdatedAt = Value(clientUpdatedAt);
  static Insertable<AmalRow> custom({
    Expression<String>? amalKey,
    Expression<String>? date,
    Expression<String>? valueJson,
    Expression<String>? source,
    Expression<DateTime>? clientUpdatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (amalKey != null) 'amal_key': amalKey,
      if (date != null) 'date': date,
      if (valueJson != null) 'value_json': valueJson,
      if (source != null) 'source': source,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AmalEntriesCompanion copyWith({
    Value<String>? amalKey,
    Value<String>? date,
    Value<String>? valueJson,
    Value<String>? source,
    Value<DateTime>? clientUpdatedAt,
    Value<DateTime?>? serverUpdatedAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return AmalEntriesCompanion(
      amalKey: amalKey ?? this.amalKey,
      date: date ?? this.date,
      valueJson: valueJson ?? this.valueJson,
      source: source ?? this.source,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (amalKey.present) {
      map['amal_key'] = Variable<String>(amalKey.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AmalEntriesCompanion(')
          ..write('amalKey: $amalKey, ')
          ..write('date: $date, ')
          ..write('valueJson: $valueJson, ')
          ..write('source: $source, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _amalKeyMeta = const VerificationMeta(
    'amalKey',
  );
  @override
  late final GeneratedColumn<String> amalKey = GeneratedColumn<String>(
    'amal_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta(
    'clientUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> clientUpdatedAt =
      GeneratedColumn<DateTime>(
        'client_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
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
  static const VerificationMeta _deadAtMeta = const VerificationMeta('deadAt');
  @override
  late final GeneratedColumn<DateTime> deadAt = GeneratedColumn<DateTime>(
    'dead_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    amalKey,
    date,
    valueJson,
    source,
    clientUpdatedAt,
    attempts,
    lastError,
    deadAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('amal_key')) {
      context.handle(
        _amalKeyMeta,
        amalKey.isAcceptableOrUnknown(data['amal_key']!, _amalKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_amalKeyMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(
          data['client_updated_at']!,
          _clientUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientUpdatedAtMeta);
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
    if (data.containsKey('dead_at')) {
      context.handle(
        _deadAtMeta,
        deadAt.isAcceptableOrUnknown(data['dead_at']!, _deadAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      amalKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amal_key'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}client_updated_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      deadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dead_at'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int id;
  final String amalKey;
  final String date;
  final String valueJson;
  final String source;
  final DateTime clientUpdatedAt;
  final int attempts;

  /// Last server rejection reason (C-W3d) — shown on the dead-rows list.
  final String? lastError;

  /// Set when the row must never re-POST again (converged via serverValue,
  /// or attempts exhausted). Nullable — null while the row is alive.
  final DateTime? deadAt;
  const OutboxRow({
    required this.id,
    required this.amalKey,
    required this.date,
    required this.valueJson,
    required this.source,
    required this.clientUpdatedAt,
    required this.attempts,
    this.lastError,
    this.deadAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['amal_key'] = Variable<String>(amalKey);
    map['date'] = Variable<String>(date);
    map['value_json'] = Variable<String>(valueJson);
    map['source'] = Variable<String>(source);
    map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || deadAt != null) {
      map['dead_at'] = Variable<DateTime>(deadAt);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      amalKey: Value(amalKey),
      date: Value(date),
      valueJson: Value(valueJson),
      source: Value(source),
      clientUpdatedAt: Value(clientUpdatedAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      deadAt: deadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deadAt),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      id: serializer.fromJson<int>(json['id']),
      amalKey: serializer.fromJson<String>(json['amalKey']),
      date: serializer.fromJson<String>(json['date']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      source: serializer.fromJson<String>(json['source']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      deadAt: serializer.fromJson<DateTime?>(json['deadAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'amalKey': serializer.toJson<String>(amalKey),
      'date': serializer.toJson<String>(date),
      'valueJson': serializer.toJson<String>(valueJson),
      'source': serializer.toJson<String>(source),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'deadAt': serializer.toJson<DateTime?>(deadAt),
    };
  }

  OutboxRow copyWith({
    int? id,
    String? amalKey,
    String? date,
    String? valueJson,
    String? source,
    DateTime? clientUpdatedAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> deadAt = const Value.absent(),
  }) => OutboxRow(
    id: id ?? this.id,
    amalKey: amalKey ?? this.amalKey,
    date: date ?? this.date,
    valueJson: valueJson ?? this.valueJson,
    source: source ?? this.source,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    deadAt: deadAt.present ? deadAt.value : this.deadAt,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      id: data.id.present ? data.id.value : this.id,
      amalKey: data.amalKey.present ? data.amalKey.value : this.amalKey,
      date: data.date.present ? data.date.value : this.date,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      source: data.source.present ? data.source.value : this.source,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      deadAt: data.deadAt.present ? data.deadAt.value : this.deadAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('id: $id, ')
          ..write('amalKey: $amalKey, ')
          ..write('date: $date, ')
          ..write('valueJson: $valueJson, ')
          ..write('source: $source, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('deadAt: $deadAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    amalKey,
    date,
    valueJson,
    source,
    clientUpdatedAt,
    attempts,
    lastError,
    deadAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.id == this.id &&
          other.amalKey == this.amalKey &&
          other.date == this.date &&
          other.valueJson == this.valueJson &&
          other.source == this.source &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.deadAt == this.deadAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> id;
  final Value<String> amalKey;
  final Value<String> date;
  final Value<String> valueJson;
  final Value<String> source;
  final Value<DateTime> clientUpdatedAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime?> deadAt;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.amalKey = const Value.absent(),
    this.date = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.source = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.deadAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String amalKey,
    required String date,
    required String valueJson,
    required String source,
    required DateTime clientUpdatedAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.deadAt = const Value.absent(),
  }) : amalKey = Value(amalKey),
       date = Value(date),
       valueJson = Value(valueJson),
       source = Value(source),
       clientUpdatedAt = Value(clientUpdatedAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? id,
    Expression<String>? amalKey,
    Expression<String>? date,
    Expression<String>? valueJson,
    Expression<String>? source,
    Expression<DateTime>? clientUpdatedAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? deadAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (amalKey != null) 'amal_key': amalKey,
      if (date != null) 'date': date,
      if (valueJson != null) 'value_json': valueJson,
      if (source != null) 'source': source,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (deadAt != null) 'dead_at': deadAt,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? amalKey,
    Value<String>? date,
    Value<String>? valueJson,
    Value<String>? source,
    Value<DateTime>? clientUpdatedAt,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime?>? deadAt,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      amalKey: amalKey ?? this.amalKey,
      date: date ?? this.date,
      valueJson: valueJson ?? this.valueJson,
      source: source ?? this.source,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      deadAt: deadAt ?? this.deadAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (amalKey.present) {
      map['amal_key'] = Variable<String>(amalKey.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (deadAt.present) {
      map['dead_at'] = Variable<DateTime>(deadAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('amalKey: $amalKey, ')
          ..write('date: $date, ')
          ..write('valueJson: $valueJson, ')
          ..write('source: $source, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('deadAt: $deadAt')
          ..write(')'))
        .toString();
  }
}

class $GuestProfilesTable extends GuestProfiles
    with TableInfo<$GuestProfilesTable, GuestProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GuestProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('M'),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('bn'),
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ঢাকা'),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(23.8103),
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(90.4125),
  );
  static const VerificationMeta _tzMeta = const VerificationMeta('tz');
  @override
  late final GeneratedColumn<double> tz = GeneratedColumn<double>(
    'tz',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(6.0),
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ifb'),
  );
  static const VerificationMeta _madhhabMeta = const VerificationMeta(
    'madhhab',
  );
  @override
  late final GeneratedColumn<String> madhhab = GeneratedColumn<String>(
    'madhhab',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('hanafi'),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('general'),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _hijriAdjustMeta = const VerificationMeta(
    'hijriAdjust',
  );
  @override
  late final GeneratedColumn<int> hijriAdjust = GeneratedColumn<int>(
    'hijri_adjust',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _prayerAdjustMeta = const VerificationMeta(
    'prayerAdjust',
  );
  @override
  late final GeneratedColumn<String> prayerAdjust = GeneratedColumn<String>(
    'prayer_adjust',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _onboardingDoneMeta = const VerificationMeta(
    'onboardingDone',
  );
  @override
  late final GeneratedColumn<bool> onboardingDone = GeneratedColumn<bool>(
    'onboarding_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    gender,
    language,
    city,
    lat,
    lng,
    tz,
    method,
    madhhab,
    category,
    themeMode,
    hijriAdjust,
    prayerAdjust,
    onboardingDone,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'guest_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<GuestProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    }
    if (data.containsKey('tz')) {
      context.handle(_tzMeta, tz.isAcceptableOrUnknown(data['tz']!, _tzMeta));
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    }
    if (data.containsKey('madhhab')) {
      context.handle(
        _madhhabMeta,
        madhhab.isAcceptableOrUnknown(data['madhhab']!, _madhhabMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('hijri_adjust')) {
      context.handle(
        _hijriAdjustMeta,
        hijriAdjust.isAcceptableOrUnknown(
          data['hijri_adjust']!,
          _hijriAdjustMeta,
        ),
      );
    }
    if (data.containsKey('prayer_adjust')) {
      context.handle(
        _prayerAdjustMeta,
        prayerAdjust.isAcceptableOrUnknown(
          data['prayer_adjust']!,
          _prayerAdjustMeta,
        ),
      );
    }
    if (data.containsKey('onboarding_done')) {
      context.handle(
        _onboardingDoneMeta,
        onboardingDone.isAcceptableOrUnknown(
          data['onboarding_done']!,
          _onboardingDoneMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GuestProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GuestProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      tz: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tz'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      madhhab: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}madhhab'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      hijriAdjust: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hijri_adjust'],
      )!,
      prayerAdjust: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prayer_adjust'],
      )!,
      onboardingDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_done'],
      )!,
    );
  }

  @override
  $GuestProfilesTable createAlias(String alias) {
    return $GuestProfilesTable(attachedDatabase, alias);
  }
}

class GuestProfile extends DataClass implements Insertable<GuestProfile> {
  final int id;
  final String name;
  final String gender;
  final String language;
  final String city;
  final double lat;
  final double lng;
  final double tz;
  final String method;
  final String madhhab;
  final String category;
  final String themeMode;
  final int hijriAdjust;

  /// The reader's ± minutes per farz waqt (PrayerAdjust JSON, "{}" = none).
  final String prayerAdjust;
  final bool onboardingDone;
  const GuestProfile({
    required this.id,
    required this.name,
    required this.gender,
    required this.language,
    required this.city,
    required this.lat,
    required this.lng,
    required this.tz,
    required this.method,
    required this.madhhab,
    required this.category,
    required this.themeMode,
    required this.hijriAdjust,
    required this.prayerAdjust,
    required this.onboardingDone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['gender'] = Variable<String>(gender);
    map['language'] = Variable<String>(language);
    map['city'] = Variable<String>(city);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    map['tz'] = Variable<double>(tz);
    map['method'] = Variable<String>(method);
    map['madhhab'] = Variable<String>(madhhab);
    map['category'] = Variable<String>(category);
    map['theme_mode'] = Variable<String>(themeMode);
    map['hijri_adjust'] = Variable<int>(hijriAdjust);
    map['prayer_adjust'] = Variable<String>(prayerAdjust);
    map['onboarding_done'] = Variable<bool>(onboardingDone);
    return map;
  }

  GuestProfilesCompanion toCompanion(bool nullToAbsent) {
    return GuestProfilesCompanion(
      id: Value(id),
      name: Value(name),
      gender: Value(gender),
      language: Value(language),
      city: Value(city),
      lat: Value(lat),
      lng: Value(lng),
      tz: Value(tz),
      method: Value(method),
      madhhab: Value(madhhab),
      category: Value(category),
      themeMode: Value(themeMode),
      hijriAdjust: Value(hijriAdjust),
      prayerAdjust: Value(prayerAdjust),
      onboardingDone: Value(onboardingDone),
    );
  }

  factory GuestProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GuestProfile(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      gender: serializer.fromJson<String>(json['gender']),
      language: serializer.fromJson<String>(json['language']),
      city: serializer.fromJson<String>(json['city']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      tz: serializer.fromJson<double>(json['tz']),
      method: serializer.fromJson<String>(json['method']),
      madhhab: serializer.fromJson<String>(json['madhhab']),
      category: serializer.fromJson<String>(json['category']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      hijriAdjust: serializer.fromJson<int>(json['hijriAdjust']),
      prayerAdjust: serializer.fromJson<String>(json['prayerAdjust']),
      onboardingDone: serializer.fromJson<bool>(json['onboardingDone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'gender': serializer.toJson<String>(gender),
      'language': serializer.toJson<String>(language),
      'city': serializer.toJson<String>(city),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'tz': serializer.toJson<double>(tz),
      'method': serializer.toJson<String>(method),
      'madhhab': serializer.toJson<String>(madhhab),
      'category': serializer.toJson<String>(category),
      'themeMode': serializer.toJson<String>(themeMode),
      'hijriAdjust': serializer.toJson<int>(hijriAdjust),
      'prayerAdjust': serializer.toJson<String>(prayerAdjust),
      'onboardingDone': serializer.toJson<bool>(onboardingDone),
    };
  }

  GuestProfile copyWith({
    int? id,
    String? name,
    String? gender,
    String? language,
    String? city,
    double? lat,
    double? lng,
    double? tz,
    String? method,
    String? madhhab,
    String? category,
    String? themeMode,
    int? hijriAdjust,
    String? prayerAdjust,
    bool? onboardingDone,
  }) => GuestProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    gender: gender ?? this.gender,
    language: language ?? this.language,
    city: city ?? this.city,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    tz: tz ?? this.tz,
    method: method ?? this.method,
    madhhab: madhhab ?? this.madhhab,
    category: category ?? this.category,
    themeMode: themeMode ?? this.themeMode,
    hijriAdjust: hijriAdjust ?? this.hijriAdjust,
    prayerAdjust: prayerAdjust ?? this.prayerAdjust,
    onboardingDone: onboardingDone ?? this.onboardingDone,
  );
  GuestProfile copyWithCompanion(GuestProfilesCompanion data) {
    return GuestProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      gender: data.gender.present ? data.gender.value : this.gender,
      language: data.language.present ? data.language.value : this.language,
      city: data.city.present ? data.city.value : this.city,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      tz: data.tz.present ? data.tz.value : this.tz,
      method: data.method.present ? data.method.value : this.method,
      madhhab: data.madhhab.present ? data.madhhab.value : this.madhhab,
      category: data.category.present ? data.category.value : this.category,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      hijriAdjust: data.hijriAdjust.present
          ? data.hijriAdjust.value
          : this.hijriAdjust,
      prayerAdjust: data.prayerAdjust.present
          ? data.prayerAdjust.value
          : this.prayerAdjust,
      onboardingDone: data.onboardingDone.present
          ? data.onboardingDone.value
          : this.onboardingDone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GuestProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('gender: $gender, ')
          ..write('language: $language, ')
          ..write('city: $city, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('tz: $tz, ')
          ..write('method: $method, ')
          ..write('madhhab: $madhhab, ')
          ..write('category: $category, ')
          ..write('themeMode: $themeMode, ')
          ..write('hijriAdjust: $hijriAdjust, ')
          ..write('prayerAdjust: $prayerAdjust, ')
          ..write('onboardingDone: $onboardingDone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    gender,
    language,
    city,
    lat,
    lng,
    tz,
    method,
    madhhab,
    category,
    themeMode,
    hijriAdjust,
    prayerAdjust,
    onboardingDone,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuestProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.gender == this.gender &&
          other.language == this.language &&
          other.city == this.city &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.tz == this.tz &&
          other.method == this.method &&
          other.madhhab == this.madhhab &&
          other.category == this.category &&
          other.themeMode == this.themeMode &&
          other.hijriAdjust == this.hijriAdjust &&
          other.prayerAdjust == this.prayerAdjust &&
          other.onboardingDone == this.onboardingDone);
}

class GuestProfilesCompanion extends UpdateCompanion<GuestProfile> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> gender;
  final Value<String> language;
  final Value<String> city;
  final Value<double> lat;
  final Value<double> lng;
  final Value<double> tz;
  final Value<String> method;
  final Value<String> madhhab;
  final Value<String> category;
  final Value<String> themeMode;
  final Value<int> hijriAdjust;
  final Value<String> prayerAdjust;
  final Value<bool> onboardingDone;
  const GuestProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.gender = const Value.absent(),
    this.language = const Value.absent(),
    this.city = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.tz = const Value.absent(),
    this.method = const Value.absent(),
    this.madhhab = const Value.absent(),
    this.category = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.hijriAdjust = const Value.absent(),
    this.prayerAdjust = const Value.absent(),
    this.onboardingDone = const Value.absent(),
  });
  GuestProfilesCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.gender = const Value.absent(),
    this.language = const Value.absent(),
    this.city = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.tz = const Value.absent(),
    this.method = const Value.absent(),
    this.madhhab = const Value.absent(),
    this.category = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.hijriAdjust = const Value.absent(),
    this.prayerAdjust = const Value.absent(),
    this.onboardingDone = const Value.absent(),
  });
  static Insertable<GuestProfile> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? gender,
    Expression<String>? language,
    Expression<String>? city,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<double>? tz,
    Expression<String>? method,
    Expression<String>? madhhab,
    Expression<String>? category,
    Expression<String>? themeMode,
    Expression<int>? hijriAdjust,
    Expression<String>? prayerAdjust,
    Expression<bool>? onboardingDone,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (gender != null) 'gender': gender,
      if (language != null) 'language': language,
      if (city != null) 'city': city,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (tz != null) 'tz': tz,
      if (method != null) 'method': method,
      if (madhhab != null) 'madhhab': madhhab,
      if (category != null) 'category': category,
      if (themeMode != null) 'theme_mode': themeMode,
      if (hijriAdjust != null) 'hijri_adjust': hijriAdjust,
      if (prayerAdjust != null) 'prayer_adjust': prayerAdjust,
      if (onboardingDone != null) 'onboarding_done': onboardingDone,
    });
  }

  GuestProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? gender,
    Value<String>? language,
    Value<String>? city,
    Value<double>? lat,
    Value<double>? lng,
    Value<double>? tz,
    Value<String>? method,
    Value<String>? madhhab,
    Value<String>? category,
    Value<String>? themeMode,
    Value<int>? hijriAdjust,
    Value<String>? prayerAdjust,
    Value<bool>? onboardingDone,
  }) {
    return GuestProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      language: language ?? this.language,
      city: city ?? this.city,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      tz: tz ?? this.tz,
      method: method ?? this.method,
      madhhab: madhhab ?? this.madhhab,
      category: category ?? this.category,
      themeMode: themeMode ?? this.themeMode,
      hijriAdjust: hijriAdjust ?? this.hijriAdjust,
      prayerAdjust: prayerAdjust ?? this.prayerAdjust,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (tz.present) {
      map['tz'] = Variable<double>(tz.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (madhhab.present) {
      map['madhhab'] = Variable<String>(madhhab.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (hijriAdjust.present) {
      map['hijri_adjust'] = Variable<int>(hijriAdjust.value);
    }
    if (prayerAdjust.present) {
      map['prayer_adjust'] = Variable<String>(prayerAdjust.value);
    }
    if (onboardingDone.present) {
      map['onboarding_done'] = Variable<bool>(onboardingDone.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GuestProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('gender: $gender, ')
          ..write('language: $language, ')
          ..write('city: $city, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('tz: $tz, ')
          ..write('method: $method, ')
          ..write('madhhab: $madhhab, ')
          ..write('category: $category, ')
          ..write('themeMode: $themeMode, ')
          ..write('hijriAdjust: $hijriAdjust, ')
          ..write('prayerAdjust: $prayerAdjust, ')
          ..write('onboardingDone: $onboardingDone')
          ..write(')'))
        .toString();
  }
}

class $SettingsTableTable extends SettingsTable
    with TableInfo<$SettingsTableTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTableTable createAlias(String alias) {
    return $SettingsTableTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsTableCompanion toCompanion(bool nullToAbsent) {
    return SettingsTableCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsTableCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsTableCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsTableCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsTableCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LastReadTable extends LastRead
    with TableInfo<$LastReadTable, LastReadData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LastReadTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _surahMeta = const VerificationMeta('surah');
  @override
  late final GeneratedColumn<int> surah = GeneratedColumn<int>(
    'surah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _ayahMeta = const VerificationMeta('ayah');
  @override
  late final GeneratedColumn<int> ayah = GeneratedColumn<int>(
    'ayah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, surah, ayah, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'last_read';
  @override
  VerificationContext validateIntegrity(
    Insertable<LastReadData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('surah')) {
      context.handle(
        _surahMeta,
        surah.isAcceptableOrUnknown(data['surah']!, _surahMeta),
      );
    }
    if (data.containsKey('ayah')) {
      context.handle(
        _ayahMeta,
        ayah.isAcceptableOrUnknown(data['ayah']!, _ayahMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LastReadData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LastReadData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      surah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}surah'],
      )!,
      ayah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ayah'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LastReadTable createAlias(String alias) {
    return $LastReadTable(attachedDatabase, alias);
  }
}

class LastReadData extends DataClass implements Insertable<LastReadData> {
  final int id;
  final int surah;
  final int ayah;
  final DateTime updatedAt;
  const LastReadData({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['surah'] = Variable<int>(surah);
    map['ayah'] = Variable<int>(ayah);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LastReadCompanion toCompanion(bool nullToAbsent) {
    return LastReadCompanion(
      id: Value(id),
      surah: Value(surah),
      ayah: Value(ayah),
      updatedAt: Value(updatedAt),
    );
  }

  factory LastReadData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LastReadData(
      id: serializer.fromJson<int>(json['id']),
      surah: serializer.fromJson<int>(json['surah']),
      ayah: serializer.fromJson<int>(json['ayah']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'surah': serializer.toJson<int>(surah),
      'ayah': serializer.toJson<int>(ayah),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LastReadData copyWith({
    int? id,
    int? surah,
    int? ayah,
    DateTime? updatedAt,
  }) => LastReadData(
    id: id ?? this.id,
    surah: surah ?? this.surah,
    ayah: ayah ?? this.ayah,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LastReadData copyWithCompanion(LastReadCompanion data) {
    return LastReadData(
      id: data.id.present ? data.id.value : this.id,
      surah: data.surah.present ? data.surah.value : this.surah,
      ayah: data.ayah.present ? data.ayah.value : this.ayah,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LastReadData(')
          ..write('id: $id, ')
          ..write('surah: $surah, ')
          ..write('ayah: $ayah, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, surah, ayah, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LastReadData &&
          other.id == this.id &&
          other.surah == this.surah &&
          other.ayah == this.ayah &&
          other.updatedAt == this.updatedAt);
}

class LastReadCompanion extends UpdateCompanion<LastReadData> {
  final Value<int> id;
  final Value<int> surah;
  final Value<int> ayah;
  final Value<DateTime> updatedAt;
  const LastReadCompanion({
    this.id = const Value.absent(),
    this.surah = const Value.absent(),
    this.ayah = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LastReadCompanion.insert({
    this.id = const Value.absent(),
    this.surah = const Value.absent(),
    this.ayah = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<LastReadData> custom({
    Expression<int>? id,
    Expression<int>? surah,
    Expression<int>? ayah,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (surah != null) 'surah': surah,
      if (ayah != null) 'ayah': ayah,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LastReadCompanion copyWith({
    Value<int>? id,
    Value<int>? surah,
    Value<int>? ayah,
    Value<DateTime>? updatedAt,
  }) {
    return LastReadCompanion(
      id: id ?? this.id,
      surah: surah ?? this.surah,
      ayah: ayah ?? this.ayah,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (surah.present) {
      map['surah'] = Variable<int>(surah.value);
    }
    if (ayah.present) {
      map['ayah'] = Variable<int>(ayah.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LastReadCompanion(')
          ..write('id: $id, ')
          ..write('surah: $surah, ')
          ..write('ayah: $ayah, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AyahBookmarksTable extends AyahBookmarks
    with TableInfo<$AyahBookmarksTable, AyahBookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AyahBookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _surahMeta = const VerificationMeta('surah');
  @override
  late final GeneratedColumn<int> surah = GeneratedColumn<int>(
    'surah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ayahMeta = const VerificationMeta('ayah');
  @override
  late final GeneratedColumn<int> ayah = GeneratedColumn<int>(
    'ayah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  List<GeneratedColumn> get $columns => [surah, ayah, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ayah_bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<AyahBookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('surah')) {
      context.handle(
        _surahMeta,
        surah.isAcceptableOrUnknown(data['surah']!, _surahMeta),
      );
    } else if (isInserting) {
      context.missing(_surahMeta);
    }
    if (data.containsKey('ayah')) {
      context.handle(
        _ayahMeta,
        ayah.isAcceptableOrUnknown(data['ayah']!, _ayahMeta),
      );
    } else if (isInserting) {
      context.missing(_ayahMeta);
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
  Set<GeneratedColumn> get $primaryKey => {surah, ayah};
  @override
  AyahBookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AyahBookmark(
      surah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}surah'],
      )!,
      ayah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ayah'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AyahBookmarksTable createAlias(String alias) {
    return $AyahBookmarksTable(attachedDatabase, alias);
  }
}

class AyahBookmark extends DataClass implements Insertable<AyahBookmark> {
  final int surah;
  final int ayah;
  final DateTime createdAt;
  const AyahBookmark({
    required this.surah,
    required this.ayah,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['surah'] = Variable<int>(surah);
    map['ayah'] = Variable<int>(ayah);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AyahBookmarksCompanion toCompanion(bool nullToAbsent) {
    return AyahBookmarksCompanion(
      surah: Value(surah),
      ayah: Value(ayah),
      createdAt: Value(createdAt),
    );
  }

  factory AyahBookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AyahBookmark(
      surah: serializer.fromJson<int>(json['surah']),
      ayah: serializer.fromJson<int>(json['ayah']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'surah': serializer.toJson<int>(surah),
      'ayah': serializer.toJson<int>(ayah),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AyahBookmark copyWith({int? surah, int? ayah, DateTime? createdAt}) =>
      AyahBookmark(
        surah: surah ?? this.surah,
        ayah: ayah ?? this.ayah,
        createdAt: createdAt ?? this.createdAt,
      );
  AyahBookmark copyWithCompanion(AyahBookmarksCompanion data) {
    return AyahBookmark(
      surah: data.surah.present ? data.surah.value : this.surah,
      ayah: data.ayah.present ? data.ayah.value : this.ayah,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AyahBookmark(')
          ..write('surah: $surah, ')
          ..write('ayah: $ayah, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(surah, ayah, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AyahBookmark &&
          other.surah == this.surah &&
          other.ayah == this.ayah &&
          other.createdAt == this.createdAt);
}

class AyahBookmarksCompanion extends UpdateCompanion<AyahBookmark> {
  final Value<int> surah;
  final Value<int> ayah;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AyahBookmarksCompanion({
    this.surah = const Value.absent(),
    this.ayah = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AyahBookmarksCompanion.insert({
    required int surah,
    required int ayah,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : surah = Value(surah),
       ayah = Value(ayah);
  static Insertable<AyahBookmark> custom({
    Expression<int>? surah,
    Expression<int>? ayah,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (surah != null) 'surah': surah,
      if (ayah != null) 'ayah': ayah,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AyahBookmarksCompanion copyWith({
    Value<int>? surah,
    Value<int>? ayah,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AyahBookmarksCompanion(
      surah: surah ?? this.surah,
      ayah: ayah ?? this.ayah,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (surah.present) {
      map['surah'] = Variable<int>(surah.value);
    }
    if (ayah.present) {
      map['ayah'] = Variable<int>(ayah.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AyahBookmarksCompanion(')
          ..write('surah: $surah, ')
          ..write('ayah: $ayah, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomChecklistItemsTable extends CustomChecklistItems
    with TableInfo<$CustomChecklistItemsTable, CustomChecklistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomChecklistItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    dateKey,
    title,
    done,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_checklist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomChecklistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
  CustomChecklistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomChecklistItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CustomChecklistItemsTable createAlias(String alias) {
    return $CustomChecklistItemsTable(attachedDatabase, alias);
  }
}

class CustomChecklistItem extends DataClass
    implements Insertable<CustomChecklistItem> {
  final int id;
  final String dateKey;
  final String title;
  final bool done;
  final int sortOrder;
  final DateTime createdAt;
  const CustomChecklistItem({
    required this.id,
    required this.dateKey,
    required this.title,
    required this.done,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date_key'] = Variable<String>(dateKey);
    map['title'] = Variable<String>(title);
    map['done'] = Variable<bool>(done);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CustomChecklistItemsCompanion toCompanion(bool nullToAbsent) {
    return CustomChecklistItemsCompanion(
      id: Value(id),
      dateKey: Value(dateKey),
      title: Value(title),
      done: Value(done),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory CustomChecklistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomChecklistItem(
      id: serializer.fromJson<int>(json['id']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      title: serializer.fromJson<String>(json['title']),
      done: serializer.fromJson<bool>(json['done']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dateKey': serializer.toJson<String>(dateKey),
      'title': serializer.toJson<String>(title),
      'done': serializer.toJson<bool>(done),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CustomChecklistItem copyWith({
    int? id,
    String? dateKey,
    String? title,
    bool? done,
    int? sortOrder,
    DateTime? createdAt,
  }) => CustomChecklistItem(
    id: id ?? this.id,
    dateKey: dateKey ?? this.dateKey,
    title: title ?? this.title,
    done: done ?? this.done,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  CustomChecklistItem copyWithCompanion(CustomChecklistItemsCompanion data) {
    return CustomChecklistItem(
      id: data.id.present ? data.id.value : this.id,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      title: data.title.present ? data.title.value : this.title,
      done: data.done.present ? data.done.value : this.done,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomChecklistItem(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, dateKey, title, done, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomChecklistItem &&
          other.id == this.id &&
          other.dateKey == this.dateKey &&
          other.title == this.title &&
          other.done == this.done &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class CustomChecklistItemsCompanion
    extends UpdateCompanion<CustomChecklistItem> {
  final Value<int> id;
  final Value<String> dateKey;
  final Value<String> title;
  final Value<bool> done;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const CustomChecklistItemsCompanion({
    this.id = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.title = const Value.absent(),
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CustomChecklistItemsCompanion.insert({
    this.id = const Value.absent(),
    required String dateKey,
    required String title,
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : dateKey = Value(dateKey),
       title = Value(title);
  static Insertable<CustomChecklistItem> custom({
    Expression<int>? id,
    Expression<String>? dateKey,
    Expression<String>? title,
    Expression<bool>? done,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateKey != null) 'date_key': dateKey,
      if (title != null) 'title': title,
      if (done != null) 'done': done,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CustomChecklistItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? dateKey,
    Value<String>? title,
    Value<bool>? done,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return CustomChecklistItemsCompanion(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      title: title ?? this.title,
      done: done ?? this.done,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomChecklistItemsCompanion(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RemoteCacheTableTable extends RemoteCacheTable
    with TableInfo<$RemoteCacheTableTable, RemoteCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemoteCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, payload, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'remote_cache_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<RemoteCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  RemoteCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemoteCacheRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $RemoteCacheTableTable createAlias(String alias) {
    return $RemoteCacheTableTable(attachedDatabase, alias);
  }
}

class RemoteCacheRow extends DataClass implements Insertable<RemoteCacheRow> {
  final String key;
  final String payload;
  final DateTime fetchedAt;
  const RemoteCacheRow({
    required this.key,
    required this.payload,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  RemoteCacheTableCompanion toCompanion(bool nullToAbsent) {
    return RemoteCacheTableCompanion(
      key: Value(key),
      payload: Value(payload),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory RemoteCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemoteCacheRow(
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  RemoteCacheRow copyWith({
    String? key,
    String? payload,
    DateTime? fetchedAt,
  }) => RemoteCacheRow(
    key: key ?? this.key,
    payload: payload ?? this.payload,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  RemoteCacheRow copyWithCompanion(RemoteCacheTableCompanion data) {
    return RemoteCacheRow(
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemoteCacheRow(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, payload, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteCacheRow &&
          other.key == this.key &&
          other.payload == this.payload &&
          other.fetchedAt == this.fetchedAt);
}

class RemoteCacheTableCompanion extends UpdateCompanion<RemoteCacheRow> {
  final Value<String> key;
  final Value<String> payload;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const RemoteCacheTableCompanion({
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemoteCacheTableCompanion.insert({
    required String key,
    required String payload,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       payload = Value(payload),
       fetchedAt = Value(fetchedAt);
  static Insertable<RemoteCacheRow> custom({
    Expression<String>? key,
    Expression<String>? payload,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemoteCacheTableCompanion copyWith({
    Value<String>? key,
    Value<String>? payload,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return RemoteCacheTableCompanion(
      key: key ?? this.key,
      payload: payload ?? this.payload,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemoteCacheTableCompanion(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AmalEntriesTable amalEntries = $AmalEntriesTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $GuestProfilesTable guestProfiles = $GuestProfilesTable(this);
  late final $SettingsTableTable settingsTable = $SettingsTableTable(this);
  late final $LastReadTable lastRead = $LastReadTable(this);
  late final $AyahBookmarksTable ayahBookmarks = $AyahBookmarksTable(this);
  late final $CustomChecklistItemsTable customChecklistItems =
      $CustomChecklistItemsTable(this);
  late final $RemoteCacheTableTable remoteCacheTable = $RemoteCacheTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    amalEntries,
    outbox,
    guestProfiles,
    settingsTable,
    lastRead,
    ayahBookmarks,
    customChecklistItems,
    remoteCacheTable,
  ];
}

typedef $$AmalEntriesTableCreateCompanionBuilder =
    AmalEntriesCompanion Function({
      required String amalKey,
      required String date,
      required String valueJson,
      required String source,
      required DateTime clientUpdatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$AmalEntriesTableUpdateCompanionBuilder =
    AmalEntriesCompanion Function({
      Value<String> amalKey,
      Value<String> date,
      Value<String> valueJson,
      Value<String> source,
      Value<DateTime> clientUpdatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$AmalEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AmalEntriesTable> {
  $$AmalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get amalKey => $composableBuilder(
    column: $table.amalKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AmalEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AmalEntriesTable> {
  $$AmalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get amalKey => $composableBuilder(
    column: $table.amalKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AmalEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AmalEntriesTable> {
  $$AmalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get amalKey =>
      $composableBuilder(column: $table.amalKey, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$AmalEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AmalEntriesTable,
          AmalRow,
          $$AmalEntriesTableFilterComposer,
          $$AmalEntriesTableOrderingComposer,
          $$AmalEntriesTableAnnotationComposer,
          $$AmalEntriesTableCreateCompanionBuilder,
          $$AmalEntriesTableUpdateCompanionBuilder,
          (AmalRow, BaseReferences<_$AppDatabase, $AmalEntriesTable, AmalRow>),
          AmalRow,
          PrefetchHooks Function()
        > {
  $$AmalEntriesTableTableManager(_$AppDatabase db, $AmalEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AmalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AmalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AmalEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> amalKey = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AmalEntriesCompanion(
                amalKey: amalKey,
                date: date,
                valueJson: valueJson,
                source: source,
                clientUpdatedAt: clientUpdatedAt,
                serverUpdatedAt: serverUpdatedAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String amalKey,
                required String date,
                required String valueJson,
                required String source,
                required DateTime clientUpdatedAt,
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AmalEntriesCompanion.insert(
                amalKey: amalKey,
                date: date,
                valueJson: valueJson,
                source: source,
                clientUpdatedAt: clientUpdatedAt,
                serverUpdatedAt: serverUpdatedAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AmalEntriesTable, AmalRow>(table),
                  BaseReferences<_$AppDatabase, $AmalEntriesTable, AmalRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AmalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AmalEntriesTable,
      AmalRow,
      $$AmalEntriesTableFilterComposer,
      $$AmalEntriesTableOrderingComposer,
      $$AmalEntriesTableAnnotationComposer,
      $$AmalEntriesTableCreateCompanionBuilder,
      $$AmalEntriesTableUpdateCompanionBuilder,
      (AmalRow, BaseReferences<_$AppDatabase, $AmalEntriesTable, AmalRow>),
      AmalRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  required String amalKey,
  required String date,
  required String valueJson,
  required String source,
  required DateTime clientUpdatedAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime?> deadAt,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  Value<String> amalKey,
  Value<String> date,
  Value<String> valueJson,
  Value<String> source,
  Value<DateTime> clientUpdatedAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime?> deadAt,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
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

  ColumnFilters<String> get amalKey => $composableBuilder(
    column: $table.amalKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
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

  ColumnFilters<DateTime> get deadAt => $composableBuilder(
    column: $table.deadAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
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

  ColumnOrderings<String> get amalKey => $composableBuilder(
    column: $table.amalKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
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

  ColumnOrderings<DateTime> get deadAt => $composableBuilder(
    column: $table.deadAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get amalKey =>
      $composableBuilder(column: $table.amalKey, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get deadAt =>
      $composableBuilder(column: $table.deadAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> amalKey = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> deadAt = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                amalKey: amalKey,
                date: date,
                valueJson: valueJson,
                source: source,
                clientUpdatedAt: clientUpdatedAt,
                attempts: attempts,
                lastError: lastError,
                deadAt: deadAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String amalKey,
                required String date,
                required String valueJson,
                required String source,
                required DateTime clientUpdatedAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> deadAt = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                amalKey: amalKey,
                date: date,
                valueJson: valueJson,
                source: source,
                clientUpdatedAt: clientUpdatedAt,
                attempts: attempts,
                lastError: lastError,
                deadAt: deadAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxRow>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$GuestProfilesTableCreateCompanionBuilder =
    GuestProfilesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> gender,
      Value<String> language,
      Value<String> city,
      Value<double> lat,
      Value<double> lng,
      Value<double> tz,
      Value<String> method,
      Value<String> madhhab,
      Value<String> category,
      Value<String> themeMode,
      Value<int> hijriAdjust,
      Value<String> prayerAdjust,
      Value<bool> onboardingDone,
    });
typedef $$GuestProfilesTableUpdateCompanionBuilder =
    GuestProfilesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> gender,
      Value<String> language,
      Value<String> city,
      Value<double> lat,
      Value<double> lng,
      Value<double> tz,
      Value<String> method,
      Value<String> madhhab,
      Value<String> category,
      Value<String> themeMode,
      Value<int> hijriAdjust,
      Value<String> prayerAdjust,
      Value<bool> onboardingDone,
    });

class $$GuestProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $GuestProfilesTable> {
  $$GuestProfilesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get madhhab => $composableBuilder(
    column: $table.madhhab,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hijriAdjust => $composableBuilder(
    column: $table.hijriAdjust,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prayerAdjust => $composableBuilder(
    column: $table.prayerAdjust,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GuestProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $GuestProfilesTable> {
  $$GuestProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get madhhab => $composableBuilder(
    column: $table.madhhab,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hijriAdjust => $composableBuilder(
    column: $table.hijriAdjust,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prayerAdjust => $composableBuilder(
    column: $table.prayerAdjust,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GuestProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GuestProfilesTable> {
  $$GuestProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<double> get tz =>
      $composableBuilder(column: $table.tz, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get madhhab =>
      $composableBuilder(column: $table.madhhab, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<int> get hijriAdjust => $composableBuilder(
    column: $table.hijriAdjust,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prayerAdjust => $composableBuilder(
    column: $table.prayerAdjust,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => column,
  );
}

class $$GuestProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GuestProfilesTable,
          GuestProfile,
          $$GuestProfilesTableFilterComposer,
          $$GuestProfilesTableOrderingComposer,
          $$GuestProfilesTableAnnotationComposer,
          $$GuestProfilesTableCreateCompanionBuilder,
          $$GuestProfilesTableUpdateCompanionBuilder,
          (
            GuestProfile,
            BaseReferences<_$AppDatabase, $GuestProfilesTable, GuestProfile>,
          ),
          GuestProfile,
          PrefetchHooks Function()
        > {
  $$GuestProfilesTableTableManager(_$AppDatabase db, $GuestProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GuestProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GuestProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GuestProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> gender = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<double> tz = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> madhhab = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<int> hijriAdjust = const Value.absent(),
                Value<String> prayerAdjust = const Value.absent(),
                Value<bool> onboardingDone = const Value.absent(),
              }) => GuestProfilesCompanion(
                id: id,
                name: name,
                gender: gender,
                language: language,
                city: city,
                lat: lat,
                lng: lng,
                tz: tz,
                method: method,
                madhhab: madhhab,
                category: category,
                themeMode: themeMode,
                hijriAdjust: hijriAdjust,
                prayerAdjust: prayerAdjust,
                onboardingDone: onboardingDone,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> gender = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<double> tz = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> madhhab = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<int> hijriAdjust = const Value.absent(),
                Value<String> prayerAdjust = const Value.absent(),
                Value<bool> onboardingDone = const Value.absent(),
              }) => GuestProfilesCompanion.insert(
                id: id,
                name: name,
                gender: gender,
                language: language,
                city: city,
                lat: lat,
                lng: lng,
                tz: tz,
                method: method,
                madhhab: madhhab,
                category: category,
                themeMode: themeMode,
                hijriAdjust: hijriAdjust,
                prayerAdjust: prayerAdjust,
                onboardingDone: onboardingDone,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GuestProfilesTable, GuestProfile>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $GuestProfilesTable,
                    GuestProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GuestProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GuestProfilesTable,
      GuestProfile,
      $$GuestProfilesTableFilterComposer,
      $$GuestProfilesTableOrderingComposer,
      $$GuestProfilesTableAnnotationComposer,
      $$GuestProfilesTableCreateCompanionBuilder,
      $$GuestProfilesTableUpdateCompanionBuilder,
      (
        GuestProfile,
        BaseReferences<_$AppDatabase, $GuestProfilesTable, GuestProfile>,
      ),
      GuestProfile,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableTableCreateCompanionBuilder =
    SettingsTableCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableTableUpdateCompanionBuilder =
    SettingsTableCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTableTable> {
  $$SettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTableTable> {
  $$SettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTableTable> {
  $$SettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTableTable,
          SettingRow,
          $$SettingsTableTableFilterComposer,
          $$SettingsTableTableOrderingComposer,
          $$SettingsTableTableAnnotationComposer,
          $$SettingsTableTableCreateCompanionBuilder,
          $$SettingsTableTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTableTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableTableManager(_$AppDatabase db, $SettingsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsTableCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsTableCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTableTable, SettingRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SettingsTableTable,
                    SettingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTableTable,
      SettingRow,
      $$SettingsTableTableFilterComposer,
      $$SettingsTableTableOrderingComposer,
      $$SettingsTableTableAnnotationComposer,
      $$SettingsTableTableCreateCompanionBuilder,
      $$SettingsTableTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$AppDatabase, $SettingsTableTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$LastReadTableCreateCompanionBuilder = LastReadCompanion Function({
  Value<int> id,
  Value<int> surah,
  Value<int> ayah,
  Value<DateTime> updatedAt,
});
typedef $$LastReadTableUpdateCompanionBuilder = LastReadCompanion Function({
  Value<int> id,
  Value<int> surah,
  Value<int> ayah,
  Value<DateTime> updatedAt,
});

class $$LastReadTableFilterComposer
    extends Composer<_$AppDatabase, $LastReadTable> {
  $$LastReadTableFilterComposer({
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

  ColumnFilters<int> get surah => $composableBuilder(
    column: $table.surah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ayah => $composableBuilder(
    column: $table.ayah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LastReadTableOrderingComposer
    extends Composer<_$AppDatabase, $LastReadTable> {
  $$LastReadTableOrderingComposer({
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

  ColumnOrderings<int> get surah => $composableBuilder(
    column: $table.surah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ayah => $composableBuilder(
    column: $table.ayah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LastReadTableAnnotationComposer
    extends Composer<_$AppDatabase, $LastReadTable> {
  $$LastReadTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get surah =>
      $composableBuilder(column: $table.surah, builder: (column) => column);

  GeneratedColumn<int> get ayah =>
      $composableBuilder(column: $table.ayah, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LastReadTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LastReadTable,
          LastReadData,
          $$LastReadTableFilterComposer,
          $$LastReadTableOrderingComposer,
          $$LastReadTableAnnotationComposer,
          $$LastReadTableCreateCompanionBuilder,
          $$LastReadTableUpdateCompanionBuilder,
          (
            LastReadData,
            BaseReferences<_$AppDatabase, $LastReadTable, LastReadData>,
          ),
          LastReadData,
          PrefetchHooks Function()
        > {
  $$LastReadTableTableManager(_$AppDatabase db, $LastReadTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LastReadTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LastReadTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LastReadTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> surah = const Value.absent(),
                Value<int> ayah = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LastReadCompanion(
                id: id,
                surah: surah,
                ayah: ayah,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> surah = const Value.absent(),
                Value<int> ayah = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LastReadCompanion.insert(
                id: id,
                surah: surah,
                ayah: ayah,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LastReadTable, LastReadData>(table),
                  BaseReferences<_$AppDatabase, $LastReadTable, LastReadData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LastReadTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LastReadTable,
      LastReadData,
      $$LastReadTableFilterComposer,
      $$LastReadTableOrderingComposer,
      $$LastReadTableAnnotationComposer,
      $$LastReadTableCreateCompanionBuilder,
      $$LastReadTableUpdateCompanionBuilder,
      (
        LastReadData,
        BaseReferences<_$AppDatabase, $LastReadTable, LastReadData>,
      ),
      LastReadData,
      PrefetchHooks Function()
    >;
typedef $$AyahBookmarksTableCreateCompanionBuilder =
    AyahBookmarksCompanion Function({
      required int surah,
      required int ayah,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$AyahBookmarksTableUpdateCompanionBuilder =
    AyahBookmarksCompanion Function({
      Value<int> surah,
      Value<int> ayah,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$AyahBookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $AyahBookmarksTable> {
  $$AyahBookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get surah => $composableBuilder(
    column: $table.surah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ayah => $composableBuilder(
    column: $table.ayah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AyahBookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $AyahBookmarksTable> {
  $$AyahBookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get surah => $composableBuilder(
    column: $table.surah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ayah => $composableBuilder(
    column: $table.ayah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AyahBookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $AyahBookmarksTable> {
  $$AyahBookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get surah =>
      $composableBuilder(column: $table.surah, builder: (column) => column);

  GeneratedColumn<int> get ayah =>
      $composableBuilder(column: $table.ayah, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AyahBookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AyahBookmarksTable,
          AyahBookmark,
          $$AyahBookmarksTableFilterComposer,
          $$AyahBookmarksTableOrderingComposer,
          $$AyahBookmarksTableAnnotationComposer,
          $$AyahBookmarksTableCreateCompanionBuilder,
          $$AyahBookmarksTableUpdateCompanionBuilder,
          (
            AyahBookmark,
            BaseReferences<_$AppDatabase, $AyahBookmarksTable, AyahBookmark>,
          ),
          AyahBookmark,
          PrefetchHooks Function()
        > {
  $$AyahBookmarksTableTableManager(_$AppDatabase db, $AyahBookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AyahBookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AyahBookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AyahBookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> surah = const Value.absent(),
                Value<int> ayah = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AyahBookmarksCompanion(
                surah: surah,
                ayah: ayah,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int surah,
                required int ayah,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AyahBookmarksCompanion.insert(
                surah: surah,
                ayah: ayah,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AyahBookmarksTable, AyahBookmark>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AyahBookmarksTable,
                    AyahBookmark
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AyahBookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AyahBookmarksTable,
      AyahBookmark,
      $$AyahBookmarksTableFilterComposer,
      $$AyahBookmarksTableOrderingComposer,
      $$AyahBookmarksTableAnnotationComposer,
      $$AyahBookmarksTableCreateCompanionBuilder,
      $$AyahBookmarksTableUpdateCompanionBuilder,
      (
        AyahBookmark,
        BaseReferences<_$AppDatabase, $AyahBookmarksTable, AyahBookmark>,
      ),
      AyahBookmark,
      PrefetchHooks Function()
    >;
typedef $$CustomChecklistItemsTableCreateCompanionBuilder =
    CustomChecklistItemsCompanion Function({
      Value<int> id,
      required String dateKey,
      required String title,
      Value<bool> done,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });
typedef $$CustomChecklistItemsTableUpdateCompanionBuilder =
    CustomChecklistItemsCompanion Function({
      Value<int> id,
      Value<String> dateKey,
      Value<String> title,
      Value<bool> done,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });

class $$CustomChecklistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CustomChecklistItemsTable> {
  $$CustomChecklistItemsTableFilterComposer({
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

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomChecklistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomChecklistItemsTable> {
  $$CustomChecklistItemsTableOrderingComposer({
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

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomChecklistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomChecklistItemsTable> {
  $$CustomChecklistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CustomChecklistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomChecklistItemsTable,
          CustomChecklistItem,
          $$CustomChecklistItemsTableFilterComposer,
          $$CustomChecklistItemsTableOrderingComposer,
          $$CustomChecklistItemsTableAnnotationComposer,
          $$CustomChecklistItemsTableCreateCompanionBuilder,
          $$CustomChecklistItemsTableUpdateCompanionBuilder,
          (
            CustomChecklistItem,
            BaseReferences<
              _$AppDatabase,
              $CustomChecklistItemsTable,
              CustomChecklistItem
            >,
          ),
          CustomChecklistItem,
          PrefetchHooks Function()
        > {
  $$CustomChecklistItemsTableTableManager(
    _$AppDatabase db,
    $CustomChecklistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomChecklistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomChecklistItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CustomChecklistItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CustomChecklistItemsCompanion(
                id: id,
                dateKey: dateKey,
                title: title,
                done: done,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String dateKey,
                required String title,
                Value<bool> done = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CustomChecklistItemsCompanion.insert(
                id: id,
                dateKey: dateKey,
                title: title,
                done: done,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomChecklistItemsTable, CustomChecklistItem>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $CustomChecklistItemsTable,
                    CustomChecklistItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomChecklistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomChecklistItemsTable,
      CustomChecklistItem,
      $$CustomChecklistItemsTableFilterComposer,
      $$CustomChecklistItemsTableOrderingComposer,
      $$CustomChecklistItemsTableAnnotationComposer,
      $$CustomChecklistItemsTableCreateCompanionBuilder,
      $$CustomChecklistItemsTableUpdateCompanionBuilder,
      (
        CustomChecklistItem,
        BaseReferences<
          _$AppDatabase,
          $CustomChecklistItemsTable,
          CustomChecklistItem
        >,
      ),
      CustomChecklistItem,
      PrefetchHooks Function()
    >;
typedef $$RemoteCacheTableTableCreateCompanionBuilder =
    RemoteCacheTableCompanion Function({
      required String key,
      required String payload,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$RemoteCacheTableTableUpdateCompanionBuilder =
    RemoteCacheTableCompanion Function({
      Value<String> key,
      Value<String> payload,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$RemoteCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $RemoteCacheTableTable> {
  $$RemoteCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemoteCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RemoteCacheTableTable> {
  $$RemoteCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemoteCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemoteCacheTableTable> {
  $$RemoteCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$RemoteCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemoteCacheTableTable,
          RemoteCacheRow,
          $$RemoteCacheTableTableFilterComposer,
          $$RemoteCacheTableTableOrderingComposer,
          $$RemoteCacheTableTableAnnotationComposer,
          $$RemoteCacheTableTableCreateCompanionBuilder,
          $$RemoteCacheTableTableUpdateCompanionBuilder,
          (
            RemoteCacheRow,
            BaseReferences<
              _$AppDatabase,
              $RemoteCacheTableTable,
              RemoteCacheRow
            >,
          ),
          RemoteCacheRow,
          PrefetchHooks Function()
        > {
  $$RemoteCacheTableTableTableManager(
    _$AppDatabase db,
    $RemoteCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemoteCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemoteCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemoteCacheTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemoteCacheTableCompanion(
                key: key,
                payload: payload,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String payload,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => RemoteCacheTableCompanion.insert(
                key: key,
                payload: payload,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemoteCacheTableTable, RemoteCacheRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RemoteCacheTableTable,
                    RemoteCacheRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemoteCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemoteCacheTableTable,
      RemoteCacheRow,
      $$RemoteCacheTableTableFilterComposer,
      $$RemoteCacheTableTableOrderingComposer,
      $$RemoteCacheTableTableAnnotationComposer,
      $$RemoteCacheTableTableCreateCompanionBuilder,
      $$RemoteCacheTableTableUpdateCompanionBuilder,
      (
        RemoteCacheRow,
        BaseReferences<_$AppDatabase, $RemoteCacheTableTable, RemoteCacheRow>,
      ),
      RemoteCacheRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AmalEntriesTableTableManager get amalEntries =>
      $$AmalEntriesTableTableManager(_db, _db.amalEntries);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$GuestProfilesTableTableManager get guestProfiles =>
      $$GuestProfilesTableTableManager(_db, _db.guestProfiles);
  $$SettingsTableTableTableManager get settingsTable =>
      $$SettingsTableTableTableManager(_db, _db.settingsTable);
  $$LastReadTableTableManager get lastRead =>
      $$LastReadTableTableManager(_db, _db.lastRead);
  $$AyahBookmarksTableTableManager get ayahBookmarks =>
      $$AyahBookmarksTableTableManager(_db, _db.ayahBookmarks);
  $$CustomChecklistItemsTableTableManager get customChecklistItems =>
      $$CustomChecklistItemsTableTableManager(_db, _db.customChecklistItems);
  $$RemoteCacheTableTableTableManager get remoteCacheTable =>
      $$RemoteCacheTableTableTableManager(_db, _db.remoteCacheTable);
}
