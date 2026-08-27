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
  static const VerificationMeta _snoozeIntervalMinutesMeta =
      const VerificationMeta('snoozeIntervalMinutes');
  @override
  late final GeneratedColumn<int> snoozeIntervalMinutes = GeneratedColumn<int>(
    'snooze_interval_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozeMaxCountMeta = const VerificationMeta(
    'snoozeMaxCount',
  );
  @override
  late final GeneratedColumn<int> snoozeMaxCount = GeneratedColumn<int>(
    'snooze_max_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _soundIdMeta = const VerificationMeta(
    'soundId',
  );
  @override
  late final GeneratedColumn<String> soundId = GeneratedColumn<String>(
    'sound_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(defaultSoundId),
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
  static const VerificationMeta _kakugoSnoozePenaltyMeta =
      const VerificationMeta('kakugoSnoozePenalty');
  @override
  late final GeneratedColumn<int> kakugoSnoozePenalty = GeneratedColumn<int>(
    'kakugo_snooze_penalty',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kakugoSnoozeResetsClockMeta =
      const VerificationMeta('kakugoSnoozeResetsClock');
  @override
  late final GeneratedColumn<bool> kakugoSnoozeResetsClock =
      GeneratedColumn<bool>(
        'kakugo_snooze_resets_clock',
        aliasedName,
        true,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("kakugo_snooze_resets_clock" IN (0, 1))',
        ),
      );
  static const VerificationMeta _oversleepContactMeta = const VerificationMeta(
    'oversleepContact',
  );
  @override
  late final GeneratedColumn<String> oversleepContact = GeneratedColumn<String>(
    'oversleep_contact',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _oversleepShareMeta = const VerificationMeta(
    'oversleepShare',
  );
  @override
  late final GeneratedColumn<String> oversleepShare = GeneratedColumn<String>(
    'oversleep_share',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _oversleepTriggerMinutesMeta =
      const VerificationMeta('oversleepTriggerMinutes');
  @override
  late final GeneratedColumn<int> oversleepTriggerMinutes =
      GeneratedColumn<int>(
        'oversleep_trigger_minutes',
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
    snoozeIntervalMinutes,
    snoozeMaxCount,
    soundId,
    kakugoHostage,
    kakugoRatePerMinute,
    kakugoCap,
    kakugoSnoozePenalty,
    kakugoSnoozeResetsClock,
    oversleepContact,
    oversleepShare,
    oversleepTriggerMinutes,
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
    if (data.containsKey('snooze_interval_minutes')) {
      context.handle(
        _snoozeIntervalMinutesMeta,
        snoozeIntervalMinutes.isAcceptableOrUnknown(
          data['snooze_interval_minutes']!,
          _snoozeIntervalMinutesMeta,
        ),
      );
    }
    if (data.containsKey('snooze_max_count')) {
      context.handle(
        _snoozeMaxCountMeta,
        snoozeMaxCount.isAcceptableOrUnknown(
          data['snooze_max_count']!,
          _snoozeMaxCountMeta,
        ),
      );
    }
    if (data.containsKey('sound_id')) {
      context.handle(
        _soundIdMeta,
        soundId.isAcceptableOrUnknown(data['sound_id']!, _soundIdMeta),
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
    if (data.containsKey('kakugo_snooze_penalty')) {
      context.handle(
        _kakugoSnoozePenaltyMeta,
        kakugoSnoozePenalty.isAcceptableOrUnknown(
          data['kakugo_snooze_penalty']!,
          _kakugoSnoozePenaltyMeta,
        ),
      );
    }
    if (data.containsKey('kakugo_snooze_resets_clock')) {
      context.handle(
        _kakugoSnoozeResetsClockMeta,
        kakugoSnoozeResetsClock.isAcceptableOrUnknown(
          data['kakugo_snooze_resets_clock']!,
          _kakugoSnoozeResetsClockMeta,
        ),
      );
    }
    if (data.containsKey('oversleep_contact')) {
      context.handle(
        _oversleepContactMeta,
        oversleepContact.isAcceptableOrUnknown(
          data['oversleep_contact']!,
          _oversleepContactMeta,
        ),
      );
    }
    if (data.containsKey('oversleep_share')) {
      context.handle(
        _oversleepShareMeta,
        oversleepShare.isAcceptableOrUnknown(
          data['oversleep_share']!,
          _oversleepShareMeta,
        ),
      );
    }
    if (data.containsKey('oversleep_trigger_minutes')) {
      context.handle(
        _oversleepTriggerMinutesMeta,
        oversleepTriggerMinutes.isAcceptableOrUnknown(
          data['oversleep_trigger_minutes']!,
          _oversleepTriggerMinutesMeta,
        ),
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
      snoozeIntervalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_interval_minutes'],
      ),
      snoozeMaxCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_max_count'],
      ),
      soundId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sound_id'],
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
      kakugoSnoozePenalty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kakugo_snooze_penalty'],
      ),
      kakugoSnoozeResetsClock: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}kakugo_snooze_resets_clock'],
      ),
      oversleepContact: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}oversleep_contact'],
      ),
      oversleepShare: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}oversleep_share'],
      ),
      oversleepTriggerMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}oversleep_trigger_minutes'],
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

  /// Both null = this alarm cannot be snoozed. Rows written before v4 read
  /// that way, which is the rule they were saved under.
  final int? snoozeIntervalMinutes;
  final int? snoozeMaxCount;

  /// A sound library id, or `file:<path>`. Alarms written before v4 rang with
  /// the one bundled sound, which is `bell`.
  final String soundId;
  final String? kakugoHostage;
  final int? kakugoRatePerMinute;
  final int? kakugoCap;

  /// Stage B of the v2 alarm spec: the coin cost of one snooze, and whether
  /// snoozing restarts the clock. Added in the v4 migration, together with
  /// [oversleepContact], so that stage needs no migration of its own. Nothing
  /// reads them yet.
  final int? kakugoSnoozePenalty;
  final bool? kakugoSnoozeResetsClock;

  /// Stage B: the whole OversleepContact as one JSON blob, because it is only
  /// ever read and written whole.
  final String? oversleepContact;

  /// Stage C: the whole OversleepShare, one JSON blob for the same reason the
  /// contact is one — it is read and written whole and nothing queries into it.
  final String? oversleepShare;

  /// How many minutes after the grace window the contact and the share go out.
  ///
  /// Nullable because a v6 row kept this number inside [oversleepContact]'s
  /// JSON, where it belonged to the contact alone. Null means "read it out of
  /// that blob, or take the default"; the writer always fills the column in,
  /// so a row only ever reads as null once.
  final int? oversleepTriggerMinutes;
  const AlarmRow({
    required this.id,
    required this.hour,
    required this.minute,
    required this.repeatDays,
    required this.enabled,
    required this.wakeCheck,
    required this.graceMinutes,
    this.snoozeIntervalMinutes,
    this.snoozeMaxCount,
    required this.soundId,
    this.kakugoHostage,
    this.kakugoRatePerMinute,
    this.kakugoCap,
    this.kakugoSnoozePenalty,
    this.kakugoSnoozeResetsClock,
    this.oversleepContact,
    this.oversleepShare,
    this.oversleepTriggerMinutes,
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
    if (!nullToAbsent || snoozeIntervalMinutes != null) {
      map['snooze_interval_minutes'] = Variable<int>(snoozeIntervalMinutes);
    }
    if (!nullToAbsent || snoozeMaxCount != null) {
      map['snooze_max_count'] = Variable<int>(snoozeMaxCount);
    }
    map['sound_id'] = Variable<String>(soundId);
    if (!nullToAbsent || kakugoHostage != null) {
      map['kakugo_hostage'] = Variable<String>(kakugoHostage);
    }
    if (!nullToAbsent || kakugoRatePerMinute != null) {
      map['kakugo_rate_per_minute'] = Variable<int>(kakugoRatePerMinute);
    }
    if (!nullToAbsent || kakugoCap != null) {
      map['kakugo_cap'] = Variable<int>(kakugoCap);
    }
    if (!nullToAbsent || kakugoSnoozePenalty != null) {
      map['kakugo_snooze_penalty'] = Variable<int>(kakugoSnoozePenalty);
    }
    if (!nullToAbsent || kakugoSnoozeResetsClock != null) {
      map['kakugo_snooze_resets_clock'] = Variable<bool>(
        kakugoSnoozeResetsClock,
      );
    }
    if (!nullToAbsent || oversleepContact != null) {
      map['oversleep_contact'] = Variable<String>(oversleepContact);
    }
    if (!nullToAbsent || oversleepShare != null) {
      map['oversleep_share'] = Variable<String>(oversleepShare);
    }
    if (!nullToAbsent || oversleepTriggerMinutes != null) {
      map['oversleep_trigger_minutes'] = Variable<int>(oversleepTriggerMinutes);
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
      snoozeIntervalMinutes: snoozeIntervalMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozeIntervalMinutes),
      snoozeMaxCount: snoozeMaxCount == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozeMaxCount),
      soundId: Value(soundId),
      kakugoHostage: kakugoHostage == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoHostage),
      kakugoRatePerMinute: kakugoRatePerMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoRatePerMinute),
      kakugoCap: kakugoCap == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoCap),
      kakugoSnoozePenalty: kakugoSnoozePenalty == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoSnoozePenalty),
      kakugoSnoozeResetsClock: kakugoSnoozeResetsClock == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoSnoozeResetsClock),
      oversleepContact: oversleepContact == null && nullToAbsent
          ? const Value.absent()
          : Value(oversleepContact),
      oversleepShare: oversleepShare == null && nullToAbsent
          ? const Value.absent()
          : Value(oversleepShare),
      oversleepTriggerMinutes: oversleepTriggerMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(oversleepTriggerMinutes),
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
      snoozeIntervalMinutes: serializer.fromJson<int?>(
        json['snoozeIntervalMinutes'],
      ),
      snoozeMaxCount: serializer.fromJson<int?>(json['snoozeMaxCount']),
      soundId: serializer.fromJson<String>(json['soundId']),
      kakugoHostage: serializer.fromJson<String?>(json['kakugoHostage']),
      kakugoRatePerMinute: serializer.fromJson<int?>(
        json['kakugoRatePerMinute'],
      ),
      kakugoCap: serializer.fromJson<int?>(json['kakugoCap']),
      kakugoSnoozePenalty: serializer.fromJson<int?>(
        json['kakugoSnoozePenalty'],
      ),
      kakugoSnoozeResetsClock: serializer.fromJson<bool?>(
        json['kakugoSnoozeResetsClock'],
      ),
      oversleepContact: serializer.fromJson<String?>(json['oversleepContact']),
      oversleepShare: serializer.fromJson<String?>(json['oversleepShare']),
      oversleepTriggerMinutes: serializer.fromJson<int?>(
        json['oversleepTriggerMinutes'],
      ),
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
      'snoozeIntervalMinutes': serializer.toJson<int?>(snoozeIntervalMinutes),
      'snoozeMaxCount': serializer.toJson<int?>(snoozeMaxCount),
      'soundId': serializer.toJson<String>(soundId),
      'kakugoHostage': serializer.toJson<String?>(kakugoHostage),
      'kakugoRatePerMinute': serializer.toJson<int?>(kakugoRatePerMinute),
      'kakugoCap': serializer.toJson<int?>(kakugoCap),
      'kakugoSnoozePenalty': serializer.toJson<int?>(kakugoSnoozePenalty),
      'kakugoSnoozeResetsClock': serializer.toJson<bool?>(
        kakugoSnoozeResetsClock,
      ),
      'oversleepContact': serializer.toJson<String?>(oversleepContact),
      'oversleepShare': serializer.toJson<String?>(oversleepShare),
      'oversleepTriggerMinutes': serializer.toJson<int?>(
        oversleepTriggerMinutes,
      ),
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
    Value<int?> snoozeIntervalMinutes = const Value.absent(),
    Value<int?> snoozeMaxCount = const Value.absent(),
    String? soundId,
    Value<String?> kakugoHostage = const Value.absent(),
    Value<int?> kakugoRatePerMinute = const Value.absent(),
    Value<int?> kakugoCap = const Value.absent(),
    Value<int?> kakugoSnoozePenalty = const Value.absent(),
    Value<bool?> kakugoSnoozeResetsClock = const Value.absent(),
    Value<String?> oversleepContact = const Value.absent(),
    Value<String?> oversleepShare = const Value.absent(),
    Value<int?> oversleepTriggerMinutes = const Value.absent(),
  }) => AlarmRow(
    id: id ?? this.id,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    repeatDays: repeatDays ?? this.repeatDays,
    enabled: enabled ?? this.enabled,
    wakeCheck: wakeCheck ?? this.wakeCheck,
    graceMinutes: graceMinutes ?? this.graceMinutes,
    snoozeIntervalMinutes: snoozeIntervalMinutes.present
        ? snoozeIntervalMinutes.value
        : this.snoozeIntervalMinutes,
    snoozeMaxCount: snoozeMaxCount.present
        ? snoozeMaxCount.value
        : this.snoozeMaxCount,
    soundId: soundId ?? this.soundId,
    kakugoHostage: kakugoHostage.present
        ? kakugoHostage.value
        : this.kakugoHostage,
    kakugoRatePerMinute: kakugoRatePerMinute.present
        ? kakugoRatePerMinute.value
        : this.kakugoRatePerMinute,
    kakugoCap: kakugoCap.present ? kakugoCap.value : this.kakugoCap,
    kakugoSnoozePenalty: kakugoSnoozePenalty.present
        ? kakugoSnoozePenalty.value
        : this.kakugoSnoozePenalty,
    kakugoSnoozeResetsClock: kakugoSnoozeResetsClock.present
        ? kakugoSnoozeResetsClock.value
        : this.kakugoSnoozeResetsClock,
    oversleepContact: oversleepContact.present
        ? oversleepContact.value
        : this.oversleepContact,
    oversleepShare: oversleepShare.present
        ? oversleepShare.value
        : this.oversleepShare,
    oversleepTriggerMinutes: oversleepTriggerMinutes.present
        ? oversleepTriggerMinutes.value
        : this.oversleepTriggerMinutes,
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
      snoozeIntervalMinutes: data.snoozeIntervalMinutes.present
          ? data.snoozeIntervalMinutes.value
          : this.snoozeIntervalMinutes,
      snoozeMaxCount: data.snoozeMaxCount.present
          ? data.snoozeMaxCount.value
          : this.snoozeMaxCount,
      soundId: data.soundId.present ? data.soundId.value : this.soundId,
      kakugoHostage: data.kakugoHostage.present
          ? data.kakugoHostage.value
          : this.kakugoHostage,
      kakugoRatePerMinute: data.kakugoRatePerMinute.present
          ? data.kakugoRatePerMinute.value
          : this.kakugoRatePerMinute,
      kakugoCap: data.kakugoCap.present ? data.kakugoCap.value : this.kakugoCap,
      kakugoSnoozePenalty: data.kakugoSnoozePenalty.present
          ? data.kakugoSnoozePenalty.value
          : this.kakugoSnoozePenalty,
      kakugoSnoozeResetsClock: data.kakugoSnoozeResetsClock.present
          ? data.kakugoSnoozeResetsClock.value
          : this.kakugoSnoozeResetsClock,
      oversleepContact: data.oversleepContact.present
          ? data.oversleepContact.value
          : this.oversleepContact,
      oversleepShare: data.oversleepShare.present
          ? data.oversleepShare.value
          : this.oversleepShare,
      oversleepTriggerMinutes: data.oversleepTriggerMinutes.present
          ? data.oversleepTriggerMinutes.value
          : this.oversleepTriggerMinutes,
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
          ..write('snoozeIntervalMinutes: $snoozeIntervalMinutes, ')
          ..write('snoozeMaxCount: $snoozeMaxCount, ')
          ..write('soundId: $soundId, ')
          ..write('kakugoHostage: $kakugoHostage, ')
          ..write('kakugoRatePerMinute: $kakugoRatePerMinute, ')
          ..write('kakugoCap: $kakugoCap, ')
          ..write('kakugoSnoozePenalty: $kakugoSnoozePenalty, ')
          ..write('kakugoSnoozeResetsClock: $kakugoSnoozeResetsClock, ')
          ..write('oversleepContact: $oversleepContact, ')
          ..write('oversleepShare: $oversleepShare, ')
          ..write('oversleepTriggerMinutes: $oversleepTriggerMinutes')
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
    snoozeIntervalMinutes,
    snoozeMaxCount,
    soundId,
    kakugoHostage,
    kakugoRatePerMinute,
    kakugoCap,
    kakugoSnoozePenalty,
    kakugoSnoozeResetsClock,
    oversleepContact,
    oversleepShare,
    oversleepTriggerMinutes,
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
          other.snoozeIntervalMinutes == this.snoozeIntervalMinutes &&
          other.snoozeMaxCount == this.snoozeMaxCount &&
          other.soundId == this.soundId &&
          other.kakugoHostage == this.kakugoHostage &&
          other.kakugoRatePerMinute == this.kakugoRatePerMinute &&
          other.kakugoCap == this.kakugoCap &&
          other.kakugoSnoozePenalty == this.kakugoSnoozePenalty &&
          other.kakugoSnoozeResetsClock == this.kakugoSnoozeResetsClock &&
          other.oversleepContact == this.oversleepContact &&
          other.oversleepShare == this.oversleepShare &&
          other.oversleepTriggerMinutes == this.oversleepTriggerMinutes);
}

