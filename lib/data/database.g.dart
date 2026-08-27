// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AlarmRowsTable extends AlarmRows
    with TableInfo<$AlarmRowsTable, AlarmRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlarmRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatDaysMeta = const VerificationMeta(
    'repeatDays',
  );
  @override
  late final GeneratedColumn<String> repeatDays = GeneratedColumn<String>(
    'repeat_days',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _wakeCheckMeta = const VerificationMeta(
    'wakeCheck',
  );
  @override
  late final GeneratedColumn<String> wakeCheck = GeneratedColumn<String>(
    'wake_check',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _graceMinutesMeta = const VerificationMeta(
    'graceMinutes',
  );
  @override
  late final GeneratedColumn<int> graceMinutes = GeneratedColumn<int>(
    'grace_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _kakugoHostageMeta = const VerificationMeta(
    'kakugoHostage',
  );
  @override
  late final GeneratedColumn<String> kakugoHostage = GeneratedColumn<String>(
    'kakugo_hostage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kakugoRatePerMinuteMeta =
      const VerificationMeta('kakugoRatePerMinute');
  @override
  late final GeneratedColumn<int> kakugoRatePerMinute = GeneratedColumn<int>(
    'kakugo_rate_per_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kakugoCapMeta = const VerificationMeta(
    'kakugoCap',
  );
  @override
  late final GeneratedColumn<int> kakugoCap = GeneratedColumn<int>(
    'kakugo_cap',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hour,
    minute,
    repeatDays,
    enabled,
    wakeCheck,
    graceMinutes,
    kakugoHostage,
    kakugoRatePerMinute,
    kakugoCap,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alarm_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlarmRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('hour')) {
      context.handle(
        _hourMeta,
        hour.isAcceptableOrUnknown(data['hour']!, _hourMeta),
      );
    } else if (isInserting) {
      context.missing(_hourMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    } else if (isInserting) {
      context.missing(_minuteMeta);
    }
    if (data.containsKey('repeat_days')) {
      context.handle(
        _repeatDaysMeta,
        repeatDays.isAcceptableOrUnknown(data['repeat_days']!, _repeatDaysMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('wake_check')) {
      context.handle(
        _wakeCheckMeta,
        wakeCheck.isAcceptableOrUnknown(data['wake_check']!, _wakeCheckMeta),
      );
    } else if (isInserting) {
      context.missing(_wakeCheckMeta);
    }
    if (data.containsKey('grace_minutes')) {
      context.handle(
        _graceMinutesMeta,
        graceMinutes.isAcceptableOrUnknown(
          data['grace_minutes']!,
          _graceMinutesMeta,
        ),
      );
    }
    if (data.containsKey('kakugo_hostage')) {
      context.handle(
        _kakugoHostageMeta,
        kakugoHostage.isAcceptableOrUnknown(
          data['kakugo_hostage']!,
          _kakugoHostageMeta,
        ),
      );
    }
    if (data.containsKey('kakugo_rate_per_minute')) {
      context.handle(
        _kakugoRatePerMinuteMeta,
        kakugoRatePerMinute.isAcceptableOrUnknown(
          data['kakugo_rate_per_minute']!,
          _kakugoRatePerMinuteMeta,
        ),
      );
    }
    if (data.containsKey('kakugo_cap')) {
      context.handle(
        _kakugoCapMeta,
        kakugoCap.isAcceptableOrUnknown(data['kakugo_cap']!, _kakugoCapMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlarmRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlarmRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      hour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour'],
      )!,
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      )!,
      repeatDays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_days'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      wakeCheck: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wake_check'],
      )!,
      graceMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grace_minutes'],
      )!,
      kakugoHostage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kakugo_hostage'],
      ),
      kakugoRatePerMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kakugo_rate_per_minute'],
      ),
      kakugoCap: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kakugo_cap'],
      ),
    );
  }

  @override
  $AlarmRowsTable createAlias(String alias) {
    return $AlarmRowsTable(attachedDatabase, alias);
  }
}

class AlarmRow extends DataClass implements Insertable<AlarmRow> {
  final String id;
  final int hour;
  final int minute;

  /// Comma separated weekdays, 1-7. Empty string = one shot.
  final String repeatDays;
  final bool enabled;
  final String wakeCheck;

