import 'package:flutter/foundation.dart';

/// Where a [PendingCharge] is in its life. Only [pending] is ever written
/// today; the rest are the states Phase 3 will move a row through once it can
/// actually talk to the Worker.
enum PendingChargeStatus {
  pending,
  submitted,
  paid,
  failed;

  static PendingChargeStatus byName(String? name) =>
      PendingChargeStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => PendingChargeStatus.pending,
      );
}

/// One overslept ring that will be billed to the registered card.
///
/// Written locally at settle time and **never sent anywhere**: Phase 1 charges
/// nothing, and this ledger exists so that when Phase 3 arrives there is a
/// record of every amount that was promised — see `docs/BILLING_API.md`.
///
/// [sessionId] is the identity: one ring can produce at most one charge, which
/// is the same rule the Worker's own ledger keeps with a UNIQUE `session_id`.
@immutable
class PendingCharge {
  const PendingCharge({
    required this.sessionId,
    required this.alarmId,
    required this.amount,
    required this.createdAt,
    this.currency = 'jpy',
    this.status = PendingChargeStatus.pending,
  });

  final String sessionId;
  final String alarmId;

  /// 円. 1 コイン = 1 円, so this is the session's `loss` unchanged.
  final int amount;

  final DateTime createdAt;
  final String currency;
  final PendingChargeStatus status;

  @override
  bool operator ==(Object other) =>
      other is PendingCharge &&
      other.sessionId == sessionId &&
      other.alarmId == alarmId &&
      other.amount == amount &&
      other.createdAt == createdAt &&
      other.currency == currency &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(sessionId, alarmId, amount, createdAt, currency, status);

  @override
  String toString() =>
      'PendingCharge($sessionId, $amount $currency, ${status.name})';
}
