import 'package:flutter/foundation.dart';

import 'kakugo.dart';
import 'snooze.dart';

/// How the user proves they are actually awake.
enum WakeCheckType { longPress, math, typing, shake, random }

extension WakeCheckTypeLabel on WakeCheckType {
  String get label => switch (this) {
    WakeCheckType.longPress => '長押し（5秒）',
    WakeCheckType.math => '計算（3問）',
    WakeCheckType.typing => '文字入力',
    WakeCheckType.shake => '振る（5秒）',
    WakeCheckType.random => 'ランダム',
  };

  /// One line of explanation, shown in the editor's sub-screen.
  String get description => switch (this) {
    WakeCheckType.longPress => 'ボタンを5秒間押し続ける',
    WakeCheckType.math => '2桁の足し算を3問続けて正解する',
    WakeCheckType.typing => '表示された文を一字一句そのまま打つ',
    WakeCheckType.shake => '端末を5秒間振り続ける',
    WakeCheckType.random => '鳴った時に上の4種類から抽選する',
  };
}

/// Looks a stored wake check up by name. null in, null out; an unknown name
/// also gives null, so a row written by a future version cannot crash a read.
WakeCheckType? wakeCheckTypeByName(String? name) {
  if (name == null) return null;
  for (final type in WakeCheckType.values) {
    if (type.name == name) return type;
  }
  return null;
}

/// How long, in minutes, the user may take to clear the wake check before it
/// counts as oversleeping. 1 = the burn starts at 60 seconds.
const graceMinutesOptions = <int>[1, 2, 3, 4, 5];

const minGraceMinutes = 1;
const maxGraceMinutes = 5;

/// Grace is money, so nothing downstream trusts the stored number: a hand
/// edited database or an old row can never widen the window past five minutes
/// or shrink it below one. Pure.
int normalizeGraceMinutes(int minutes) =>
    minutes.clamp(minGraceMinutes, maxGraceMinutes);

/// The bundled sound an alarm rings with when nothing else was chosen. The
/// library itself lives in `domain/sound_library.dart`; an id of the form
/// `file:<path>` is a file the user picked off their device.
const defaultSoundId = 'bell';

@immutable
class Alarm {
  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.repeatDays = const {},
    this.enabled = true,
    this.wakeCheck = WakeCheckType.longPress,
    this.graceMinutes = minGraceMinutes,
    this.snooze,
    this.soundId = defaultSoundId,
    this.kakugo,
  });

  final String id;
  final int hour;
  final int minute;

  /// 1 = Monday … 7 = Sunday, matching [DateTime.weekday]. Empty = one shot.
  final Set<int> repeatDays;
  final bool enabled;
  final WakeCheckType wakeCheck;

  /// Minutes of slack before oversleeping starts, 1-5.
  final int graceMinutes;

  /// null = this alarm cannot be snoozed at all.
  final Snooze? snooze;

  /// A library id, or `file:<path>` for a sound copied off the device.
  final String soundId;

  /// null = plain alarm, nothing at stake.
  final Kakugo? kakugo;

  bool get isKakugo => kakugo != null;

  bool get canSnooze => snooze != null;

  Alarm copyWith({
    String? id,
    int? hour,
    int? minute,
    Set<int>? repeatDays,
    bool? enabled,
    WakeCheckType? wakeCheck,
    int? graceMinutes,
    Snooze? snooze,
    bool clearSnooze = false,
    String? soundId,
    Kakugo? kakugo,
    bool clearKakugo = false,
  }) => Alarm(
    id: id ?? this.id,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    repeatDays: repeatDays ?? this.repeatDays,
    enabled: enabled ?? this.enabled,
    wakeCheck: wakeCheck ?? this.wakeCheck,
    graceMinutes: graceMinutes ?? this.graceMinutes,
    snooze: clearSnooze ? null : (snooze ?? this.snooze),
    soundId: soundId ?? this.soundId,
    kakugo: clearKakugo ? null : (kakugo ?? this.kakugo),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'repeatDays': (repeatDays.toList()..sort()),
    'enabled': enabled,
    'wakeCheck': wakeCheck.name,
    'graceMinutes': graceMinutes,
    'snooze': snooze?.toJson(),
    'soundId': soundId,
    'kakugo': kakugo?.toJson(),
  };

  factory Alarm.fromJson(Map<String, dynamic> json) => Alarm(
    id: json['id'] as String,
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    repeatDays: {...(json['repeatDays'] as List).cast<int>()},
    enabled: json['enabled'] as bool,
    wakeCheck: WakeCheckType.values.firstWhere(
      (w) => w.name == json['wakeCheck'],
      orElse: () => WakeCheckType.longPress,
    ),
    graceMinutes: normalizeGraceMinutes(
      json['graceMinutes'] as int? ?? minGraceMinutes,
    ),
    snooze: json['snooze'] == null
        ? null
        : Snooze.fromJson((json['snooze'] as Map).cast<String, dynamic>()),
    soundId: json['soundId'] as String? ?? defaultSoundId,
    kakugo: json['kakugo'] == null
        ? null
        : Kakugo.fromJson((json['kakugo'] as Map).cast<String, dynamic>()),
  );

  @override
  bool operator ==(Object other) =>
      other is Alarm &&
      other.id == id &&
      other.hour == hour &&
      other.minute == minute &&
      setEquals(other.repeatDays, repeatDays) &&
      other.enabled == enabled &&
      other.wakeCheck == wakeCheck &&
      other.graceMinutes == graceMinutes &&
      other.snooze == snooze &&
      other.soundId == soundId &&
      other.kakugo == kakugo;

  @override
  int get hashCode => Object.hash(
    id,
    hour,
    minute,
    Object.hashAllUnordered(repeatDays),
    enabled,
    wakeCheck,
    graceMinutes,
    snooze,
    soundId,
    kakugo,
  );

  @override
  String toString() =>
      'Alarm($id, $hour:$minute, days $repeatDays, enabled $enabled, '
      '$wakeCheck, grace ${graceMinutes}m, $snooze, $soundId, $kakugo)';
}
