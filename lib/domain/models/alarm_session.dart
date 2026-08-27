import 'package:flutter/foundation.dart';

import 'alarm.dart';
import 'kakugo.dart';

enum SessionStatus { ringing, success, failed }

/// One ring of one alarm.
///
/// [kakugoSnapshot] and [coinsAtFire] freeze the terms at the moment the alarm
/// fired, so editing the alarm — or spending coins — mid-ring cannot change
/// what this session costs.
@immutable
class AlarmSession {
  // Not const: [currentRingAt] defaults to [firedAt], and an initializing
  // formal cannot be read from an initializer list. A DateTime is never a
  // constant expression anyway, so no caller loses anything.
  // ignore: prefer_const_constructors_in_immutables
  AlarmSession({
    required this.id,
    required this.alarmId,
    required DateTime firedAt,
    this.dismissedAt,
    this.status = SessionStatus.ringing,
    this.loss = 0,
    this.kakugoSnapshot,
    this.coinsAtFire = 0,
    this.graceMinutes = minGraceMinutes,
    this.wakeCheckResolved,
    this.snoozes = const [],
    DateTime? currentRingAt,
  }) : firedAt = firedAt,
       currentRingAt = currentRingAt ?? firedAt;

  final String id;
  final String alarmId;
  final DateTime firedAt;
  final DateTime? dismissedAt;
  final SessionStatus status;
  final int loss;
  final Kakugo? kakugoSnapshot;

  /// Coin balance when the alarm fired. Never burn more than this.
  final int coinsAtFire;

  /// The alarm's grace window, frozen at fire time like the pledge. Lives on
  /// the session rather than inside [kakugoSnapshot] so a plain alarm — which
  /// has no pledge but still has a success window — carries it too.
  final int graceMinutes;

  /// Which wake check this ring actually asks for. Only ever set when the alarm
  /// chose [WakeCheckType.random]: the draw happens once, when the session
  /// opens, and is stored so a relaunch mid-ring shows the same check rather
  /// than rolling again for an easier one.
  final WakeCheckType? wakeCheckResolved;

  /// Every time the user pressed snooze during this ring, oldest first. Empty
  /// is the overwhelmingly common case and the only one a pre-stage-B row can
  /// read back as.
  final List<DateTime> snoozes;

  /// When the ring the user is standing in front of *started*: [firedAt] for a
  /// session that was never snoozed, the re-ring time afterwards. Defaulted
  /// rather than nullable so no caller has to remember the first-ring case.
  final DateTime currentRingAt;

  bool get isRinging => status == SessionStatus.ringing;

  bool get wasSnoozed => snoozes.isNotEmpty;

  AlarmSession copyWith({
    String? id,
    String? alarmId,
    DateTime? firedAt,
    DateTime? dismissedAt,
    SessionStatus? status,
    int? loss,
    Kakugo? kakugoSnapshot,
    int? coinsAtFire,
    int? graceMinutes,
    WakeCheckType? wakeCheckResolved,
    List<DateTime>? snoozes,
    DateTime? currentRingAt,
  }) => AlarmSession(
    id: id ?? this.id,
    alarmId: alarmId ?? this.alarmId,
    firedAt: firedAt ?? this.firedAt,
    dismissedAt: dismissedAt ?? this.dismissedAt,
    status: status ?? this.status,
    loss: loss ?? this.loss,
    kakugoSnapshot: kakugoSnapshot ?? this.kakugoSnapshot,
    coinsAtFire: coinsAtFire ?? this.coinsAtFire,
    graceMinutes: graceMinutes ?? this.graceMinutes,
    wakeCheckResolved: wakeCheckResolved ?? this.wakeCheckResolved,
    snoozes: snoozes ?? this.snoozes,
    currentRingAt: currentRingAt ?? this.currentRingAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'alarmId': alarmId,
    'firedAt': firedAt.toIso8601String(),
    'dismissedAt': dismissedAt?.toIso8601String(),
    'status': status.name,
    'loss': loss,
    'kakugoSnapshot': kakugoSnapshot?.toJson(),
    'coinsAtFire': coinsAtFire,
    'graceMinutes': graceMinutes,
    'wakeCheckResolved': wakeCheckResolved?.name,
    'snoozes': snoozes.map((t) => t.toIso8601String()).toList(),
    'currentRingAt': currentRingAt.toIso8601String(),
  };

  factory AlarmSession.fromJson(Map<String, dynamic> json) => AlarmSession(
    id: json['id'] as String,
    alarmId: json['alarmId'] as String,
    firedAt: DateTime.parse(json['firedAt'] as String),
    dismissedAt: json['dismissedAt'] == null
        ? null
        : DateTime.parse(json['dismissedAt'] as String),
    status: SessionStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => SessionStatus.ringing,
    ),
    loss: json['loss'] as int,
    kakugoSnapshot: json['kakugoSnapshot'] == null
        ? null
        : Kakugo.fromJson(
            (json['kakugoSnapshot'] as Map).cast<String, dynamic>(),
          ),
    coinsAtFire: json['coinsAtFire'] as int? ?? 0,
    graceMinutes: normalizeGraceMinutes(
      json['graceMinutes'] as int? ?? minGraceMinutes,
    ),
    wakeCheckResolved: wakeCheckTypeByName(
      json['wakeCheckResolved'] as String?,
    ),
    snoozes: [
      for (final t in (json['snoozes'] as List? ?? const []))
        DateTime.parse(t as String),
    ],
    currentRingAt: json['currentRingAt'] == null
        ? null
        : DateTime.parse(json['currentRingAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is AlarmSession &&
      other.id == id &&
      other.alarmId == alarmId &&
      other.firedAt == firedAt &&
      other.dismissedAt == dismissedAt &&
      other.status == status &&
      other.loss == loss &&
      other.kakugoSnapshot == kakugoSnapshot &&
      other.coinsAtFire == coinsAtFire &&
      other.graceMinutes == graceMinutes &&
      other.wakeCheckResolved == wakeCheckResolved &&
      listEquals(other.snoozes, snoozes) &&
      other.currentRingAt == currentRingAt;

  @override
  int get hashCode => Object.hash(
    id,
    alarmId,
    firedAt,
    dismissedAt,
    status,
    loss,
    kakugoSnapshot,
    coinsAtFire,
    graceMinutes,
    wakeCheckResolved,
    Object.hashAll(snoozes),
    currentRingAt,
  );

  @override
  String toString() =>
      'AlarmSession($id, alarm $alarmId, fired $firedAt, $status, loss $loss)';
}
