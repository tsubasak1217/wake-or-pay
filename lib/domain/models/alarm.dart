import 'package:flutter/foundation.dart';

import 'kakugo.dart';

/// How the user proves they are actually awake.
enum WakeCheckType { longPress, math, typing }

extension WakeCheckTypeLabel on WakeCheckType {
  String get label => switch (this) {
    WakeCheckType.longPress => '長押し（5秒）',
    WakeCheckType.math => '計算（3問）',
    WakeCheckType.typing => '文字入力',
  };
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

  /// null = plain alarm, nothing at stake.
  final Kakugo? kakugo;

  bool get isKakugo => kakugo != null;

  Alarm copyWith({
    String? id,
    int? hour,
    int? minute,
    Set<int>? repeatDays,
    bool? enabled,
    WakeCheckType? wakeCheck,
    int? graceMinutes,
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
    kakugo,
  );

  @override
  String toString() =>
      'Alarm($id, $hour:$minute, days $repeatDays, enabled $enabled, '
      '$wakeCheck, grace ${graceMinutes}m, $kakugo)';
}