class AlarmRowsCompanion extends UpdateCompanion<AlarmRow> {
  final Value<String> id;
  final Value<int> hour;
  final Value<int> minute;
  final Value<String> repeatDays;
  final Value<bool> enabled;
  final Value<String> wakeCheck;
  final Value<int> graceMinutes;
  final Value<int?> snoozeIntervalMinutes;
  final Value<int?> snoozeMaxCount;
  final Value<String> soundId;
  final Value<String?> kakugoHostage;
  final Value<int?> kakugoRatePerMinute;
  final Value<int?> kakugoCap;
  final Value<int?> kakugoSnoozePenalty;
  final Value<bool?> kakugoSnoozeResetsClock;
  final Value<String?> oversleepContact;
  final Value<String?> oversleepShare;
  final Value<int?> oversleepTriggerMinutes;
  final Value<int> rowid;
  const AlarmRowsCompanion({
    this.id = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.repeatDays = const Value.absent(),
    this.enabled = const Value.absent(),
    this.wakeCheck = const Value.absent(),
    this.graceMinutes = const Value.absent(),
    this.snoozeIntervalMinutes = const Value.absent(),
    this.snoozeMaxCount = const Value.absent(),
    this.soundId = const Value.absent(),
    this.kakugoHostage = const Value.absent(),
    this.kakugoRatePerMinute = const Value.absent(),
    this.kakugoCap = const Value.absent(),
    this.kakugoSnoozePenalty = const Value.absent(),
    this.kakugoSnoozeResetsClock = const Value.absent(),
    this.oversleepContact = const Value.absent(),
    this.oversleepShare = const Value.absent(),
    this.oversleepTriggerMinutes = const Value.absent(),
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
    this.snoozeIntervalMinutes = const Value.absent(),
    this.snoozeMaxCount = const Value.absent(),
    this.soundId = const Value.absent(),
    this.kakugoHostage = const Value.absent(),
    this.kakugoRatePerMinute = const Value.absent(),
    this.kakugoCap = const Value.absent(),
    this.kakugoSnoozePenalty = const Value.absent(),
    this.kakugoSnoozeResetsClock = const Value.absent(),
    this.oversleepContact = const Value.absent(),
    this.oversleepShare = const Value.absent(),
    this.oversleepTriggerMinutes = const Value.absent(),
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
    Expression<int>? snoozeIntervalMinutes,
    Expression<int>? snoozeMaxCount,
    Expression<String>? soundId,
    Expression<String>? kakugoHostage,
    Expression<int>? kakugoRatePerMinute,
    Expression<int>? kakugoCap,
    Expression<int>? kakugoSnoozePenalty,
    Expression<bool>? kakugoSnoozeResetsClock,
    Expression<String>? oversleepContact,
    Expression<String>? oversleepShare,
    Expression<int>? oversleepTriggerMinutes,
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
      if (snoozeIntervalMinutes != null)
        'snooze_interval_minutes': snoozeIntervalMinutes,
      if (snoozeMaxCount != null) 'snooze_max_count': snoozeMaxCount,
      if (soundId != null) 'sound_id': soundId,
      if (kakugoHostage != null) 'kakugo_hostage': kakugoHostage,
      if (kakugoRatePerMinute != null)
        'kakugo_rate_per_minute': kakugoRatePerMinute,
      if (kakugoCap != null) 'kakugo_cap': kakugoCap,
      if (kakugoSnoozePenalty != null)
        'kakugo_snooze_penalty': kakugoSnoozePenalty,
      if (kakugoSnoozeResetsClock != null)
        'kakugo_snooze_resets_clock': kakugoSnoozeResetsClock,
      if (oversleepContact != null) 'oversleep_contact': oversleepContact,
      if (oversleepShare != null) 'oversleep_share': oversleepShare,
      if (oversleepTriggerMinutes != null)
        'oversleep_trigger_minutes': oversleepTriggerMinutes,
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
    Value<int?>? snoozeIntervalMinutes,
    Value<int?>? snoozeMaxCount,
    Value<String>? soundId,
    Value<String?>? kakugoHostage,
    Value<int?>? kakugoRatePerMinute,
    Value<int?>? kakugoCap,
    Value<int?>? kakugoSnoozePenalty,
    Value<bool?>? kakugoSnoozeResetsClock,
    Value<String?>? oversleepContact,
    Value<String?>? oversleepShare,
    Value<int?>? oversleepTriggerMinutes,
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
      snoozeIntervalMinutes:
          snoozeIntervalMinutes ?? this.snoozeIntervalMinutes,
      snoozeMaxCount: snoozeMaxCount ?? this.snoozeMaxCount,
      soundId: soundId ?? this.soundId,
      kakugoHostage: kakugoHostage ?? this.kakugoHostage,
      kakugoRatePerMinute: kakugoRatePerMinute ?? this.kakugoRatePerMinute,
      kakugoCap: kakugoCap ?? this.kakugoCap,
      kakugoSnoozePenalty: kakugoSnoozePenalty ?? this.kakugoSnoozePenalty,
      kakugoSnoozeResetsClock:
          kakugoSnoozeResetsClock ?? this.kakugoSnoozeResetsClock,
      oversleepContact: oversleepContact ?? this.oversleepContact,
      oversleepShare: oversleepShare ?? this.oversleepShare,
      oversleepTriggerMinutes:
          oversleepTriggerMinutes ?? this.oversleepTriggerMinutes,
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
    if (snoozeIntervalMinutes.present) {
      map['snooze_interval_minutes'] = Variable<int>(
        snoozeIntervalMinutes.value,
      );
    }
    if (snoozeMaxCount.present) {
      map['snooze_max_count'] = Variable<int>(snoozeMaxCount.value);
    }
    if (soundId.present) {
      map['sound_id'] = Variable<String>(soundId.value);
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
    if (kakugoSnoozePenalty.present) {
      map['kakugo_snooze_penalty'] = Variable<int>(kakugoSnoozePenalty.value);
    }
    if (kakugoSnoozeResetsClock.present) {
      map['kakugo_snooze_resets_clock'] = Variable<bool>(
        kakugoSnoozeResetsClock.value,
      );
    }
    if (oversleepContact.present) {
      map['oversleep_contact'] = Variable<String>(oversleepContact.value);
    }
    if (oversleepShare.present) {
      map['oversleep_share'] = Variable<String>(oversleepShare.value);
    }
    if (oversleepTriggerMinutes.present) {
      map['oversleep_trigger_minutes'] = Variable<int>(
        oversleepTriggerMinutes.value,
      );
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
          ..write('snoozeIntervalMinutes: $snoozeIntervalMinutes, ')
          ..write('snoozeMaxCount: $snoozeMaxCount, ')
          ..write('soundId: $soundId, ')
          ..write('kakugoHostage: $kakugoHostage, ')
          ..write('kakugoRatePerMinute: $kakugoRatePerMinute, ')
          ..write('kakugoCap: $kakugoCap, ')
          ..write('kakugoSnoozePenalty: $kakugoSnoozePenalty, ')
          ..write('kakugoSnoozeResetsClock: $kakugoSnoozeResetsClock, ')
          ..write('oversleepContact: $oversleepContact, ')
          ..write('oversleepShare: $oversleepShare, ')
          ..write('oversleepTriggerMinutes: $oversleepTriggerMinutes, ')
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
  static const VerificationMeta _kakugoSnoozePenaltyMeta =
      const VerificationMeta('kakugoSnoozePenalty');
  @override
  late final GeneratedColumn<int> kakugoSnoozePenalty = GeneratedColumn<int>(
    'kakugo_snooze_penalty',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kakugoSnoozeResetsClockMeta =
      const VerificationMeta('kakugoSnoozeResetsClock');
  @override
  late final GeneratedColumn<bool> kakugoSnoozeResetsClock =
      GeneratedColumn<bool>(
        'kakugo_snooze_resets_clock',
        aliasedName,
        true,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("kakugo_snooze_resets_clock" IN (0, 1))',
        ),
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
  static const VerificationMeta _wakeCheckResolvedMeta = const VerificationMeta(
    'wakeCheckResolved',
  );
  @override
  late final GeneratedColumn<String> wakeCheckResolved =
      GeneratedColumn<String>(
        'wake_check_resolved',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _snoozesMeta = const VerificationMeta(
    'snoozes',
  );
  @override
  late final GeneratedColumn<String> snoozes = GeneratedColumn<String>(
    'snoozes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentRingAtMsMeta = const VerificationMeta(
    'currentRingAtMs',
  );
  @override
  late final GeneratedColumn<int> currentRingAtMs = GeneratedColumn<int>(
    'current_ring_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
    kakugoSnoozePenalty,
    kakugoSnoozeResetsClock,
    coinsAtFire,
    graceMinutes,
    wakeCheckResolved,
    snoozes,
    currentRingAtMs,
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
    if (data.containsKey('kakugo_snooze_penalty')) {
      context.handle(
        _kakugoSnoozePenaltyMeta,
        kakugoSnoozePenalty.isAcceptableOrUnknown(
          data['kakugo_snooze_penalty']!,
          _kakugoSnoozePenaltyMeta,
        ),
      );
    }
    if (data.containsKey('kakugo_snooze_resets_clock')) {
      context.handle(
        _kakugoSnoozeResetsClockMeta,
        kakugoSnoozeResetsClock.isAcceptableOrUnknown(
          data['kakugo_snooze_resets_clock']!,
          _kakugoSnoozeResetsClockMeta,
        ),
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
    if (data.containsKey('wake_check_resolved')) {
      context.handle(
        _wakeCheckResolvedMeta,
        wakeCheckResolved.isAcceptableOrUnknown(
          data['wake_check_resolved']!,
          _wakeCheckResolvedMeta,
        ),
      );
    }
    if (data.containsKey('snoozes')) {
      context.handle(
        _snoozesMeta,
        snoozes.isAcceptableOrUnknown(data['snoozes']!, _snoozesMeta),
      );
    }
    if (data.containsKey('current_ring_at_ms')) {
      context.handle(
        _currentRingAtMsMeta,
        currentRingAtMs.isAcceptableOrUnknown(
          data['current_ring_at_ms']!,
          _currentRingAtMsMeta,
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
      kakugoSnoozePenalty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kakugo_snooze_penalty'],
      ),
      kakugoSnoozeResetsClock: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}kakugo_snooze_resets_clock'],
      ),
      coinsAtFire: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coins_at_fire'],
      )!,
      graceMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grace_minutes'],
      )!,
      wakeCheckResolved: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wake_check_resolved'],
      ),
      snoozes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snoozes'],
      ),
      currentRingAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_ring_at_ms'],
      ),
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

  /// The other half of the frozen pledge, added in v5. v4 stored these two on
  /// the alarm but not on the session, so a snapshot could not carry them; a
  /// row written before v5 reads back as "snoozing is free and never stops the
  /// clock", which is the rule it was written under.
  final int? kakugoSnoozePenalty;
  final bool? kakugoSnoozeResetsClock;
  final int coinsAtFire;

  /// The grace window frozen at fire time, alongside the pledge and balance.
  final int graceMinutes;

  /// The wake check drawn for this ring, set only when the alarm asked for a
  /// random one. Stored so a relaunch mid-ring cannot re-roll it.
  final String? wakeCheckResolved;

  /// Stage B: the times the user pressed snooze (JSON list of epoch millis)
  /// and the start of the current ring. Added in v4 so stage B needs no
  /// migration; nothing reads them yet.
  final String? snoozes;
  final int? currentRingAtMs;
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
    this.kakugoSnoozePenalty,
    this.kakugoSnoozeResetsClock,
    required this.coinsAtFire,
    required this.graceMinutes,
    this.wakeCheckResolved,
    this.snoozes,
    this.currentRingAtMs,
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
    if (!nullToAbsent || kakugoSnoozePenalty != null) {
      map['kakugo_snooze_penalty'] = Variable<int>(kakugoSnoozePenalty);
    }
    if (!nullToAbsent || kakugoSnoozeResetsClock != null) {
      map['kakugo_snooze_resets_clock'] = Variable<bool>(
        kakugoSnoozeResetsClock,
      );
    }
    map['coins_at_fire'] = Variable<int>(coinsAtFire);
    map['grace_minutes'] = Variable<int>(graceMinutes);
    if (!nullToAbsent || wakeCheckResolved != null) {
      map['wake_check_resolved'] = Variable<String>(wakeCheckResolved);
    }
    if (!nullToAbsent || snoozes != null) {
      map['snoozes'] = Variable<String>(snoozes);
    }
    if (!nullToAbsent || currentRingAtMs != null) {
      map['current_ring_at_ms'] = Variable<int>(currentRingAtMs);
    }
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
      kakugoSnoozePenalty: kakugoSnoozePenalty == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoSnoozePenalty),
      kakugoSnoozeResetsClock: kakugoSnoozeResetsClock == null && nullToAbsent
          ? const Value.absent()
          : Value(kakugoSnoozeResetsClock),
      coinsAtFire: Value(coinsAtFire),
      graceMinutes: Value(graceMinutes),
      wakeCheckResolved: wakeCheckResolved == null && nullToAbsent
          ? const Value.absent()
          : Value(wakeCheckResolved),
      snoozes: snoozes == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozes),
      currentRingAtMs: currentRingAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(currentRingAtMs),
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
      kakugoSnoozePenalty: serializer.fromJson<int?>(
        json['kakugoSnoozePenalty'],
      ),
      kakugoSnoozeResetsClock: serializer.fromJson<bool?>(
        json['kakugoSnoozeResetsClock'],
      ),
      coinsAtFire: serializer.fromJson<int>(json['coinsAtFire']),
      graceMinutes: serializer.fromJson<int>(json['graceMinutes']),
      wakeCheckResolved: serializer.fromJson<String?>(
        json['wakeCheckResolved'],
      ),
      snoozes: serializer.fromJson<String?>(json['snoozes']),
      currentRingAtMs: serializer.fromJson<int?>(json['currentRingAtMs']),
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
      'kakugoSnoozePenalty': serializer.toJson<int?>(kakugoSnoozePenalty),
      'kakugoSnoozeResetsClock': serializer.toJson<bool?>(
        kakugoSnoozeResetsClock,
      ),
      'coinsAtFire': serializer.toJson<int>(coinsAtFire),
      'graceMinutes': serializer.toJson<int>(graceMinutes),
      'wakeCheckResolved': serializer.toJson<String?>(wakeCheckResolved),
      'snoozes': serializer.toJson<String?>(snoozes),
      'currentRingAtMs': serializer.toJson<int?>(currentRingAtMs),
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
    Value<int?> kakugoSnoozePenalty = const Value.absent(),
    Value<bool?> kakugoSnoozeResetsClock = const Value.absent(),
    int? coinsAtFire,
    int? graceMinutes,
    Value<String?> wakeCheckResolved = const Value.absent(),
    Value<String?> snoozes = const Value.absent(),
    Value<int?> currentRingAtMs = const Value.absent(),
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
    kakugoSnoozePenalty: kakugoSnoozePenalty.present
        ? kakugoSnoozePenalty.value
        : this.kakugoSnoozePenalty,
    kakugoSnoozeResetsClock: kakugoSnoozeResetsClock.present
        ? kakugoSnoozeResetsClock.value
        : this.kakugoSnoozeResetsClock,
    coinsAtFire: coinsAtFire ?? this.coinsAtFire,
    graceMinutes: graceMinutes ?? this.graceMinutes,
    wakeCheckResolved: wakeCheckResolved.present
        ? wakeCheckResolved.value
        : this.wakeCheckResolved,
    snoozes: snoozes.present ? snoozes.value : this.snoozes,
    currentRingAtMs: currentRingAtMs.present
        ? currentRingAtMs.value
        : this.currentRingAtMs,
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
      kakugoSnoozePenalty: data.kakugoSnoozePenalty.present
          ? data.kakugoSnoozePenalty.value
          : this.kakugoSnoozePenalty,
      kakugoSnoozeResetsClock: data.kakugoSnoozeResetsClock.present
          ? data.kakugoSnoozeResetsClock.value
          : this.kakugoSnoozeResetsClock,
      coinsAtFire: data.coinsAtFire.present
          ? data.coinsAtFire.value
          : this.coinsAtFire,
      graceMinutes: data.graceMinutes.present
          ? data.graceMinutes.value
          : this.graceMinutes,
      wakeCheckResolved: data.wakeCheckResolved.present
          ? data.wakeCheckResolved.value
          : this.wakeCheckResolved,
      snoozes: data.snoozes.present ? data.snoozes.value : this.snoozes,
      currentRingAtMs: data.currentRingAtMs.present
          ? data.currentRingAtMs.value
          : this.currentRingAtMs,
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
          ..write('kakugoSnoozePenalty: $kakugoSnoozePenalty, ')
          ..write('kakugoSnoozeResetsClock: $kakugoSnoozeResetsClock, ')
          ..write('coinsAtFire: $coinsAtFire, ')
          ..write('graceMinutes: $graceMinutes, ')
          ..write('wakeCheckResolved: $wakeCheckResolved, ')
          ..write('snoozes: $snoozes, ')
          ..write('currentRingAtMs: $currentRingAtMs')
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
    kakugoSnoozePenalty,
    kakugoSnoozeResetsClock,
    coinsAtFire,
    graceMinutes,
    wakeCheckResolved,
    snoozes,
    currentRingAtMs,
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
          other.kakugoSnoozePenalty == this.kakugoSnoozePenalty &&
          other.kakugoSnoozeResetsClock == this.kakugoSnoozeResetsClock &&
          other.coinsAtFire == this.coinsAtFire &&
          other.graceMinutes == this.graceMinutes &&
          other.wakeCheckResolved == this.wakeCheckResolved &&
          other.snoozes == this.snoozes &&
          other.currentRingAtMs == this.currentRingAtMs);
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
  final Value<int?> kakugoSnoozePenalty;
  final Value<bool?> kakugoSnoozeResetsClock;
  final Value<int> coinsAtFire;
  final Value<int> graceMinutes;
  final Value<String?> wakeCheckResolved;
  final Value<String?> snoozes;
  final Value<int?> currentRingAtMs;
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
    this.kakugoSnoozePenalty = const Value.absent(),
    this.kakugoSnoozeResetsClock = const Value.absent(),
    this.coinsAtFire = const Value.absent(),
    this.graceMinutes = const Value.absent(),
    this.wakeCheckResolved = const Value.absent(),
    this.snoozes = const Value.absent(),
    this.currentRingAtMs = const Value.absent(),
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
    this.kakugoSnoozePenalty = const Value.absent(),
    this.kakugoSnoozeResetsClock = const Value.absent(),
    this.coinsAtFire = const Value.absent(),
    this.graceMinutes = const Value.absent(),
    this.wakeCheckResolved = const Value.absent(),
    this.snoozes = const Value.absent(),
    this.currentRingAtMs = const Value.absent(),
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
    Expression<int>? kakugoSnoozePenalty,
    Expression<bool>? kakugoSnoozeResetsClock,
    Expression<int>? coinsAtFire,
    Expression<int>? graceMinutes,
    Expression<String>? wakeCheckResolved,
    Expression<String>? snoozes,
    Expression<int>? currentRingAtMs,
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
      if (kakugoSnoozePenalty != null)
        'kakugo_snooze_penalty': kakugoSnoozePenalty,
      if (kakugoSnoozeResetsClock != null)
        'kakugo_snooze_resets_clock': kakugoSnoozeResetsClock,
      if (coinsAtFire != null) 'coins_at_fire': coinsAtFire,
      if (graceMinutes != null) 'grace_minutes': graceMinutes,
      if (wakeCheckResolved != null) 'wake_check_resolved': wakeCheckResolved,
      if (snoozes != null) 'snoozes': snoozes,
      if (currentRingAtMs != null) 'current_ring_at_ms': currentRingAtMs,
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
    Value<int?>? kakugoSnoozePenalty,
    Value<bool?>? kakugoSnoozeResetsClock,
    Value<int>? coinsAtFire,
    Value<int>? graceMinutes,
    Value<String?>? wakeCheckResolved,
    Value<String?>? snoozes,
    Value<int?>? currentRingAtMs,
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
      kakugoSnoozePenalty: kakugoSnoozePenalty ?? this.kakugoSnoozePenalty,
      kakugoSnoozeResetsClock:
          kakugoSnoozeResetsClock ?? this.kakugoSnoozeResetsClock,
      coinsAtFire: coinsAtFire ?? this.coinsAtFire,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      wakeCheckResolved: wakeCheckResolved ?? this.wakeCheckResolved,
      snoozes: snoozes ?? this.snoozes,
      currentRingAtMs: currentRingAtMs ?? this.currentRingAtMs,
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
    if (kakugoSnoozePenalty.present) {
      map['kakugo_snooze_penalty'] = Variable<int>(kakugoSnoozePenalty.value);
    }
    if (kakugoSnoozeResetsClock.present) {
      map['kakugo_snooze_resets_clock'] = Variable<bool>(
        kakugoSnoozeResetsClock.value,
      );
    }
    if (coinsAtFire.present) {
      map['coins_at_fire'] = Variable<int>(coinsAtFire.value);
    }
    if (graceMinutes.present) {
      map['grace_minutes'] = Variable<int>(graceMinutes.value);
    }
    if (wakeCheckResolved.present) {
      map['wake_check_resolved'] = Variable<String>(wakeCheckResolved.value);
    }
    if (snoozes.present) {
      map['snoozes'] = Variable<String>(snoozes.value);
    }
    if (currentRingAtMs.present) {
      map['current_ring_at_ms'] = Variable<int>(currentRingAtMs.value);
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
          ..write('kakugoSnoozePenalty: $kakugoSnoozePenalty, ')
          ..write('kakugoSnoozeResetsClock: $kakugoSnoozeResetsClock, ')
          ..write('coinsAtFire: $coinsAtFire, ')
          ..write('graceMinutes: $graceMinutes, ')
          ..write('wakeCheckResolved: $wakeCheckResolved, ')
          ..write('snoozes: $snoozes, ')
          ..write('currentRingAtMs: $currentRingAtMs, ')
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

class $GardenPlacementRowsTable extends GardenPlacementRows
    with TableInfo<$GardenPlacementRowsTable, GardenPlacementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GardenPlacementRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<int> x = GeneratedColumn<int>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<int> y = GeneratedColumn<int>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placedAtMsMeta = const VerificationMeta(
    'placedAtMs',
  );
  @override
  late final GeneratedColumn<int> placedAtMs = GeneratedColumn<int>(
    'placed_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _growthStageMeta = const VerificationMeta(
    'growthStage',
  );
  @override
  late final GeneratedColumn<int> growthStage = GeneratedColumn<int>(
    'growth_stage',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    x,
    y,
    placedAtMs,
    growthStage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'garden_placement_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<GardenPlacementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('placed_at_ms')) {
      context.handle(
        _placedAtMsMeta,
        placedAtMs.isAcceptableOrUnknown(
          data['placed_at_ms']!,
          _placedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_placedAtMsMeta);
    }
    if (data.containsKey('growth_stage')) {
      context.handle(
        _growthStageMeta,
        growthStage.isAcceptableOrUnknown(
          data['growth_stage']!,
          _growthStageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GardenPlacementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GardenPlacementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}y'],
      )!,
      placedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}placed_at_ms'],
      )!,
      growthStage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}growth_stage'],
      )!,
    );
  }

  @override
  $GardenPlacementRowsTable createAlias(String alias) {
    return $GardenPlacementRowsTable(attachedDatabase, alias);
  }
}