  /// Minutes of slack before the burn starts, 1-5. Alarms written before this
  /// column existed keep the old behaviour, which is exactly 1.
  final int graceMinutes;
  final String? kakugoHostage;
  final int? kakugoRatePerMinute;
  final int? kakugoCap;
  const AlarmRow({
    required this.id,
    required this.hour,
    required this.minute,
    required this.repeatDays,
    required this.enabled,
    required this.wakeCheck,
    required this.graceMinutes,
    this.kakugoHostage,
    this.kakugoRatePerMinute,
    this.kakugoCap,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hour'] = Variable<int>(hour);
    map['minute'] = Variable<int>(minute);
    map['repeat_days'] = Variable<String>(repeatDays);
    map['enabled'] = Variable<bool>(enabled);
    map['wake_check'] = Variable<String>(wakeCheck);
    map['grace_minutes'] = Variable<int>(graceMinutes);
    if (!nullToAbsent || kakugoHostage != null) {
      map['kakugo_hostage'] = Variable<String>(kakugoHostage);
    }
    if (!nullToAbsent || kakugoRatePerMinute != null) {
      map['kakugo_rate_per_minute'] = Variable<int>(kakugoRatePerMinute);
    }
    if (!nullToAbsent || kakugoCap != null) {
      map['kakugo_cap'] = Variable<int>(kakugoCap);
    }
    return map;
  }

  AlarmRowsCompanion toCompanion(bool nullToAbsent) {
    return AlarmRowsCompanion(
      id: Value(id),
      hour: Value(hour),
      minute: Value(minute),
      repeatDays: Value(repeatDays),
      enabled: Value(enabled),
      wakeCheck: Value(wakeCheck),
      graceMinutes: Value(graceMinutes),
      kakugoHostage: kakugoHostage == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoHostage),
      kakugoRatePerMinute: kakugoRatePerMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoRatePerMinute),
      kakugoCap: kakugoCap == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoCap),
    );
  }

  factory AlarmRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlarmRow(
      id: serializer.fromJson<String>(json['id']),
      hour: serializer.fromJson<int>(json['hour']),
      minute: serializer.fromJson<int>(json['minute']),
      repeatDays: serializer.fromJson<String>(json['repeatDays']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      wakeCheck: serializer.fromJson<String>(json['wakeCheck']),
      graceMinutes: serializer.fromJson<int>(json['graceMinutes']),
      kakugoHostage: serializer.fromJson<String?>(json['kakugoHostage']),
      kakugoRatePerMinute: serializer.fromJson<int?>(
        json['kakugoRatePerMinute'],
      ),
      kakugoCap: serializer.fromJson<int?>(json['kakugoCap']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hour': serializer.toJson<int>(hour),
      'minute': serializer.toJson<int>(minute),
      'repeatDays': serializer.toJson<String>(repeatDays),
      'enabled': serializer.toJson<bool>(enabled),
      'wakeCheck': serializer.toJson<String>(wakeCheck),
      'graceMinutes': serializer.toJson<int>(graceMinutes),
      'kakugoHostage': serializer.toJson<String?>(kakugoHostage),
      'kakugoRatePerMinute': serializer.toJson<int?>(kakugoRatePerMinute),
      'kakugoCap': serializer.toJson<int?>(kakugoCap),
    };
  }

  AlarmRow copyWith({
    String? id,
    int? hour,
    int? minute,
    String? repeatDays,
    bool? enabled,
    String? wakeCheck,
    int? graceMinutes,
    Value<String?> kakugoHostage = const Value.absent(),
    Value<int?> kakugoRatePerMinute = const Value.absent(),
    Value<int?> kakugoCap = const Value.absent(),
  }) => AlarmRow(
    id: id ?? this.id,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    repeatDays: repeatDays ?? this.repeatDays,
    enabled: enabled ?? this.enabled,
    wakeCheck: wakeCheck ?? this.wakeCheck,
    graceMinutes: graceMinutes ?? this.graceMinutes,
    kakugoHostage: kakugoHostage.present
        ? kakugoHostage.value
        : this.kakugoHostage,
    kakugoRatePerMinute: kakugoRatePerMinute.present
        ? kakugoRatePerMinute.value
        : this.kakugoRatePerMinute,
    kakugoCap: kakugoCap.present ? kakugoCap.value : this.kakugoCap,
  );
  AlarmRow copyWithCompanion(AlarmRowsCompanion data) {
    return AlarmRow(
      id: data.id.present ? data.id.value : this.id,
      hour: data.hour.present ? data.hour.value : this.hour,
      minute: data.minute.present ? data.minute.value : this.minute,
      repeatDays: data.repeatDays.present
          ? data.repeatDays.value
          : this.repeatDays,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      wakeCheck: data.wakeCheck.present ? data.wakeCheck.value : this.wakeCheck,
      graceMinutes: data.graceMinutes.present
          ? data.graceMinutes.value
          : this.graceMinutes,
      kakugoHostage: data.kakugoHostage.present
          ? data.kakugoHostage.value
          : this.kakugoHostage,
      kakugoRatePerMinute: data.kakugoRatePerMinute.present
          ? data.kakugoRatePerMinute.value
          : this.kakugoRatePerMinute,
      kakugoCap: data.kakugoCap.present ? data.kakugoCap.value : this.kakugoCap,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlarmRow(')
          ..write('id: $id, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('repeatDays: $repeatDays, ')
          ..write('enabled: $enabled, ')
          ..write('wakeCheck: $wakeCheck, ')
          ..write('graceMinutes: $graceMinutes, ')
          ..write('kakugoHostage: $kakugoHostage, ')
          ..write('kakugoRatePerMinute: $kakugoRatePerMinute, ')
          ..write('kakugoCap: $kakugoCap')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    hour,
    minute,
    repeatDays,
    enabled,
    wakeCheck,
    graceMinutes,
    kakugoHostage,
    kakugoRatePerMinute,
    kakugoCap,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlarmRow &&
          other.id == this.id &&
          other.hour == this.hour &&
          other.minute == this.minute &&
          other.repeatDays == this.repeatDays &&
          other.enabled == this.enabled &&
          other.wakeCheck == this.wakeCheck &&
          other.graceMinutes == this.graceMinutes &&
          other.kakugoHostage == this.kakugoHostage &&
          other.kakugoRatePerMinute == this.kakugoRatePerMinute &&
          other.kakugoCap == this.kakugoCap);
}

class AlarmRowsCompanion extends UpdateCompanion<AlarmRow> {
  final Value<String> id;
  final Value<int> hour;
  final Value<int> minute;
  final Value<String> repeatDays;
  final Value<bool> enabled;
  final Value<String> wakeCheck;
  final Value<int> graceMinutes;
  final Value<String?> kakugoHostage;
  final Value<int?> kakugoRatePerMinute;
  final Value<int?> kakugoCap;
  final Value<int> rowid;
  const AlarmRowsCompanion({
    this.id = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.repeatDays = const Value.absent(),
    this.enabled = const Value.absent(),
    this.wakeCheck = const Value.absent(),
    this.graceMinutes = const Value.absent(),
    this.kakugoHostage = const Value.absent(),
    this.kakugoRatePerMinute = const Value.absent(),
    this.kakugoCap = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlarmRowsCompanion.insert({
    required String id,
    required int hour,
    required int minute,
    this.repeatDays = const Value.absent(),
    this.enabled = const Value.absent(),
    required String wakeCheck,
    this.graceMinutes = const Value.absent(),
    this.kakugoHostage = const Value.absent(),
    this.kakugoRatePerMinute = const Value.absent(),
    this.kakugoCap = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       hour = Value(hour),
       minute = Value(minute),
       wakeCheck = Value(wakeCheck);
  static Insertable<AlarmRow> custom({
    Expression<String>? id,
    Expression<int>? hour,
    Expression<int>? minute,
    Expression<String>? repeatDays,
    Expression<bool>? enabled,
    Expression<String>? wakeCheck,
    Expression<int>? graceMinutes,
    Expression<String>? kakugoHostage,
    Expression<int>? kakugoRatePerMinute,
    Expression<int>? kakugoCap,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hour != null) 'hour': hour,
      if (minute != null) 'minute': minute,
      if (repeatDays != null) 'repeat_days': repeatDays,
      if (enabled != null) 'enabled': enabled,
      if (wakeCheck != null) 'wake_check': wakeCheck,
      if (graceMinutes != null) 'grace_minutes': graceMinutes,
      if (kakugoHostage != null) 'kakugo_hostage': kakugoHostage,
      if (kakugoRatePerMinute != null)
        'kakugo_rate_per_minute': kakugoRatePerMinute,
      if (kakugoCap != null) 'kakugo_cap': kakugoCap,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlarmRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? hour,
    Value<int>? minute,
    Value<String>? repeatDays,
    Value<bool>? enabled,
    Value<String>? wakeCheck,
    Value<int>? graceMinutes,
    Value<String?>? kakugoHostage,
    Value<int?>? kakugoRatePerMinute,
    Value<int?>? kakugoCap,
    Value<int>? rowid,
  }) {
    return AlarmRowsCompanion(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? this.repeatDays,
      enabled: enabled ?? this.enabled,
      wakeCheck: wakeCheck ?? this.wakeCheck,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      kakugoHostage: kakugoHostage ?? this.kakugoHostage,
      kakugoRatePerMinute: kakugoRatePerMinute ?? this.kakugoRatePerMinute,
      kakugoCap: kakugoCap ?? this.kakugoCap,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (repeatDays.present) {
      map['repeat_days'] = Variable<String>(repeatDays.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (wakeCheck.present) {
      map['wake_check'] = Variable<String>(wakeCheck.value);
    }
    if (graceMinutes.present) {
      map['grace_minutes'] = Variable<int>(graceMinutes.value);
    }
    if (kakugoHostage.present) {
      map['kakugo_hostage'] = Variable<String>(kakugoHostage.value);
    }
    if (kakugoRatePerMinute.present) {
      map['kakugo_rate_per_minute'] = Variable<int>(kakugoRatePerMinute.value);
    }
    if (kakugoCap.present) {
      map['kakugo_cap'] = Variable<int>(kakugoCap.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlarmRowsCompanion(')
          ..write('id: $id, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('repeatDays: $repeatDays, ')
          ..write('enabled: $enabled, ')
          ..write('wakeCheck: $wakeCheck, ')
          ..write('graceMinutes: $graceMinutes, ')
          ..write('kakugoHostage: $kakugoHostage, ')
          ..write('kakugoRatePerMinute: $kakugoRatePerMinute, ')
          ..write('kakugoCap: $kakugoCap, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlarmSessionRowsTable extends AlarmSessionRows
    with TableInfo<$AlarmSessionRowsTable, AlarmSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlarmSessionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alarmIdMeta = const VerificationMeta(
    'alarmId',
  );
  @override
  late final GeneratedColumn<String> alarmId = GeneratedColumn<String>(
    'alarm_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firedAtMsMeta = const VerificationMeta(
    'firedAtMs',
  );
  @override
  late final GeneratedColumn<int> firedAtMs = GeneratedColumn<int>(
    'fired_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dismissedAtMsMeta = const VerificationMeta(
    'dismissedAtMs',
  );
  @override
  late final GeneratedColumn<int> dismissedAtMs = GeneratedColumn<int>(
    'dismissed_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _lossMeta = const VerificationMeta('loss');
  @override
  late final GeneratedColumn<int> loss = GeneratedColumn<int>(
    'loss',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _kakugoHostageMeta = const VerificationMeta(
    'kakugoHostage',
  );
  @override
  late final GeneratedColumn<String> kakugoHostage = GeneratedColumn<String>(
    'kakugo_hostage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kakugoRatePerMinuteMeta =
      const VerificationMeta('kakugoRatePerMinute');
  @override
  late final GeneratedColumn<int> kakugoRatePerMinute = GeneratedColumn<int>(
    'kakugo_rate_per_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kakugoCapMeta = const VerificationMeta(
    'kakugoCap',
  );
  @override
  late final GeneratedColumn<int> kakugoCap = GeneratedColumn<int>(
    'kakugo_cap',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coinsAtFireMeta = const VerificationMeta(
    'coinsAtFire',
  );
  @override
  late final GeneratedColumn<int> coinsAtFire = GeneratedColumn<int>(
    'coins_at_fire',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _graceMinutesMeta = const VerificationMeta(
    'graceMinutes',
  );
  @override
  late final GeneratedColumn<int> graceMinutes = GeneratedColumn<int>(
    'grace_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    alarmId,
    firedAtMs,
    dismissedAtMs,
    status,
    loss,
    kakugoHostage,
    kakugoRatePerMinute,
    kakugoCap,
    coinsAtFire,
    graceMinutes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alarm_session_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlarmSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('alarm_id')) {
      context.handle(
        _alarmIdMeta,
        alarmId.isAcceptableOrUnknown(data['alarm_id']!, _alarmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_alarmIdMeta);
    }
    if (data.containsKey('fired_at_ms')) {
      context.handle(
        _firedAtMsMeta,
        firedAtMs.isAcceptableOrUnknown(data['fired_at_ms']!, _firedAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_firedAtMsMeta);
    }
    if (data.containsKey('dismissed_at_ms')) {
      context.handle(
        _dismissedAtMsMeta,
        dismissedAtMs.isAcceptableOrUnknown(
          data['dismissed_at_ms']!,
          _dismissedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('loss')) {
      context.handle(
        _lossMeta,
        loss.isAcceptableOrUnknown(data['loss']!, _lossMeta),
      );
    }
    if (data.containsKey('kakugo_hostage')) {
      context.handle(
        _kakugoHostageMeta,
        kakugoHostage.isAcceptableOrUnknown(
          data['kakugo_hostage']!,
          _kakugoHostageMeta,
        ),
      );
    }
    if (data.containsKey('kakugo_rate_per_minute')) {
      context.handle(
        _kakugoRatePerMinuteMeta,
        kakugoRatePerMinute.isAcceptableOrUnknown(
          data['kakugo_rate_per_minute']!,
          _kakugoRatePerMinuteMeta,
        ),
      );
    }
    if (data.containsKey('kakugo_cap')) {
      context.handle(
        _kakugoCapMeta,
        kakugoCap.isAcceptableOrUnknown(data['kakugo_cap']!, _kakugoCapMeta),
      );
    }
    if (data.containsKey('coins_at_fire')) {
      context.handle(
        _coinsAtFireMeta,
        coinsAtFire.isAcceptableOrUnknown(
          data['coins_at_fire']!,
          _coinsAtFireMeta,
        ),
      );
    }
    if (data.containsKey('grace_minutes')) {
      context.handle(
        _graceMinutesMeta,
        graceMinutes.isAcceptableOrUnknown(
          data['grace_minutes']!,
          _graceMinutesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlarmSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlarmSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      alarmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alarm_id'],
      )!,
      firedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fired_at_ms'],
      )!,
      dismissedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dismissed_at_ms'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      loss: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}loss'],
      )!,
      kakugoHostage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kakugo_hostage'],
      ),
      kakugoRatePerMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kakugo_rate_per_minute'],
      ),
      kakugoCap: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kakugo_cap'],
      ),
      coinsAtFire: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coins_at_fire'],
      )!,
      graceMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grace_minutes'],
      )!,
    );
  }

  @override
  $AlarmSessionRowsTable createAlias(String alias) {
    return $AlarmSessionRowsTable(attachedDatabase, alias);
  }
}

class AlarmSessionRow extends DataClass implements Insertable<AlarmSessionRow> {
  final String id;
  final String alarmId;
  final int firedAtMs;
  final int? dismissedAtMs;
  final String status;
  final int loss;
  final String? kakugoHostage;
  final int? kakugoRatePerMinute;
  final int? kakugoCap;
  final int coinsAtFire;

  /// The grace window frozen at fire time, alongside the pledge and balance.
  final int graceMinutes;
  const AlarmSessionRow({
    required this.id,
    required this.alarmId,
    required this.firedAtMs,
    this.dismissedAtMs,
    required this.status,
    required this.loss,
    this.kakugoHostage,
    this.kakugoRatePerMinute,
    this.kakugoCap,
    required this.coinsAtFire,
    required this.graceMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['alarm_id'] = Variable<String>(alarmId);
    map['fired_at_ms'] = Variable<int>(firedAtMs);
    if (!nullToAbsent || dismissedAtMs != null) {
      map['dismissed_at_ms'] = Variable<int>(dismissedAtMs);
    }
    map['status'] = Variable<String>(status);
    map['loss'] = Variable<int>(loss);
    if (!nullToAbsent || kakugoHostage != null) {
      map['kakugo_hostage'] = Variable<String>(kakugoHostage);
    }
    if (!nullToAbsent || kakugoRatePerMinute != null) {
      map['kakugo_rate_per_minute'] = Variable<int>(kakugoRatePerMinute);
    }
    if (!nullToAbsent || kakugoCap != null) {
      map['kakugo_cap'] = Variable<int>(kakugoCap);
    }
    map['coins_at_fire'] = Variable<int>(coinsAtFire);
    map['grace_minutes'] = Variable<int>(graceMinutes);
    return map;
  }

  AlarmSessionRowsCompanion toCompanion(bool nullToAbsent) {
    return AlarmSessionRowsCompanion(
      id: Value(id),
      alarmId: Value(alarmId),
      firedAtMs: Value(firedAtMs),
      dismissedAtMs: dismissedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(dismissedAtMs),
      status: Value(status),
      loss: Value(loss),
      kakugoHostage: kakugoHostage == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoHostage),
      kakugoRatePerMinute: kakugoRatePerMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoRatePerMinute),
      kakugoCap: kakugoCap == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoCap),
      coinsAtFire: Value(coinsAtFire),
      graceMinutes: Value(graceMinutes),
    );
  }

  factory AlarmSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlarmSessionRow(
      id: serializer.fromJson<String>(json['id']),
      alarmId: serializer.fromJson<String>(json['alarmId']),
      firedAtMs: serializer.fromJson<int>(json['firedAtMs']),
      dismissedAtMs: serializer.fromJson<int?>(json['dismissedAtMs']),
      status: serializer.fromJson<String>(json['status']),
      loss: serializer.fromJson<int>(json['loss']),
      kakugoHostage: serializer.fromJson<String?>(json['kakugoHostage']),
      kakugoRatePerMinute: serializer.fromJson<int?>(
        json['kakugoRatePerMinute'],
      ),
      kakugoCap: serializer.fromJson<int?>(json['kakugoCap']),
      coinsAtFire: serializer.fromJson<int>(json['coinsAtFire']),
      graceMinutes: serializer.fromJson<int>(json['graceMinutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'alarmId': serializer.toJson<String>(alarmId),
      'firedAtMs': serializer.toJson<int>(firedAtMs),
      'dismissedAtMs': serializer.toJson<int?>(dismissedAtMs),
      'status': serializer.toJson<String>(status),
      'loss': serializer.toJson<int>(loss),
      'kakugoHostage': serializer.toJson<String?>(kakugoHostage),
      'kakugoRatePerMinute': serializer.toJson<int?>(kakugoRatePerMinute),
      'kakugoCap': serializer.toJson<int?>(kakugoCap),
      'coinsAtFire': serializer.toJson<int>(coinsAtFire),
      'graceMinutes': serializer.toJson<int>(graceMinutes),
    };
  }

  AlarmSessionRow copyWith({
    String? id,
    String? alarmId,
    int? firedAtMs,
    Value<int?> dismissedAtMs = const Value.absent(),
    String? status,
    int? loss,
    Value<String?> kakugoHostage = const Value.absent(),
    Value<int?> kakugoRatePerMinute = const Value.absent(),
    Value<int?> kakugoCap = const Value.absent(),
    int? coinsAtFire,
    int? graceMinutes,
  }) => AlarmSessionRow(
    id: id ?? this.id,
    alarmId: alarmId ?? this.alarmId,
    firedAtMs: firedAtMs ?? this.firedAtMs,
    dismissedAtMs: dismissedAtMs.present
        ? dismissedAtMs.value
        : this.dismissedAtMs,
    status: status ?? this.status,
    loss: loss ?? this.loss,
    kakugoHostage: kakugoHostage.present
        ? kakugoHostage.value
        : this.kakugoHostage,
    kakugoRatePerMinute: kakugoRatePerMinute.present
        ? kakugoRatePerMinute.value
        : this.kakugoRatePerMinute,
    kakugoCap: kakugoCap.present ? kakugoCap.value : this.kakugoCap,
    coinsAtFire: coinsAtFire ?? this.coinsAtFire,
    graceMinutes: graceMinutes ?? this.graceMinutes,
  );
  AlarmSessionRow copyWithCompanion(AlarmSessionRowsCompanion data) {
    return AlarmSessionRow(
      id: data.id.present ? data.id.value : this.id,
      alarmId: data.alarmId.present ? data.alarmId.value : this.alarmId,
      firedAtMs: data.firedAtMs.present ? data.firedAtMs.value : this.firedAtMs,
      dismissedAtMs: data.dismissedAtMs.present
          ? data.dismissedAtMs.value
          : this.dismissedAtMs,
      status: data.status.present ? data.status.value : this.status,
      loss: data.loss.present ? data.loss.value : this.loss,
      kakugoHostage: data.kakugoHostage.present
          ? data.kakugoHostage.value
          : this.kakugoHostage,
      kakugoRatePerMinute: data.kakugoRatePerMinute.present
          ? data.kakugoRatePerMinute.value
          : this.kakugoRatePerMinute,
      kakugoCap: data.kakugoCap.present ? data.kakugoCap.value : this.kakugoCap,
      coinsAtFire: data.coinsAtFire.present
          ? data.coinsAtFire.value
          : this.coinsAtFire,
      graceMinutes: data.graceMinutes.present
          ? data.graceMinutes.value
          : this.graceMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlarmSessionRow(')
          ..write('id: $id, ')
          ..write('alarmId: $alarmId, ')
          ..write('firedAtMs: $firedAtMs, ')
          ..write('dismissedAtMs: $dismissedAtMs, ')
          ..write('status: $status, ')
          ..write('loss: $loss, ')
          ..write('kakugoHostage: $kakugoHostage, ')
          ..write('kakugoRatePerMinute: $kakugoRatePerMinute, ')
          ..write('kakugoCap: $kakugoCap, ')
          ..write('coinsAtFire: $coinsAtFire, ')
          ..write('graceMinutes: $graceMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    alarmId,
    firedAtMs,
    dismissedAtMs,
    status,
    loss,
    kakugoHostage,
    kakugoRatePerMinute,
    kakugoCap,
    coinsAtFire,
    graceMinutes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlarmSessionRow &&
          other.id == this.id &&
          other.alarmId == this.alarmId &&
          other.firedAtMs == this.firedAtMs &&
          other.dismissedAtMs == this.dismissedAtMs &&
          other.status == this.status &&
          other.loss == this.loss &&
          other.kakugoHostage == this.kakugoHostage &&
          other.kakugoRatePerMinute == this.kakugoRatePerMinute &&
          other.kakugoCap == this.kakugoCap &&
          other.coinsAtFire == this.coinsAtFire &&
          other.graceMinutes == this.graceMinutes);
}

class AlarmSessionRowsCompanion extends UpdateCompanion<AlarmSessionRow> {
  final Value<String> id;
  final Value<String> alarmId;
  final Value<int> firedAtMs;
  final Value<int?> dismissedAtMs;
  final Value<String> status;
  final Value<int> loss;
  final Value<String?> kakugoHostage;
  final Value<int?> kakugoRatePerMinute;
  final Value<int?> kakugoCap;
  final Value<int> coinsAtFire;
  final Value<int> graceMinutes;
  final Value<int> rowid;
  const AlarmSessionRowsCompanion({
    this.id = const Value.absent(),
    this.alarmId = const Value.absent(),
    this.firedAtMs = const Value.absent(),
    this.dismissedAtMs = const Value.absent(),
    this.status = const Value.absent(),
    this.loss = const Value.absent(),
    this.kakugoHostage = const Value.absent(),
    this.kakugoRatePerMinute = const Value.absent(),
    this.kakugoCap = const Value.absent(),
    this.coinsAtFire = const Value.absent(),
    this.graceMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlarmSessionRowsCompanion.insert({
    required String id,
    required String alarmId,
    required int firedAtMs,
    this.dismissedAtMs = const Value.absent(),
    required String status,
    this.loss = const Value.absent(),
    this.kakugoHostage = const Value.absent(),
    this.kakugoRatePerMinute = const Value.absent(),
    this.kakugoCap = const Value.absent(),
    this.coinsAtFire = const Value.absent(),
    this.graceMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       alarmId = Value(alarmId),
       firedAtMs = Value(firedAtMs),
       status = Value(status);
  static Insertable<AlarmSessionRow> custom({
    Expression<String>? id,
    Expression<String>? alarmId,
    Expression<int>? firedAtMs,
    Expression<int>? dismissedAtMs,
    Expression<String>? status,
    Expression<int>? loss,
    Expression<String>? kakugoHostage,
    Expression<int>? kakugoRatePerMinute,
    Expression<int>? kakugoCap,
    Expression<int>? coinsAtFire,
    Expression<int>? graceMinutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (alarmId != null) 'alarm_id': alarmId,
      if (firedAtMs != null) 'fired_at_ms': firedAtMs,
      if (dismissedAtMs != null) 'dismissed_at_ms': dismissedAtMs,
      if (status != null) 'status': status,
      if (loss != null) 'loss': loss,
      if (kakugoHostage != null) 'kakugo_hostage': kakugoHostage,
      if (kakugoRatePerMinute != null)
        'kakugo_rate_per_minute': kakugoRatePerMinute,
      if (kakugoCap != null) 'kakugo_cap': kakugoCap,
      if (coinsAtFire != null) 'coins_at_fire': coinsAtFire,
      if (graceMinutes != null) 'grace_minutes': graceMinutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlarmSessionRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? alarmId,
    Value<int>? firedAtMs,
    Value<int?>? dismissedAtMs,
    Value<String>? status,
    Value<int>? loss,
    Value<String?>? kakugoHostage,
    Value<int?>? kakugoRatePerMinute,
    Value<int?>? kakugoCap,
    Value<int>? coinsAtFire,
    Value<int>? graceMinutes,
    Value<int>? rowid,
  }) {
    return AlarmSessionRowsCompanion(
      id: id ?? this.id,
      alarmId: alarmId ?? this.alarmId,
      firedAtMs: firedAtMs ?? this.firedAtMs,
      dismissedAtMs: dismissedAtMs ?? this.dismissedAtMs,
      status: status ?? this.status,
      loss: loss ?? this.loss,
      kakugoHostage: kakugoHostage ?? this.kakugoHostage,
      kakugoRatePerMinute: kakugoRatePerMinute ?? this.kakugoRatePerMinute,
      kakugoCap: kakugoCap ?? this.kakugoCap,
      coinsAtFire: coinsAtFire ?? this.coinsAtFire,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (alarmId.present) {
      map['alarm_id'] = Variable<String>(alarmId.value);
    }
    if (firedAtMs.present) {
      map['fired_at_ms'] = Variable<int>(firedAtMs.value);
    }
    if (dismissedAtMs.present) {
      map['dismissed_at_ms'] = Variable<int>(dismissedAtMs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (loss.present) {
      map['loss'] = Variable<int>(loss.value);
    }
    if (kakugoHostage.present) {
      map['kakugo_hostage'] = Variable<String>(kakugoHostage.value);
    }
    if (kakugoRatePerMinute.present) {
      map['kakugo_rate_per_minute'] = Variable<int>(kakugoRatePerMinute.value);
    }
    if (kakugoCap.present) {
      map['kakugo_cap'] = Variable<int>(kakugoCap.value);
    }
    if (coinsAtFire.present) {
      map['coins_at_fire'] = Variable<int>(coinsAtFire.value);
    }
    if (graceMinutes.present) {
      map['grace_minutes'] = Variable<int>(graceMinutes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlarmSessionRowsCompanion(')
          ..write('id: $id, ')
          ..write('alarmId: $alarmId, ')
          ..write('firedAtMs: $firedAtMs, ')
          ..write('dismissedAtMs: $dismissedAtMs, ')
          ..write('status: $status, ')
          ..write('loss: $loss, ')
          ..write('kakugoHostage: $kakugoHostage, ')
          ..write('kakugoRatePerMinute: $kakugoRatePerMinute, ')
          ..write('kakugoCap: $kakugoCap, ')
          ..write('coinsAtFire: $coinsAtFire, ')
          ..write('graceMinutes: $graceMinutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletRowsTable extends WalletRows
    with TableInfo<$WalletRowsTable, WalletRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coinsMeta = const VerificationMeta('coins');
  @override
  late final GeneratedColumn<int> coins = GeneratedColumn<int>(
    'coins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tokensMeta = const VerificationMeta('tokens');
  @override
  late final GeneratedColumn<int> tokens = GeneratedColumn<int>(
    'tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, coins, tokens];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('coins')) {
      context.handle(
        _coinsMeta,
        coins.isAcceptableOrUnknown(data['coins']!, _coinsMeta),
      );
    }
    if (data.containsKey('tokens')) {
      context.handle(
        _tokensMeta,
        tokens.isAcceptableOrUnknown(data['tokens']!, _tokensMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      coins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coins'],
      )!,
      tokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tokens'],
      )!,
    );
  }

  @override
  $WalletRowsTable createAlias(String alias) {
    return $WalletRowsTable(attachedDatabase, alias);
  }
}

class WalletRow extends DataClass implements Insertable<WalletRow> {
  final int id;
  final int coins;
  final int tokens;
  const WalletRow({
    required this.id,
    required this.coins,
    required this.tokens,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['coins'] = Variable<int>(coins);
    map['tokens'] = Variable<int>(tokens);
    return map;
  }

  WalletRowsCompanion toCompanion(bool nullToAbsent) {
    return WalletRowsCompanion(
      id: Value(id),
      coins: Value(coins),
      tokens: Value(tokens),
    );
  }

  factory WalletRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletRow(
      id: serializer.fromJson<int>(json['id']),
      coins: serializer.fromJson<int>(json['coins']),
      tokens: serializer.fromJson<int>(json['tokens']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'coins': serializer.toJson<int>(coins),
      'tokens': serializer.toJson<int>(tokens),
    };
  }

  WalletRow copyWith({int? id, int? coins, int? tokens}) => WalletRow(
    id: id ?? this.id,
    coins: coins ?? this.coins,
    tokens: tokens ?? this.tokens,
  );
  WalletRow copyWithCompanion(WalletRowsCompanion data) {
    return WalletRow(
      id: data.id.present ? data.id.value : this.id,
      coins: data.coins.present ? data.coins.value : this.coins,
      tokens: data.tokens.present ? data.tokens.value : this.tokens,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletRow(')
          ..write('id: $id, ')
          ..write('coins: $coins, ')
          ..write('tokens: $tokens')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, coins, tokens);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletRow &&
          other.id == this.id &&
          other.coins == this.coins &&
          other.tokens == this.tokens);
}

class WalletRowsCompanion extends UpdateCompanion<WalletRow> {
  final Value<int> id;
  final Value<int> coins;
  final Value<int> tokens;
  const WalletRowsCompanion({
    this.id = const Value.absent(),
    this.coins = const Value.absent(),
    this.tokens = const Value.absent(),
  });
  WalletRowsCompanion.insert({
    this.id = const Value.absent(),
    this.coins = const Value.absent(),
    this.tokens = const Value.absent(),
  });
  static Insertable<WalletRow> custom({
    Expression<int>? id,
    Expression<int>? coins,
    Expression<int>? tokens,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (coins != null) 'coins': coins,
      if (tokens != null) 'tokens': tokens,
    });
  }

  WalletRowsCompanion copyWith({
    Value<int>? id,
    Value<int>? coins,
    Value<int>? tokens,
  }) {
    return WalletRowsCompanion(
      id: id ?? this.id,
      coins: coins ?? this.coins,
      tokens: tokens ?? this.tokens,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (coins.present) {
      map['coins'] = Variable<int>(coins.value);
    }
    if (tokens.present) {
      map['tokens'] = Variable<int>(tokens.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletRowsCompanion(')
          ..write('id: $id, ')
          ..write('coins: $coins, ')
          ..write('tokens: $tokens')
          ..write(')'))
        .toString();
  }
}

class $OjisanRowsTable extends OjisanRows
    with TableInfo<$OjisanRowsTable, OjisanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OjisanRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalOversleepsMeta = const VerificationMeta(
    'totalOversleeps',
  );
  @override
  late final GeneratedColumn<int> totalOversleeps = GeneratedColumn<int>(
    'total_oversleeps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalEarnedMeta = const VerificationMeta(
    'totalEarned',
  );
  @override
  late final GeneratedColumn<int> totalEarned = GeneratedColumn<int>(
    'total_earned',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, totalOversleeps, totalEarned];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ojisan_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<OjisanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('total_oversleeps')) {
      context.handle(
        _totalOversleepsMeta,
        totalOversleeps.isAcceptableOrUnknown(
          data['total_oversleeps']!,
          _totalOversleepsMeta,
        ),
      );
    }
    if (data.containsKey('total_earned')) {
      context.handle(
        _totalEarnedMeta,
        totalEarned.isAcceptableOrUnknown(
          data['total_earned']!,
          _totalEarnedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OjisanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OjisanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      totalOversleeps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_oversleeps'],
      )!,
      totalEarned: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_earned'],
      )!,
    );
  }

  @override
  $OjisanRowsTable createAlias(String alias) {
    return $OjisanRowsTable(attachedDatabase, alias);
  }
}

class OjisanRow extends DataClass implements Insertable<OjisanRow> {
  final int id;
  final int totalOversleeps;
  final int totalEarned;
  const OjisanRow({
    required this.id,
    required this.totalOversleeps,
    required this.totalEarned,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['total_oversleeps'] = Variable<int>(totalOversleeps);
    map['total_earned'] = Variable<int>(totalEarned);
    return map;
  }

  OjisanRowsCompanion toCompanion(bool nullToAbsent) {
    return OjisanRowsCompanion(
      id: Value(id),
      totalOversleeps: Value(totalOversleeps),
      totalEarned: Value(totalEarned),
    );
  }

  factory OjisanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OjisanRow(
      id: serializer.fromJson<int>(json['id']),
      totalOversleeps: serializer.fromJson<int>(json['totalOversleeps']),
      totalEarned: serializer.fromJson<int>(json['totalEarned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'totalOversleeps': serializer.toJson<int>(totalOversleeps),
      'totalEarned': serializer.toJson<int>(totalEarned),
    };
  }

  OjisanRow copyWith({int? id, int? totalOversleeps, int? totalEarned}) =>
      OjisanRow(
        id: id ?? this.id,
        totalOversleeps: totalOversleeps ?? this.totalOversleeps,
        totalEarned: totalEarned ?? this.totalEarned,
      );
  OjisanRow copyWithCompanion(OjisanRowsCompanion data) {
    return OjisanRow(
      id: data.id.present ? data.id.value : this.id,
      totalOversleeps: data.totalOversleeps.present
          ? data.totalOversleeps.value
          : this.totalOversleeps,
      totalEarned: data.totalEarned.present
          ? data.totalEarned.value
          : this.totalEarned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OjisanRow(')
          ..write('id: $id, ')
          ..write('totalOversleeps: $totalOversleeps, ')
          ..write('totalEarned: $totalEarned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, totalOversleeps, totalEarned);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OjisanRow &&
          other.id == this.id &&
          other.totalOversleeps == this.totalOversleeps &&
          other.totalEarned == this.totalEarned);
}

class OjisanRowsCompanion extends UpdateCompanion<OjisanRow> {
  final Value<int> id;
  final Value<int> totalOversleeps;
  final Value<int> totalEarned;
  const OjisanRowsCompanion({
    this.id = const Value.absent(),
    this.totalOversleeps = const Value.absent(),
    this.totalEarned = const Value.absent(),
  });
  OjisanRowsCompanion.insert({
    this.id = const Value.absent(),
    this.totalOversleeps = const Value.absent(),
    this.totalEarned = const Value.absent(),
  });
  static Insertable<OjisanRow> custom({
    Expression<int>? id,
    Expression<int>? totalOversleeps,
    Expression<int>? totalEarned,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (totalOversleeps != null) 'total_oversleeps': totalOversleeps,
      if (totalEarned != null) 'total_earned': totalEarned,
    });
  }

  OjisanRowsCompanion copyWith({
    Value<int>? id,
    Value<int>? totalOversleeps,
    Value<int>? totalEarned,
  }) {
    return OjisanRowsCompanion(
      id: id ?? this.id,
      totalOversleeps: totalOversleeps ?? this.totalOversleeps,
      totalEarned: totalEarned ?? this.totalEarned,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (totalOversleeps.present) {
      map['total_oversleeps'] = Variable<int>(totalOversleeps.value);
    }
    if (totalEarned.present) {
      map['total_earned'] = Variable<int>(totalEarned.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OjisanRowsCompanion(')
          ..write('id: $id, ')
          ..write('totalOversleeps: $totalOversleeps, ')
          ..write('totalEarned: $totalEarned')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AlarmRowsTable alarmRows = $AlarmRowsTable(this);
  late final $AlarmSessionRowsTable alarmSessionRows = $AlarmSessionRowsTable(
    this,
  );
  late final $WalletRowsTable walletRows = $WalletRowsTable(this);
  late final $OjisanRowsTable ojisanRows = $OjisanRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    alarmRows,
    alarmSessionRows,
    walletRows,
    ojisanRows,
  ];
}

typedef $$AlarmRowsTableCreateCompanionBuilder = AlarmRowsCompanion Function({
  required String id,
  required int hour,
  required int minute,
  Value<String> repeatDays,
  Value<bool> enabled,
  required String wakeCheck,
  Value<int> graceMinutes,
  Value<String?> kakugoHostage,
  Value<int?> kakugoRatePerMinute,
  Value<int?> kakugoCap,
  Value<int> rowid,
});
typedef $$AlarmRowsTableUpdateCompanionBuilder = AlarmRowsCompanion Function({
  Value<String> id,
  Value<int> hour,
  Value<int> minute,
  Value<String> repeatDays,
  Value<bool> enabled,
  Value<String> wakeCheck,
  Value<int> graceMinutes,
  Value<String?> kakugoHostage,
  Value<int?> kakugoRatePerMinute,
  Value<int?> kakugoCap,
  Value<int> rowid,
});

class $$AlarmRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AlarmRowsTable> {
  $$AlarmRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatDays => $composableBuilder(
    column: $table.repeatDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wakeCheck => $composableBuilder(
    column: $table.wakeCheck,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get graceMinutes => $composableBuilder(
    column: $table.graceMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kakugoHostage => $composableBuilder(
    column: $table.kakugoHostage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kakugoRatePerMinute => $composableBuilder(
    column: $table.kakugoRatePerMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kakugoCap => $composableBuilder(
    column: $table.kakugoCap,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlarmRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlarmRowsTable> {
  $$AlarmRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatDays => $composableBuilder(
    column: $table.repeatDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wakeCheck => $composableBuilder(
    column: $table.wakeCheck,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get graceMinutes => $composableBuilder(
    column: $table.graceMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kakugoHostage => $composableBuilder(
    column: $table.kakugoHostage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kakugoRatePerMinute => $composableBuilder(
    column: $table.kakugoRatePerMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kakugoCap => $composableBuilder(
    column: $table.kakugoCap,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlarmRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlarmRowsTable> {
  $$AlarmRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<String> get repeatDays => $composableBuilder(
    column: $table.repeatDays,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get wakeCheck =>
      $composableBuilder(column: $table.wakeCheck, builder: (column) => column);

  GeneratedColumn<int> get graceMinutes => $composableBuilder(
    column: $table.graceMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kakugoHostage => $composableBuilder(
    column: $table.kakugoHostage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get kakugoRatePerMinute => $composableBuilder(
    column: $table.kakugoRatePerMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get kakugoCap =>
      $composableBuilder(column: $table.kakugoCap, builder: (column) => column);
}

class $$AlarmRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlarmRowsTable,
          AlarmRow,
          $$AlarmRowsTableFilterComposer,
          $$AlarmRowsTableOrderingComposer,
          $$AlarmRowsTableAnnotationComposer,
          $$AlarmRowsTableCreateCompanionBuilder,
          $$AlarmRowsTableUpdateCompanionBuilder,
          (AlarmRow, BaseReferences<_$AppDatabase, $AlarmRowsTable, AlarmRow>),
          AlarmRow,
          PrefetchHooks Function()
        > {
  $$AlarmRowsTableTableManager(_$AppDatabase db, $AlarmRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlarmRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlarmRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlarmRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> hour = const Value.absent(),
                Value<int> minute = const Value.absent(),
                Value<String> repeatDays = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> wakeCheck = const Value.absent(),
                Value<int> graceMinutes = const Value.absent(),
                Value<String?> kakugoHostage = const Value.absent(),
                Value<int?> kakugoRatePerMinute = const Value.absent(),
                Value<int?> kakugoCap = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmRowsCompanion(
                id: id,
                hour: hour,
                minute: minute,
                repeatDays: repeatDays,
                enabled: enabled,
                wakeCheck: wakeCheck,
                graceMinutes: graceMinutes,
                kakugoHostage: kakugoHostage,
                kakugoRatePerMinute: kakugoRatePerMinute,
                kakugoCap: kakugoCap,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int hour,
                required int minute,
                Value<String> repeatDays = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                required String wakeCheck,
                Value<int> graceMinutes = const Value.absent(),
                Value<String?> kakugoHostage = const Value.absent(),
                Value<int?> kakugoRatePerMinute = const Value.absent(),
                Value<int?> kakugoCap = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmRowsCompanion.insert(
                id: id,
                hour: hour,
                minute: minute,
                repeatDays: repeatDays,
                enabled: enabled,
                wakeCheck: wakeCheck,
                graceMinutes: graceMinutes,
                kakugoHostage: kakugoHostage,
                kakugoRatePerMinute: kakugoRatePerMinute,
                kakugoCap: kakugoCap,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlarmRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlarmRowsTable,
      AlarmRow,
      $$AlarmRowsTableFilterComposer,
      $$AlarmRowsTableOrderingComposer,
      $$AlarmRowsTableAnnotationComposer,
      $$AlarmRowsTableCreateCompanionBuilder,
      $$AlarmRowsTableUpdateCompanionBuilder,
      (AlarmRow, BaseReferences<_$AppDatabase, $AlarmRowsTable, AlarmRow>),
      AlarmRow,
      PrefetchHooks Function()
    >;
typedef $$AlarmSessionRowsTableCreateCompanionBuilder =
    AlarmSessionRowsCompanion Function({
      required String id,
      required String alarmId,
      required int firedAtMs,
      Value<int?> dismissedAtMs,
      required String status,
      Value<int> loss,
      Value<String?> kakugoHostage,
      Value<int?> kakugoRatePerMinute,
      Value<int?> kakugoCap,
      Value<int> coinsAtFire,
      Value<int> graceMinutes,
      Value<int> rowid,
    });
typedef $$AlarmSessionRowsTableUpdateCompanionBuilder =
    AlarmSessionRowsCompanion Function({
      Value<String> id,
      Value<String> alarmId,
      Value<int> firedAtMs,
      Value<int?> dismissedAtMs,
      Value<String> status,
      Value<int> loss,
      Value<String?> kakugoHostage,
      Value<int?> kakugoRatePerMinute,
      Value<int?> kakugoCap,
      Value<int> coinsAtFire,
      Value<int> graceMinutes,
      Value<int> rowid,
    });

class $$AlarmSessionRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AlarmSessionRowsTable> {
  $$AlarmSessionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alarmId => $composableBuilder(
    column: $table.alarmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firedAtMs => $composableBuilder(
    column: $table.firedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dismissedAtMs => $composableBuilder(
    column: $table.dismissedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loss => $composableBuilder(
    column: $table.loss,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kakugoHostage => $composableBuilder(
    column: $table.kakugoHostage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kakugoRatePerMinute => $composableBuilder(
    column: $table.kakugoRatePerMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kakugoCap => $composableBuilder(
    column: $table.kakugoCap,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coinsAtFire => $composableBuilder(
    column: $table.coinsAtFire,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get graceMinutes => $composableBuilder(
    column: $table.graceMinutes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlarmSessionRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlarmSessionRowsTable> {
  $$AlarmSessionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alarmId => $composableBuilder(
    column: $table.alarmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firedAtMs => $composableBuilder(
    column: $table.firedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dismissedAtMs => $composableBuilder(
    column: $table.dismissedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loss => $composableBuilder(
    column: $table.loss,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kakugoHostage => $composableBuilder(
    column: $table.kakugoHostage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kakugoRatePerMinute => $composableBuilder(
    column: $table.kakugoRatePerMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kakugoCap => $composableBuilder(
    column: $table.kakugoCap,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coinsAtFire => $composableBuilder(
    column: $table.coinsAtFire,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get graceMinutes => $composableBuilder(
    column: $table.graceMinutes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlarmSessionRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlarmSessionRowsTable> {
  $$AlarmSessionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get alarmId =>
      $composableBuilder(column: $table.alarmId, builder: (column) => column);

  GeneratedColumn<int> get firedAtMs =>
      $composableBuilder(column: $table.firedAtMs, builder: (column) => column);

  GeneratedColumn<int> get dismissedAtMs => $composableBuilder(
    column: $table.dismissedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get loss =>
      $composableBuilder(column: $table.loss, builder: (column) => column);

  GeneratedColumn<String> get kakugoHostage => $composableBuilder(
    column: $table.kakugoHostage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get kakugoRatePerMinute => $composableBuilder(
    column: $table.kakugoRatePerMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get kakugoCap =>
      $composableBuilder(column: $table.kakugoCap, builder: (column) => column);

  GeneratedColumn<int> get coinsAtFire => $composableBuilder(
    column: $table.coinsAtFire,
    builder: (column) => column,
  );

  GeneratedColumn<int> get graceMinutes => $composableBuilder(
    column: $table.graceMinutes,
    builder: (column) => column,
  );
}

class $$AlarmSessionRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlarmSessionRowsTable,
          AlarmSessionRow,
          $$AlarmSessionRowsTableFilterComposer,
          $$AlarmSessionRowsTableOrderingComposer,
          $$AlarmSessionRowsTableAnnotationComposer,
          $$AlarmSessionRowsTableCreateCompanionBuilder,
          $$AlarmSessionRowsTableUpdateCompanionBuilder,
          (
            AlarmSessionRow,
            BaseReferences<
              _$AppDatabase,
              $AlarmSessionRowsTable,
              AlarmSessionRow
            >,
          ),
          AlarmSessionRow,
          PrefetchHooks Function()
        > {
  $$AlarmSessionRowsTableTableManager(
    _$AppDatabase db,
    $AlarmSessionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlarmSessionRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlarmSessionRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlarmSessionRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> alarmId = const Value.absent(),
                Value<int> firedAtMs = const Value.absent(),
                Value<int?> dismissedAtMs = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> loss = const Value.absent(),
                Value<String?> kakugoHostage = const Value.absent(),
                Value<int?> kakugoRatePerMinute = const Value.absent(),
                Value<int?> kakugoCap = const Value.absent(),
                Value<int> coinsAtFire = const Value.absent(),
                Value<int> graceMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmSessionRowsCompanion(
                id: id,
                alarmId: alarmId,
                firedAtMs: firedAtMs,
                dismissedAtMs: dismissedAtMs,
                status: status,
                loss: loss,
                kakugoHostage: kakugoHostage,
                kakugoRatePerMinute: kakugoRatePerMinute,
                kakugoCap: kakugoCap,
                coinsAtFire: coinsAtFire,
                graceMinutes: graceMinutes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String alarmId,
                required int firedAtMs,
                Value<int?> dismissedAtMs = const Value.absent(),
                required String status,
                Value<int> loss = const Value.absent(),
                Value<String?> kakugoHostage = const Value.absent(),
                Value<int?> kakugoRatePerMinute = const Value.absent(),
                Value<int?> kakugoCap = const Value.absent(),
                Value<int> coinsAtFire = const Value.absent(),
                Value<int> graceMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmSessionRowsCompanion.insert(
                id: id,
                alarmId: alarmId,
                firedAtMs: firedAtMs,
                dismissedAtMs: dismissedAtMs,
                status: status,
                loss: loss,
                kakugoHostage: kakugoHostage,
                kakugoRatePerMinute: kakugoRatePerMinute,
                kakugoCap: kakugoCap,
                coinsAtFire: coinsAtFire,
                graceMinutes: graceMinutes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlarmSessionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlarmSessionRowsTable,
      AlarmSessionRow,
      $$AlarmSessionRowsTableFilterComposer,
      $$AlarmSessionRowsTableOrderingComposer,
      $$AlarmSessionRowsTableAnnotationComposer,
      $$AlarmSessionRowsTableCreateCompanionBuilder,
      $$AlarmSessionRowsTableUpdateCompanionBuilder,
      (
        AlarmSessionRow,
        BaseReferences<_$AppDatabase, $AlarmSessionRowsTable, AlarmSessionRow>,
      ),
      AlarmSessionRow,
      PrefetchHooks Function()
    >;
typedef $$WalletRowsTableCreateCompanionBuilder = WalletRowsCompanion Function({
  Value<int> id,
  Value<int> coins,
  Value<int> tokens,
});
typedef $$WalletRowsTableUpdateCompanionBuilder = WalletRowsCompanion Function({
  Value<int> id,
  Value<int> coins,
  Value<int> tokens,
});

class $$WalletRowsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletRowsTable> {
  $$WalletRowsTableFilterComposer({
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

  ColumnFilters<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokens => $composableBuilder(
    column: $table.tokens,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletRowsTable> {
  $$WalletRowsTableOrderingComposer({
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

  ColumnOrderings<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokens => $composableBuilder(
    column: $table.tokens,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletRowsTable> {
  $$WalletRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get coins =>
      $composableBuilder(column: $table.coins, builder: (column) => column);

  GeneratedColumn<int> get tokens =>
      $composableBuilder(column: $table.tokens, builder: (column) => column);
}

class $$WalletRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletRowsTable,
          WalletRow,
          $$WalletRowsTableFilterComposer,
          $$WalletRowsTableOrderingComposer,
          $$WalletRowsTableAnnotationComposer,
          $$WalletRowsTableCreateCompanionBuilder,
          $$WalletRowsTableUpdateCompanionBuilder,
          (
            WalletRow,
            BaseReferences<_$AppDatabase, $WalletRowsTable, WalletRow>,
          ),
          WalletRow,
          PrefetchHooks Function()
        > {
  $$WalletRowsTableTableManager(_$AppDatabase db, $WalletRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> coins = const Value.absent(),
            Value<int> tokens = const Value.absent(),
          }) => WalletRowsCompanion(id: id, coins: coins, tokens: tokens),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> coins = const Value.absent(),
                Value<int> tokens = const Value.absent(),
              }) => WalletRowsCompanion.insert(
                id: id,
                coins: coins,
                tokens: tokens,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletRowsTable,
      WalletRow,
      $$WalletRowsTableFilterComposer,
      $$WalletRowsTableOrderingComposer,
      $$WalletRowsTableAnnotationComposer,
      $$WalletRowsTableCreateCompanionBuilder,
      $$WalletRowsTableUpdateCompanionBuilder,
      (WalletRow, BaseReferences<_$AppDatabase, $WalletRowsTable, WalletRow>),
      WalletRow,
      PrefetchHooks Function()
    >;
typedef $$OjisanRowsTableCreateCompanionBuilder = OjisanRowsCompanion Function({
  Value<int> id,
  Value<int> totalOversleeps,
  Value<int> totalEarned,
});
typedef $$OjisanRowsTableUpdateCompanionBuilder = OjisanRowsCompanion Function({
  Value<int> id,
  Value<int> totalOversleeps,
  Value<int> totalEarned,
});

class $$OjisanRowsTableFilterComposer
    extends Composer<_$AppDatabase, $OjisanRowsTable> {
  $$OjisanRowsTableFilterComposer({
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

  ColumnFilters<int> get totalOversleeps => $composableBuilder(
    column: $table.totalOversleeps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalEarned => $composableBuilder(
    column: $table.totalEarned,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OjisanRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $OjisanRowsTable> {
  $$OjisanRowsTableOrderingComposer({
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

  ColumnOrderings<int> get totalOversleeps => $composableBuilder(
    column: $table.totalOversleeps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalEarned => $composableBuilder(
    column: $table.totalEarned,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OjisanRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OjisanRowsTable> {
  $$OjisanRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get totalOversleeps => $composableBuilder(
    column: $table.totalOversleeps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalEarned => $composableBuilder(
    column: $table.totalEarned,
    builder: (column) => column,
  );
}

class $$OjisanRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OjisanRowsTable,
          OjisanRow,
          $$OjisanRowsTableFilterComposer,
          $$OjisanRowsTableOrderingComposer,
          $$OjisanRowsTableAnnotationComposer,
          $$OjisanRowsTableCreateCompanionBuilder,
          $$OjisanRowsTableUpdateCompanionBuilder,
          (
            OjisanRow,
            BaseReferences<_$AppDatabase, $OjisanRowsTable, OjisanRow>,
          ),
          OjisanRow,
          PrefetchHooks Function()
        > {
  $$OjisanRowsTableTableManager(_$AppDatabase db, $OjisanRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OjisanRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OjisanRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OjisanRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> totalOversleeps = const Value.absent(),
                Value<int> totalEarned = const Value.absent(),
              }) => OjisanRowsCompanion(
                id: id,
                totalOversleeps: totalOversleeps,
                totalEarned: totalEarned,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> totalOversleeps = const Value.absent(),
                Value<int> totalEarned = const Value.absent(),
              }) => OjisanRowsCompanion.insert(
                id: id,
                totalOversleeps: totalOversleeps,
                totalEarned: totalEarned,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OjisanRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OjisanRowsTable,
      OjisanRow,
      $$OjisanRowsTableFilterComposer,
      $$OjisanRowsTableOrderingComposer,
      $$OjisanRowsTableAnnotationComposer,
      $$OjisanRowsTableCreateCompanionBuilder,
      $$OjisanRowsTableUpdateCompanionBuilder,
      (OjisanRow, BaseReferences<_$AppDatabase, $OjisanRowsTable, OjisanRow>),
      OjisanRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AlarmRowsTableTableManager get alarmRows =>
      $$AlarmRowsTableTableManager(_db, _db.alarmRows);
  $$AlarmSessionRowsTableTableManager get alarmSessionRows =>
      $$AlarmSessionRowsTableTableManager(_db, _db.alarmSessionRows);
  $$WalletRowsTableTableManager get walletRows =>
      $$WalletRowsTableTableManager(_db, _db.walletRows);
  $$OjisanRowsTableTableManager get ojisanRows =>
      $$OjisanRowsTableTableManager(_db, _db.ojisanRows);
}
