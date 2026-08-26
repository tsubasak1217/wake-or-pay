import 'package:flutter/foundation.dart';

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
  }) => AlarmSession(
    id: id ?? this.id,
    alarmId: alarmId ?? this.alarmId,
    firedAt: firedAt ?? this.firedAt,
    dismissedAt: dismissedAt ?? this.dismissedAt,
    status: status ?? this.status,
    loss: loss ?? this.loss,
    kakugoSnapshot: kakugoSnapshot ?? this.kakugoSnapshot,
    coinsAtFire: coinsAtFire ?? this.coinsAtFire,
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
      other.coinsAtFire == coinsAtFire;

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
  );

  @override
  String toString() =>
      'AlarmSession($id, alarm $alarmId, fired $firedAt, $status, loss $loss)';
}