class GardenPlacementRow extends DataClass
    implements Insertable<GardenPlacementRow> {
  final String id;

  /// Catalogue id. Definitions live in code, so nothing here has to migrate
  /// when an item is renamed or repriced.
  final String itemId;
  final int x;
  final int y;
  final int placedAtMs;

  /// Cached growth stage. Recomputed from session history on every read; kept
  /// here only so the garden can paint before history arrives.
  final int growthStage;
  const GardenPlacementRow({
    required this.id,
    required this.itemId,
    required this.x,
    required this.y,
    required this.placedAtMs,
    required this.growthStage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['x'] = Variable<int>(x);
    map['y'] = Variable<int>(y);
    map['placed_at_ms'] = Variable<int>(placedAtMs);
    map['growth_stage'] = Variable<int>(growthStage);
    return map;
  }

  GardenPlacementRowsCompanion toCompanion(bool nullToAbsent) {
    return GardenPlacementRowsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      x: Value(x),
      y: Value(y),
      placedAtMs: Value(placedAtMs),
      growthStage: Value(growthStage),
    );
  }

  factory GardenPlacementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GardenPlacementRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      x: serializer.fromJson<int>(json['x']),
      y: serializer.fromJson<int>(json['y']),
      placedAtMs: serializer.fromJson<int>(json['placedAtMs']),
      growthStage: serializer.fromJson<int>(json['growthStage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'x': serializer.toJson<int>(x),
      'y': serializer.toJson<int>(y),
      'placedAtMs': serializer.toJson<int>(placedAtMs),
      'growthStage': serializer.toJson<int>(growthStage),
    };
  }

  GardenPlacementRow copyWith({
    String? id,
    String? itemId,
    int? x,
    int? y,
    int? placedAtMs,
    int? growthStage,
  }) => GardenPlacementRow(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    x: x ?? this.x,
    y: y ?? this.y,
    placedAtMs: placedAtMs ?? this.placedAtMs,
    growthStage: growthStage ?? this.growthStage,
  );
  GardenPlacementRow copyWithCompanion(GardenPlacementRowsCompanion data) {
    return GardenPlacementRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      placedAtMs: data.placedAtMs.present
          ? data.placedAtMs.value
          : this.placedAtMs,
      growthStage: data.growthStage.present
          ? data.growthStage.value
          : this.growthStage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GardenPlacementRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('placedAtMs: $placedAtMs, ')
          ..write('growthStage: $growthStage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, x, y, placedAtMs, growthStage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GardenPlacementRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.x == this.x &&
          other.y == this.y &&
          other.placedAtMs == this.placedAtMs &&
          other.growthStage == this.growthStage);
}

class GardenPlacementRowsCompanion extends UpdateCompanion<GardenPlacementRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<int> x;
  final Value<int> y;
  final Value<int> placedAtMs;
  final Value<int> growthStage;
  final Value<int> rowid;
  const GardenPlacementRowsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.placedAtMs = const Value.absent(),
    this.growthStage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GardenPlacementRowsCompanion.insert({
    required String id,
    required String itemId,
    required int x,
    required int y,
    required int placedAtMs,
    this.growthStage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       x = Value(x),
       y = Value(y),
       placedAtMs = Value(placedAtMs);
  static Insertable<GardenPlacementRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<int>? x,
    Expression<int>? y,
    Expression<int>? placedAtMs,
    Expression<int>? growthStage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (placedAtMs != null) 'placed_at_ms': placedAtMs,
      if (growthStage != null) 'growth_stage': growthStage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GardenPlacementRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<int>? x,
    Value<int>? y,
    Value<int>? placedAtMs,
    Value<int>? growthStage,
    Value<int>? rowid,
  }) {
    return GardenPlacementRowsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      x: x ?? this.x,
      y: y ?? this.y,
      placedAtMs: placedAtMs ?? this.placedAtMs,
      growthStage: growthStage ?? this.growthStage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (x.present) {
      map['x'] = Variable<int>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<int>(y.value);
    }
    if (placedAtMs.present) {
      map['placed_at_ms'] = Variable<int>(placedAtMs.value);
    }
    if (growthStage.present) {
      map['growth_stage'] = Variable<int>(growthStage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GardenPlacementRowsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('placedAtMs: $placedAtMs, ')
          ..write('growthStage: $growthStage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GardenInventoryRowsTable extends GardenInventoryRows
    with TableInfo<$GardenInventoryRowsTable, GardenInventoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GardenInventoryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'garden_inventory_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<GardenInventoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  GardenInventoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GardenInventoryRow(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $GardenInventoryRowsTable createAlias(String alias) {
    return $GardenInventoryRowsTable(attachedDatabase, alias);
  }
}

class GardenInventoryRow extends DataClass
    implements Insertable<GardenInventoryRow> {
  final String itemId;
  final int count;
  const GardenInventoryRow({required this.itemId, required this.count});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['count'] = Variable<int>(count);
    return map;
  }

  GardenInventoryRowsCompanion toCompanion(bool nullToAbsent) {
    return GardenInventoryRowsCompanion(
      itemId: Value(itemId),
      count: Value(count),
    );
  }

  factory GardenInventoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GardenInventoryRow(
      itemId: serializer.fromJson<String>(json['itemId']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'count': serializer.toJson<int>(count),
    };
  }

  GardenInventoryRow copyWith({String? itemId, int? count}) =>
      GardenInventoryRow(
        itemId: itemId ?? this.itemId,
        count: count ?? this.count,
      );
  GardenInventoryRow copyWithCompanion(GardenInventoryRowsCompanion data) {
    return GardenInventoryRow(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GardenInventoryRow(')
          ..write('itemId: $itemId, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GardenInventoryRow &&
          other.itemId == this.itemId &&
          other.count == this.count);
}

class GardenInventoryRowsCompanion extends UpdateCompanion<GardenInventoryRow> {
  final Value<String> itemId;
  final Value<int> count;
  final Value<int> rowid;
  const GardenInventoryRowsCompanion({
    this.itemId = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GardenInventoryRowsCompanion.insert({
    required String itemId,
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId);
  static Insertable<GardenInventoryRow> custom({
    Expression<String>? itemId,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GardenInventoryRowsCompanion copyWith({
    Value<String>? itemId,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return GardenInventoryRowsCompanion(
      itemId: itemId ?? this.itemId,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GardenInventoryRowsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactEventRowsTable extends ContactEventRows
    with TableInfo<$ContactEventRowsTable, ContactEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactEventRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
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
  static const VerificationMeta _contactNameMeta = const VerificationMeta(
    'contactName',
  );
  @override
  late final GeneratedColumn<String> contactName = GeneratedColumn<String>(
    'contact_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    firedAtMs,
    contactName,
    channel,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contact_event_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContactEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('fired_at_ms')) {
      context.handle(
        _firedAtMsMeta,
        firedAtMs.isAcceptableOrUnknown(data['fired_at_ms']!, _firedAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_firedAtMsMeta);
    }
    if (data.containsKey('contact_name')) {
      context.handle(
        _contactNameMeta,
        contactName.isAcceptableOrUnknown(
          data['contact_name']!,
          _contactNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contactNameMeta);
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    } else if (isInserting) {
      context.missing(_channelMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContactEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      firedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fired_at_ms'],
      )!,
      contactName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_name'],
      )!,
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
    );
  }

  @override
  $ContactEventRowsTable createAlias(String alias) {
    return $ContactEventRowsTable(attachedDatabase, alias);
  }
}

class ContactEventRow extends DataClass implements Insertable<ContactEventRow> {
  final String id;
  final String sessionId;
  final int firedAtMs;
  final String contactName;
  final String channel;
  final String? detail;
  const ContactEventRow({
    required this.id,
    required this.sessionId,
    required this.firedAtMs,
    required this.contactName,
    required this.channel,
    this.detail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['fired_at_ms'] = Variable<int>(firedAtMs);
    map['contact_name'] = Variable<String>(contactName);
    map['channel'] = Variable<String>(channel);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    return map;
  }

  ContactEventRowsCompanion toCompanion(bool nullToAbsent) {
    return ContactEventRowsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      firedAtMs: Value(firedAtMs),
      contactName: Value(contactName),
      channel: Value(channel),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
    );
  }

  factory ContactEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactEventRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      firedAtMs: serializer.fromJson<int>(json['firedAtMs']),
      contactName: serializer.fromJson<String>(json['contactName']),
      channel: serializer.fromJson<String>(json['channel']),
      detail: serializer.fromJson<String?>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'firedAtMs': serializer.toJson<int>(firedAtMs),
      'contactName': serializer.toJson<String>(contactName),
      'channel': serializer.toJson<String>(channel),
      'detail': serializer.toJson<String?>(detail),
    };
  }

  ContactEventRow copyWith({
    String? id,
    String? sessionId,
    int? firedAtMs,
    String? contactName,
    String? channel,
    Value<String?> detail = const Value.absent(),
  }) => ContactEventRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    firedAtMs: firedAtMs ?? this.firedAtMs,
    contactName: contactName ?? this.contactName,
    channel: channel ?? this.channel,
    detail: detail.present ? detail.value : this.detail,
  );
  ContactEventRow copyWithCompanion(ContactEventRowsCompanion data) {
    return ContactEventRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      firedAtMs: data.firedAtMs.present ? data.firedAtMs.value : this.firedAtMs,
      contactName: data.contactName.present
          ? data.contactName.value
          : this.contactName,
      channel: data.channel.present ? data.channel.value : this.channel,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContactEventRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('firedAtMs: $firedAtMs, ')
          ..write('contactName: $contactName, ')
          ..write('channel: $channel, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, firedAtMs, contactName, channel, detail);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactEventRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.firedAtMs == this.firedAtMs &&
          other.contactName == this.contactName &&
          other.channel == this.channel &&
          other.detail == this.detail);
}

class ContactEventRowsCompanion extends UpdateCompanion<ContactEventRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> firedAtMs;
  final Value<String> contactName;
  final Value<String> channel;
  final Value<String?> detail;
  final Value<int> rowid;
  const ContactEventRowsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.firedAtMs = const Value.absent(),
    this.contactName = const Value.absent(),
    this.channel = const Value.absent(),
    this.detail = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactEventRowsCompanion.insert({
    required String id,
    required String sessionId,
    required int firedAtMs,
    required String contactName,
    required String channel,
    this.detail = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       firedAtMs = Value(firedAtMs),
       contactName = Value(contactName),
       channel = Value(channel);
  static Insertable<ContactEventRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? firedAtMs,
    Expression<String>? contactName,
    Expression<String>? channel,
    Expression<String>? detail,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (firedAtMs != null) 'fired_at_ms': firedAtMs,
      if (contactName != null) 'contact_name': contactName,
      if (channel != null) 'channel': channel,
      if (detail != null) 'detail': detail,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactEventRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? firedAtMs,
    Value<String>? contactName,
    Value<String>? channel,
    Value<String?>? detail,
    Value<int>? rowid,
  }) {
    return ContactEventRowsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      firedAtMs: firedAtMs ?? this.firedAtMs,
      contactName: contactName ?? this.contactName,
      channel: channel ?? this.channel,
      detail: detail ?? this.detail,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (firedAtMs.present) {
      map['fired_at_ms'] = Variable<int>(firedAtMs.value);
    }
    if (contactName.present) {
      map['contact_name'] = Variable<String>(contactName.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactEventRowsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('firedAtMs: $firedAtMs, ')
          ..write('contactName: $contactName, ')
          ..write('channel: $channel, ')
          ..write('detail: $detail, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactBookRowsTable extends ContactBookRows
    with TableInfo<$ContactBookRowsTable, ContactBookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactBookRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingMeta = const VerificationMeta(
    'reading',
  );
  @override
  late final GeneratedColumn<String> reading = GeneratedColumn<String>(
    'reading',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    reading,
    phone,
    email,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contact_book_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContactBookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('reading')) {
      context.handle(
        _readingMeta,
        reading.isAcceptableOrUnknown(data['reading']!, _readingMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContactBookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactBookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      reading: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $ContactBookRowsTable createAlias(String alias) {
    return $ContactBookRowsTable(attachedDatabase, alias);
  }
}

class ContactBookRow extends DataClass implements Insertable<ContactBookRow> {
  final String id;
  final String name;

  /// よみがな. Sorting only; never displayed as the name, never sent.
  final String? reading;
  final String? phone;
  final String? email;
  final int createdAtMs;
  const ContactBookRow({
    required this.id,
    required this.name,
    this.reading,
    this.phone,
    this.email,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || reading != null) {
      map['reading'] = Variable<String>(reading);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  ContactBookRowsCompanion toCompanion(bool nullToAbsent) {
    return ContactBookRowsCompanion(
      id: Value(id),
      name: Value(name),
      reading: reading == null && nullToAbsent
          ? const Value.absent()
          : Value(reading),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory ContactBookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactBookRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      reading: serializer.fromJson<String?>(json['reading']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'reading': serializer.toJson<String?>(reading),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  ContactBookRow copyWith({
    String? id,
    String? name,
    Value<String?> reading = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> email = const Value.absent(),
    int? createdAtMs,
  }) => ContactBookRow(
    id: id ?? this.id,
    name: name ?? this.name,
    reading: reading.present ? reading.value : this.reading,
    phone: phone.present ? phone.value : this.phone,
    email: email.present ? email.value : this.email,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  ContactBookRow copyWithCompanion(ContactBookRowsCompanion data) {
    return ContactBookRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      reading: data.reading.present ? data.reading.value : this.reading,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContactBookRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('reading: $reading, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, reading, phone, email, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactBookRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.reading == this.reading &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.createdAtMs == this.createdAtMs);
}

class ContactBookRowsCompanion extends UpdateCompanion<ContactBookRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> reading;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const ContactBookRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.reading = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactBookRowsCompanion.insert({
    required String id,
    required String name,
    this.reading = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    required int createdAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAtMs = Value(createdAtMs);
  static Insertable<ContactBookRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? reading,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (reading != null) 'reading': reading,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactBookRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? reading,
    Value<String?>? phone,
    Value<String?>? email,
    Value<int>? createdAtMs,
    Value<int>? rowid,
  }) {
    return ContactBookRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      reading: reading ?? this.reading,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (reading.present) {
      map['reading'] = Variable<String>(reading.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactBookRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('reading: $reading, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiscordWebhookRowsTable extends DiscordWebhookRows
    with TableInfo<$DiscordWebhookRowsTable, DiscordWebhookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiscordWebhookRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, url, displayName, createdAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discord_webhook_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiscordWebhookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiscordWebhookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiscordWebhookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $DiscordWebhookRowsTable createAlias(String alias) {
    return $DiscordWebhookRowsTable(attachedDatabase, alias);
  }
}

class DiscordWebhookRow extends DataClass
    implements Insertable<DiscordWebhookRow> {
  final String id;

  /// The full webhook URL including its token. Never leaves the device except
  /// to Discord.
  final String url;

  /// Typed by hand: Discord does not expose the server or channel name through
  /// a webhook, so this is whatever the user calls it.
  final String displayName;
  final int createdAtMs;
  const DiscordWebhookRow({
    required this.id,
    required this.url,
    required this.displayName,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['url'] = Variable<String>(url);
    map['display_name'] = Variable<String>(displayName);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  DiscordWebhookRowsCompanion toCompanion(bool nullToAbsent) {
    return DiscordWebhookRowsCompanion(
      id: Value(id),
      url: Value(url),
      displayName: Value(displayName),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory DiscordWebhookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiscordWebhookRow(
      id: serializer.fromJson<String>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      displayName: serializer.fromJson<String>(json['displayName']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'url': serializer.toJson<String>(url),
      'displayName': serializer.toJson<String>(displayName),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  DiscordWebhookRow copyWith({
    String? id,
    String? url,
    String? displayName,
    int? createdAtMs,
  }) => DiscordWebhookRow(
    id: id ?? this.id,
    url: url ?? this.url,
    displayName: displayName ?? this.displayName,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  DiscordWebhookRow copyWithCompanion(DiscordWebhookRowsCompanion data) {
    return DiscordWebhookRow(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiscordWebhookRow(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('displayName: $displayName, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, url, displayName, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscordWebhookRow &&
          other.id == this.id &&
          other.url == this.url &&
          other.displayName == this.displayName &&
          other.createdAtMs == this.createdAtMs);
}

class DiscordWebhookRowsCompanion extends UpdateCompanion<DiscordWebhookRow> {
  final Value<String> id;
  final Value<String> url;
  final Value<String> displayName;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const DiscordWebhookRowsCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.displayName = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiscordWebhookRowsCompanion.insert({
    required String id,
    required String url,
    required String displayName,
    required int createdAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       url = Value(url),
       displayName = Value(displayName),
       createdAtMs = Value(createdAtMs);
  static Insertable<DiscordWebhookRow> custom({
    Expression<String>? id,
    Expression<String>? url,
    Expression<String>? displayName,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (displayName != null) 'display_name': displayName,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiscordWebhookRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? url,
    Value<String>? displayName,
    Value<int>? createdAtMs,
    Value<int>? rowid,
  }) {
    return DiscordWebhookRowsCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      displayName: displayName ?? this.displayName,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscordWebhookRowsCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('displayName: $displayName, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
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
  late final $GardenPlacementRowsTable gardenPlacementRows =
      $GardenPlacementRowsTable(this);
  late final $GardenInventoryRowsTable gardenInventoryRows =
      $GardenInventoryRowsTable(this);
  late final $ContactEventRowsTable contactEventRows = $ContactEventRowsTable(
    this,
  );
  late final $ContactBookRowsTable contactBookRows = $ContactBookRowsTable(
    this,
  );
  late final $DiscordWebhookRowsTable discordWebhookRows =
      $DiscordWebhookRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    alarmRows,
    alarmSessionRows,
    walletRows,
    ojisanRows,
    gardenPlacementRows,
    gardenInventoryRows,
    contactEventRows,
    contactBookRows,
    discordWebhookRows,
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
  Value<int?> snoozeIntervalMinutes,
  Value<int?> snoozeMaxCount,
  Value<String> soundId,
  Value<String?> kakugoHostage,
  Value<int?> kakugoRatePerMinute,
  Value<int?> kakugoCap,
  Value<int?> kakugoSnoozePenalty,
  Value<bool?> kakugoSnoozeResetsClock,
  Value<String?> oversleepContact,
  Value<String?> oversleepShare,
  Value<int?> oversleepTriggerMinutes,
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
  Value<int?> snoozeIntervalMinutes,
  Value<int?> snoozeMaxCount,
  Value<String> soundId,
  Value<String?> kakugoHostage,
  Value<int?> kakugoRatePerMinute,
  Value<int?> kakugoCap,
  Value<int?> kakugoSnoozePenalty,
  Value<bool?> kakugoSnoozeResetsClock,
  Value<String?> oversleepContact,
  Value<String?> oversleepShare,
  Value<int?> oversleepTriggerMinutes,
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

  ColumnFilters<int> get snoozeIntervalMinutes => $composableBuilder(
    column: $table.snoozeIntervalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeMaxCount => $composableBuilder(
    column: $table.snoozeMaxCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get soundId => $composableBuilder(
    column: $table.soundId,
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

  ColumnFilters<int> get kakugoSnoozePenalty => $composableBuilder(
    column: $table.kakugoSnoozePenalty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get kakugoSnoozeResetsClock => $composableBuilder(
    column: $table.kakugoSnoozeResetsClock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oversleepContact => $composableBuilder(
    column: $table.oversleepContact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oversleepShare => $composableBuilder(
    column: $table.oversleepShare,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get oversleepTriggerMinutes => $composableBuilder(
    column: $table.oversleepTriggerMinutes,
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

  ColumnOrderings<int> get snoozeIntervalMinutes => $composableBuilder(
    column: $table.snoozeIntervalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeMaxCount => $composableBuilder(
    column: $table.snoozeMaxCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get soundId => $composableBuilder(
    column: $table.soundId,
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

  ColumnOrderings<int> get kakugoSnoozePenalty => $composableBuilder(
    column: $table.kakugoSnoozePenalty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get kakugoSnoozeResetsClock => $composableBuilder(
    column: $table.kakugoSnoozeResetsClock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oversleepContact => $composableBuilder(
    column: $table.oversleepContact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oversleepShare => $composableBuilder(
    column: $table.oversleepShare,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get oversleepTriggerMinutes => $composableBuilder(
    column: $table.oversleepTriggerMinutes,
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

  GeneratedColumn<int> get snoozeIntervalMinutes => $composableBuilder(
    column: $table.snoozeIntervalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozeMaxCount => $composableBuilder(
    column: $table.snoozeMaxCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get soundId =>
      $composableBuilder(column: $table.soundId, builder: (column) => column);

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

  GeneratedColumn<int> get kakugoSnoozePenalty => $composableBuilder(
    column: $table.kakugoSnoozePenalty,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get kakugoSnoozeResetsClock => $composableBuilder(
    column: $table.kakugoSnoozeResetsClock,
    builder: (column) => column,
  );

  GeneratedColumn<String> get oversleepContact => $composableBuilder(
    column: $table.oversleepContact,
    builder: (column) => column,
  );

  GeneratedColumn<String> get oversleepShare => $composableBuilder(
    column: $table.oversleepShare,
    builder: (column) => column,
  );

  GeneratedColumn<int> get oversleepTriggerMinutes => $composableBuilder(
    column: $table.oversleepTriggerMinutes,
    builder: (column) => column,
  );
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
                Value<int?> snoozeIntervalMinutes = const Value.absent(),
                Value<int?> snoozeMaxCount = const Value.absent(),
                Value<String> soundId = const Value.absent(),
                Value<String?> kakugoHostage = const Value.absent(),
                Value<int?> kakugoRatePerMinute = const Value.absent(),
                Value<int?> kakugoCap = const Value.absent(),
                Value<int?> kakugoSnoozePenalty = const Value.absent(),
                Value<bool?> kakugoSnoozeResetsClock = const Value.absent(),
                Value<String?> oversleepContact = const Value.absent(),
                Value<String?> oversleepShare = const Value.absent(),
                Value<int?> oversleepTriggerMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmRowsCompanion(
                id: id,
                hour: hour,
                minute: minute,
                repeatDays: repeatDays,
                enabled: enabled,
                wakeCheck: wakeCheck,
                graceMinutes: graceMinutes,
                snoozeIntervalMinutes: snoozeIntervalMinutes,
                snoozeMaxCount: snoozeMaxCount,
                soundId: soundId,
                kakugoHostage: kakugoHostage,
                kakugoRatePerMinute: kakugoRatePerMinute,
                kakugoCap: kakugoCap,
                kakugoSnoozePenalty: kakugoSnoozePenalty,
                kakugoSnoozeResetsClock: kakugoSnoozeResetsClock,
                oversleepContact: oversleepContact,
                oversleepShare: oversleepShare,
                oversleepTriggerMinutes: oversleepTriggerMinutes,
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
                Value<int?> snoozeIntervalMinutes = const Value.absent(),
                Value<int?> snoozeMaxCount = const Value.absent(),
                Value<String> soundId = const Value.absent(),
                Value<String?> kakugoHostage = const Value.absent(),
                Value<int?> kakugoRatePerMinute = const Value.absent(),
                Value<int?> kakugoCap = const Value.absent(),
                Value<int?> kakugoSnoozePenalty = const Value.absent(),
                Value<bool?> kakugoSnoozeResetsClock = const Value.absent(),
                Value<String?> oversleepContact = const Value.absent(),
                Value<String?> oversleepShare = const Value.absent(),
                Value<int?> oversleepTriggerMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmRowsCompanion.insert(
                id: id,
                hour: hour,
                minute: minute,
                repeatDays: repeatDays,
                enabled: enabled,
                wakeCheck: wakeCheck,
                graceMinutes: graceMinutes,
                snoozeIntervalMinutes: snoozeIntervalMinutes,
                snoozeMaxCount: snoozeMaxCount,
                soundId: soundId,
                kakugoHostage: kakugoHostage,
                kakugoRatePerMinute: kakugoRatePerMinute,
                kakugoCap: kakugoCap,
                kakugoSnoozePenalty: kakugoSnoozePenalty,
                kakugoSnoozeResetsClock: kakugoSnoozeResetsClock,
                oversleepContact: oversleepContact,
                oversleepShare: oversleepShare,
                oversleepTriggerMinutes: oversleepTriggerMinutes,
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
      Value<int?> kakugoSnoozePenalty,
      Value<bool?> kakugoSnoozeResetsClock,
      Value<int> coinsAtFire,
      Value<int> graceMinutes,
      Value<String?> wakeCheckResolved,
      Value<String?> snoozes,
      Value<int?> currentRingAtMs,
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
      Value<int?> kakugoSnoozePenalty,
      Value<bool?> kakugoSnoozeResetsClock,
      Value<int> coinsAtFire,
      Value<int> graceMinutes,
      Value<String?> wakeCheckResolved,
      Value<String?> snoozes,
      Value<int?> currentRingAtMs,
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

  ColumnFilters<int> get kakugoSnoozePenalty => $composableBuilder(
    column: $table.kakugoSnoozePenalty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get kakugoSnoozeResetsClock => $composableBuilder(
    column: $table.kakugoSnoozeResetsClock,
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

  ColumnFilters<String> get wakeCheckResolved => $composableBuilder(
    column: $table.wakeCheckResolved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snoozes => $composableBuilder(
    column: $table.snoozes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentRingAtMs => $composableBuilder(
    column: $table.currentRingAtMs,
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

  ColumnOrderings<int> get kakugoSnoozePenalty => $composableBuilder(
    column: $table.kakugoSnoozePenalty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get kakugoSnoozeResetsClock => $composableBuilder(
    column: $table.kakugoSnoozeResetsClock,
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

  ColumnOrderings<String> get wakeCheckResolved => $composableBuilder(
    column: $table.wakeCheckResolved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snoozes => $composableBuilder(
    column: $table.snoozes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentRingAtMs => $composableBuilder(
    column: $table.currentRingAtMs,
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

  GeneratedColumn<int> get kakugoSnoozePenalty => $composableBuilder(
    column: $table.kakugoSnoozePenalty,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get kakugoSnoozeResetsClock => $composableBuilder(
    column: $table.kakugoSnoozeResetsClock,
    builder: (column) => column,
  );

  GeneratedColumn<int> get coinsAtFire => $composableBuilder(
    column: $table.coinsAtFire,
    builder: (column) => column,
  );

  GeneratedColumn<int> get graceMinutes => $composableBuilder(
    column: $table.graceMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wakeCheckResolved => $composableBuilder(
    column: $table.wakeCheckResolved,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snoozes =>
      $composableBuilder(column: $table.snoozes, builder: (column) => column);

  GeneratedColumn<int> get currentRingAtMs => $composableBuilder(
    column: $table.currentRingAtMs,
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
                Value<int?> kakugoSnoozePenalty = const Value.absent(),
                Value<bool?> kakugoSnoozeResetsClock = const Value.absent(),
                Value<int> coinsAtFire = const Value.absent(),
                Value<int> graceMinutes = const Value.absent(),
                Value<String?> wakeCheckResolved = const Value.absent(),
                Value<String?> snoozes = const Value.absent(),
                Value<int?> currentRingAtMs = const Value.absent(),
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
                kakugoSnoozePenalty: kakugoSnoozePenalty,
                kakugoSnoozeResetsClock: kakugoSnoozeResetsClock,
                coinsAtFire: coinsAtFire,
                graceMinutes: graceMinutes,
                wakeCheckResolved: wakeCheckResolved,
                snoozes: snoozes,
                currentRingAtMs: currentRingAtMs,
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
                Value<int?> kakugoSnoozePenalty = const Value.absent(),
                Value<bool?> kakugoSnoozeResetsClock = const Value.absent(),
                Value<int> coinsAtFire = const Value.absent(),
                Value<int> graceMinutes = const Value.absent(),
                Value<String?> wakeCheckResolved = const Value.absent(),
                Value<String?> snoozes = const Value.absent(),
                Value<int?> currentRingAtMs = const Value.absent(),
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
                kakugoSnoozePenalty: kakugoSnoozePenalty,
                kakugoSnoozeResetsClock: kakugoSnoozeResetsClock,
                coinsAtFire: coinsAtFire,
                graceMinutes: graceMinutes,
                wakeCheckResolved: wakeCheckResolved,
                snoozes: snoozes,
                currentRingAtMs: currentRingAtMs,
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
typedef $$GardenPlacementRowsTableCreateCompanionBuilder =
    GardenPlacementRowsCompanion Function({
      required String id,
      required String itemId,
      required int x,
      required int y,
      required int placedAtMs,
      Value<int> growthStage,
      Value<int> rowid,
    });
typedef $$GardenPlacementRowsTableUpdateCompanionBuilder =
    GardenPlacementRowsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<int> x,
      Value<int> y,
      Value<int> placedAtMs,
      Value<int> growthStage,
      Value<int> rowid,
    });

class $$GardenPlacementRowsTableFilterComposer
    extends Composer<_$AppDatabase, $GardenPlacementRowsTable> {
  $$GardenPlacementRowsTableFilterComposer({
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

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get placedAtMs => $composableBuilder(
    column: $table.placedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get growthStage => $composableBuilder(
    column: $table.growthStage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GardenPlacementRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $GardenPlacementRowsTable> {
  $$GardenPlacementRowsTableOrderingComposer({
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

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get placedAtMs => $composableBuilder(
    column: $table.placedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get growthStage => $composableBuilder(
    column: $table.growthStage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GardenPlacementRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GardenPlacementRowsTable> {
  $$GardenPlacementRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<int> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<int> get placedAtMs => $composableBuilder(
    column: $table.placedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get growthStage => $composableBuilder(
    column: $table.growthStage,
    builder: (column) => column,
  );
}

class $$GardenPlacementRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GardenPlacementRowsTable,
          GardenPlacementRow,
          $$GardenPlacementRowsTableFilterComposer,
          $$GardenPlacementRowsTableOrderingComposer,
          $$GardenPlacementRowsTableAnnotationComposer,
          $$GardenPlacementRowsTableCreateCompanionBuilder,
          $$GardenPlacementRowsTableUpdateCompanionBuilder,
          (
            GardenPlacementRow,
            BaseReferences<
              _$AppDatabase,
              $GardenPlacementRowsTable,
              GardenPlacementRow
            >,
          ),
          GardenPlacementRow,
          PrefetchHooks Function()
        > {
  $$GardenPlacementRowsTableTableManager(
    _$AppDatabase db,
    $GardenPlacementRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GardenPlacementRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GardenPlacementRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GardenPlacementRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> x = const Value.absent(),
                Value<int> y = const Value.absent(),
                Value<int> placedAtMs = const Value.absent(),
                Value<int> growthStage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GardenPlacementRowsCompanion(
                id: id,
                itemId: itemId,
                x: x,
                y: y,
                placedAtMs: placedAtMs,
                growthStage: growthStage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required int x,
                required int y,
                required int placedAtMs,
                Value<int> growthStage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GardenPlacementRowsCompanion.insert(
                id: id,
                itemId: itemId,
                x: x,
                y: y,
                placedAtMs: placedAtMs,
                growthStage: growthStage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GardenPlacementRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GardenPlacementRowsTable,
      GardenPlacementRow,
      $$GardenPlacementRowsTableFilterComposer,
      $$GardenPlacementRowsTableOrderingComposer,
      $$GardenPlacementRowsTableAnnotationComposer,
      $$GardenPlacementRowsTableCreateCompanionBuilder,
      $$GardenPlacementRowsTableUpdateCompanionBuilder,
      (
        GardenPlacementRow,
        BaseReferences<
          _$AppDatabase,
          $GardenPlacementRowsTable,
          GardenPlacementRow
        >,
      ),
      GardenPlacementRow,
      PrefetchHooks Function()
    >;
typedef $$GardenInventoryRowsTableCreateCompanionBuilder =
    GardenInventoryRowsCompanion Function({
      required String itemId,
      Value<int> count,
      Value<int> rowid,
    });
typedef $$GardenInventoryRowsTableUpdateCompanionBuilder =
    GardenInventoryRowsCompanion Function({
      Value<String> itemId,
      Value<int> count,
      Value<int> rowid,
    });

class $$GardenInventoryRowsTableFilterComposer
    extends Composer<_$AppDatabase, $GardenInventoryRowsTable> {
  $$GardenInventoryRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GardenInventoryRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $GardenInventoryRowsTable> {
  $$GardenInventoryRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GardenInventoryRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GardenInventoryRowsTable> {
  $$GardenInventoryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);
}

class $$GardenInventoryRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GardenInventoryRowsTable,
          GardenInventoryRow,
          $$GardenInventoryRowsTableFilterComposer,
          $$GardenInventoryRowsTableOrderingComposer,
          $$GardenInventoryRowsTableAnnotationComposer,
          $$GardenInventoryRowsTableCreateCompanionBuilder,
          $$GardenInventoryRowsTableUpdateCompanionBuilder,
          (
            GardenInventoryRow,
            BaseReferences<
              _$AppDatabase,
              $GardenInventoryRowsTable,
              GardenInventoryRow
            >,
          ),
          GardenInventoryRow,
          PrefetchHooks Function()
        > {
  $$GardenInventoryRowsTableTableManager(
    _$AppDatabase db,
    $GardenInventoryRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GardenInventoryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GardenInventoryRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GardenInventoryRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GardenInventoryRowsCompanion(
                itemId: itemId,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GardenInventoryRowsCompanion.insert(
                itemId: itemId,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GardenInventoryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GardenInventoryRowsTable,
      GardenInventoryRow,
      $$GardenInventoryRowsTableFilterComposer,
      $$GardenInventoryRowsTableOrderingComposer,
      $$GardenInventoryRowsTableAnnotationComposer,
      $$GardenInventoryRowsTableCreateCompanionBuilder,
      $$GardenInventoryRowsTableUpdateCompanionBuilder,
      (
        GardenInventoryRow,
        BaseReferences<
          _$AppDatabase,
          $GardenInventoryRowsTable,
          GardenInventoryRow
        >,
      ),
      GardenInventoryRow,
      PrefetchHooks Function()
    >;
typedef $$ContactEventRowsTableCreateCompanionBuilder =
    ContactEventRowsCompanion Function({
      required String id,
      required String sessionId,
      required int firedAtMs,
      required String contactName,
      required String channel,
      Value<String?> detail,
      Value<int> rowid,
    });
typedef $$ContactEventRowsTableUpdateCompanionBuilder =
    ContactEventRowsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> firedAtMs,
      Value<String> contactName,
      Value<String> channel,
      Value<String?> detail,
      Value<int> rowid,
    });

class $$ContactEventRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ContactEventRowsTable> {
  $$ContactEventRowsTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firedAtMs => $composableBuilder(
    column: $table.firedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactName => $composableBuilder(
    column: $table.contactName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactEventRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactEventRowsTable> {
  $$ContactEventRowsTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firedAtMs => $composableBuilder(
    column: $table.firedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactName => $composableBuilder(
    column: $table.contactName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactEventRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactEventRowsTable> {
  $$ContactEventRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get firedAtMs =>
      $composableBuilder(column: $table.firedAtMs, builder: (column) => column);

  GeneratedColumn<String> get contactName => $composableBuilder(
    column: $table.contactName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);
}

class $$ContactEventRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactEventRowsTable,
          ContactEventRow,
          $$ContactEventRowsTableFilterComposer,
          $$ContactEventRowsTableOrderingComposer,
          $$ContactEventRowsTableAnnotationComposer,
          $$ContactEventRowsTableCreateCompanionBuilder,
          $$ContactEventRowsTableUpdateCompanionBuilder,
          (
            ContactEventRow,
            BaseReferences<
              _$AppDatabase,
              $ContactEventRowsTable,
              ContactEventRow
            >,
          ),
          ContactEventRow,
          PrefetchHooks Function()
        > {
  $$ContactEventRowsTableTableManager(
    _$AppDatabase db,
    $ContactEventRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactEventRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactEventRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactEventRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> firedAtMs = const Value.absent(),
                Value<String> contactName = const Value.absent(),
                Value<String> channel = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactEventRowsCompanion(
                id: id,
                sessionId: sessionId,
                firedAtMs: firedAtMs,
                contactName: contactName,
                channel: channel,
                detail: detail,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int firedAtMs,
                required String contactName,
                required String channel,
                Value<String?> detail = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactEventRowsCompanion.insert(
                id: id,
                sessionId: sessionId,
                firedAtMs: firedAtMs,
                contactName: contactName,
                channel: channel,
                detail: detail,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContactEventRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactEventRowsTable,
      ContactEventRow,
      $$ContactEventRowsTableFilterComposer,
      $$ContactEventRowsTableOrderingComposer,
      $$ContactEventRowsTableAnnotationComposer,
      $$ContactEventRowsTableCreateCompanionBuilder,
      $$ContactEventRowsTableUpdateCompanionBuilder,
      (
        ContactEventRow,
        BaseReferences<_$AppDatabase, $ContactEventRowsTable, ContactEventRow>,
      ),
      ContactEventRow,
      PrefetchHooks Function()
    >;
typedef $$ContactBookRowsTableCreateCompanionBuilder =
    ContactBookRowsCompanion Function({
      required String id,
      required String name,
      Value<String?> reading,
      Value<String?> phone,
      Value<String?> email,
      required int createdAtMs,
      Value<int> rowid,
    });
typedef $$ContactBookRowsTableUpdateCompanionBuilder =
    ContactBookRowsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> reading,
      Value<String?> phone,
      Value<String?> email,
      Value<int> createdAtMs,
      Value<int> rowid,
    });

class $$ContactBookRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ContactBookRowsTable> {
  $$ContactBookRowsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reading => $composableBuilder(
    column: $table.reading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactBookRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactBookRowsTable> {
  $$ContactBookRowsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reading => $composableBuilder(
    column: $table.reading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactBookRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactBookRowsTable> {
  $$ContactBookRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get reading =>
      $composableBuilder(column: $table.reading, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$ContactBookRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactBookRowsTable,
          ContactBookRow,
          $$ContactBookRowsTableFilterComposer,
          $$ContactBookRowsTableOrderingComposer,
          $$ContactBookRowsTableAnnotationComposer,
          $$ContactBookRowsTableCreateCompanionBuilder,
          $$ContactBookRowsTableUpdateCompanionBuilder,
          (
            ContactBookRow,
            BaseReferences<
              _$AppDatabase,
              $ContactBookRowsTable,
              ContactBookRow
            >,
          ),
          ContactBookRow,
          PrefetchHooks Function()
        > {
  $$ContactBookRowsTableTableManager(
    _$AppDatabase db,
    $ContactBookRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactBookRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactBookRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactBookRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> reading = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactBookRowsCompanion(
                id: id,
                name: name,
                reading: reading,
                phone: phone,
                email: email,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> reading = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                required int createdAtMs,
                Value<int> rowid = const Value.absent(),
              }) => ContactBookRowsCompanion.insert(
                id: id,
                name: name,
                reading: reading,
                phone: phone,
                email: email,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContactBookRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactBookRowsTable,
      ContactBookRow,
      $$ContactBookRowsTableFilterComposer,
      $$ContactBookRowsTableOrderingComposer,
      $$ContactBookRowsTableAnnotationComposer,
      $$ContactBookRowsTableCreateCompanionBuilder,
      $$ContactBookRowsTableUpdateCompanionBuilder,
      (
        ContactBookRow,
        BaseReferences<_$AppDatabase, $ContactBookRowsTable, ContactBookRow>,
      ),
      ContactBookRow,
      PrefetchHooks Function()
    >;
typedef $$DiscordWebhookRowsTableCreateCompanionBuilder =
    DiscordWebhookRowsCompanion Function({
      required String id,
      required String url,
      required String displayName,
      required int createdAtMs,
      Value<int> rowid,
    });
typedef $$DiscordWebhookRowsTableUpdateCompanionBuilder =
    DiscordWebhookRowsCompanion Function({
      Value<String> id,
      Value<String> url,
      Value<String> displayName,
      Value<int> createdAtMs,
      Value<int> rowid,
    });

class $$DiscordWebhookRowsTableFilterComposer
    extends Composer<_$AppDatabase, $DiscordWebhookRowsTable> {
  $$DiscordWebhookRowsTableFilterComposer({
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

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiscordWebhookRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiscordWebhookRowsTable> {
  $$DiscordWebhookRowsTableOrderingComposer({
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

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiscordWebhookRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiscordWebhookRowsTable> {
  $$DiscordWebhookRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$DiscordWebhookRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiscordWebhookRowsTable,
          DiscordWebhookRow,
          $$DiscordWebhookRowsTableFilterComposer,
          $$DiscordWebhookRowsTableOrderingComposer,
          $$DiscordWebhookRowsTableAnnotationComposer,
          $$DiscordWebhookRowsTableCreateCompanionBuilder,
          $$DiscordWebhookRowsTableUpdateCompanionBuilder,
          (
            DiscordWebhookRow,
            BaseReferences<
              _$AppDatabase,
              $DiscordWebhookRowsTable,
              DiscordWebhookRow
            >,
          ),
          DiscordWebhookRow,
          PrefetchHooks Function()
        > {
  $$DiscordWebhookRowsTableTableManager(
    _$AppDatabase db,
    $DiscordWebhookRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiscordWebhookRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiscordWebhookRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiscordWebhookRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiscordWebhookRowsCompanion(
                id: id,
                url: url,
                displayName: displayName,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String url,
                required String displayName,
                required int createdAtMs,
                Value<int> rowid = const Value.absent(),
              }) => DiscordWebhookRowsCompanion.insert(
                id: id,
                url: url,
                displayName: displayName,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiscordWebhookRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiscordWebhookRowsTable,
      DiscordWebhookRow,
      $$DiscordWebhookRowsTableFilterComposer,
      $$DiscordWebhookRowsTableOrderingComposer,
      $$DiscordWebhookRowsTableAnnotationComposer,
      $$DiscordWebhookRowsTableCreateCompanionBuilder,
      $$DiscordWebhookRowsTableUpdateCompanionBuilder,
      (
        DiscordWebhookRow,
        BaseReferences<
          _$AppDatabase,
          $DiscordWebhookRowsTable,
          DiscordWebhookRow
        >,
      ),
      DiscordWebhookRow,
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
  $$GardenPlacementRowsTableTableManager get gardenPlacementRows =>
      $$GardenPlacementRowsTableTableManager(_db, _db.gardenPlacementRows);
  $$GardenInventoryRowsTableTableManager get gardenInventoryRows =>
      $$GardenInventoryRowsTableTableManager(_db, _db.gardenInventoryRows);
  $$ContactEventRowsTableTableManager get contactEventRows =>
      $$ContactEventRowsTableTableManager(_db, _db.contactEventRows);
  $$ContactBookRowsTableTableManager get contactBookRows =>
      $$ContactBookRowsTableTableManager(_db, _db.contactBookRows);
  $$DiscordWebhookRowsTableTableManager get discordWebhookRows =>
      $$DiscordWebhookRowsTableTableManager(_db, _db.discordWebhookRows);
}
