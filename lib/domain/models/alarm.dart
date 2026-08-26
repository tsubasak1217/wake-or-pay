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

@immutable
class Alarm {
  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.repeatDays = const {},
    this.enabled = true,
    this.wakeCheck = WakeCheckType.longPress,
    this.kakugo,
  });

  final String id;
  final int hour;
  final int minute;

  /// 1 = Monday … 7 = Sunday, matching [DateTime.weekday]. Empty = one shot.
  final Set<int> repeatDays;
  final bool enabled;
  final WakeCheckType wakeCheck;

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
    Kakugo? kakugo,
    bool clearKakugo = false,
  }) => Alarm(
    id: id ?? this.id,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    repeatDays: repeatDays ?? this.repeatDays,
    enabled: enabled ?? this.enabled,
    wakeCheck: wakeCheck ?? this.wakeCheck,
    kakugo: clearKakugo ? null : (kakugo ?? this.kakugo),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'repeatDays': (repeatDays.toList()..sort()),
    'enabled': enabled,
    'wakeCheck': wakeCheck.name,
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
      other.kakugo == kakugo;

  @override
  int get hashCode => Object.hash(
    id,
    hour,
    minute,
    Object.hashAllUnordered(repeatDays),
    enabled,
    wakeCheck,
    kakugo,
  );

  @override
  String toString() =>
      'Alarm($id, $hour:$minute, days $repeatDays, enabled $enabled, '
      '$wakeCheck, $kakugo)';
}
