import 'package:flutter/foundation.dart';

import 'kakugo.dart';
import 'oversleep_contact.dart';
import 'oversleep_share.dart';
import 'snooze.dart';

/// How the user proves they are actually awake.
///
/// [normal] is first because it is the plainest one — an ordinary alarm's
/// dismiss button, for the mornings nobody wants a puzzle. It is deliberately
/// **not** in [randomWakeCheckPool]: a random draw that can land on "tap once"
/// is not a check.
enum WakeCheckType { normal, longPress, math, typing, shake, random }

extension WakeCheckTypeLabel on WakeCheckType {
  String get label => switch (this) {
    WakeCheckType.normal => 'ノーマル',
    WakeCheckType.longPress => '長押し（5秒）',
    WakeCheckType.math => '計算（3問）',
    WakeCheckType.typing => '文字入力',
    WakeCheckType.shake => '振る（5秒）',
    WakeCheckType.random => 'ランダム',
  };

  /// One line of explanation, shown in the editor's sub-screen.
  String get description => switch (this) {
    WakeCheckType.normal => '解除ボタンを1回押すだけ',
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
    this.contact,
    this.share,
    this.oversleepTriggerMinutes,
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

  /// Who to tell if this alarm is slept through. One per alarm, null = nobody.
  final OversleepContact? contact;

  /// Where to announce it, per spec 11.6. null = nowhere.
  final OversleepShare? share;

  /// Minutes after the grace window before both the contact and the share go
  /// out, 0-60. **One number for both**, per spec 11.3.
  ///
  /// Nullable because a v6 row kept it inside the contact JSON: null means
  /// "whatever that row said, or the default". Everything that reads it goes
  /// through [triggerMinutes], and the mapper fills the column in on the way
  /// out, so a row only reads as null once.
  final int? oversleepTriggerMinutes;

  bool get isKakugo => kakugo != null;

  bool get canSnooze => snooze != null;

  /// The delay actually used, clamped. Pure.
  int get triggerMinutes => normalizeContactTriggerMinutes(
    oversleepTriggerMinutes ?? defaultContactTriggerMinutes,
  );

  /// A contact only means anything under a pledge — it is part of 覚悟の設定 —
  /// and only when it names someone.
  bool get willContact => isKakugo && (contact?.isUsable ?? false);

  /// The same rule for the group half: a pledge, and at least one 共有先.
  bool get willShare => isKakugo && (share?.isUsable ?? false);

  /// Whether anybody at all hears about this alarm being slept through. The
  /// countdown, the speech and the dispatcher all key off this rather than off
  /// [willContact]: a share-only alarm is every bit as much a notification.
  bool get willNotify => willContact || willShare;

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
    OversleepContact? contact,
    bool clearContact = false,
    OversleepShare? share,
    bool clearShare = false,
    int? oversleepTriggerMinutes,
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
    contact: clearContact ? null : (contact ?? this.contact),
    share: clearShare ? null : (share ?? this.share),
    oversleepTriggerMinutes:
        oversleepTriggerMinutes ?? this.oversleepTriggerMinutes,
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
    'contact': contact?.toJson(),
    'share': share?.toJson(),
    'oversleepTriggerMinutes': oversleepTriggerMinutes,
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
    contact: json['contact'] == null
        ? null
        : OversleepContact.fromJson(
            (json['contact'] as Map).cast<String, dynamic>(),
          ),
    share: json['share'] == null
        ? null
        : OversleepShare.fromJson(
            (json['share'] as Map).cast<String, dynamic>(),
          ),
    // The v6 shape kept this inside the contact blob, so an alarm read from
    // that JSON falls back to it before the default.
    oversleepTriggerMinutes:
        (json['oversleepTriggerMinutes'] as int?) ??
        (json['contact'] is Map
            ? (json['contact'] as Map)['triggerMinutesAfterGrace'] as int?
            : null),
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
      other.kakugo == kakugo &&
      other.contact == contact &&
      other.share == share &&
      other.oversleepTriggerMinutes == oversleepTriggerMinutes;

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
    contact,
    share,
    oversleepTriggerMinutes,
  );

  @override
  String toString() =>
      'Alarm($id, $hour:$minute, days $repeatDays, enabled $enabled, '
      '$wakeCheck, grace ${graceMinutes}m, $snooze, $soundId, $kakugo, '
      '$contact, $share, +${triggerMinutes}m)';
}
