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
  const AlarmSession({
    required this.id,
    required this.alarmId,
    required this.firedAt,
    this.dismissedAt,
    this.status = SessionStatus.ringing,
    this.loss = 0,
    this.kakugoSnapshot,
    this.coinsAtFire = 0,
    this.graceMinutes = minGraceMinutes,
    this.wakeCheckResolved,
  });

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

  bool get isRinging => status == SessionStatus.ringing;

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
      other.wakeCheckResolved == wakeCheckResolved;

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
  );

  @override
  String toString() =>
      'AlarmSession($id, alarm $alarmId, fired $firedAt, $status, loss $loss)';
}
