import 'dart:math';

import '../data/repositories/alarm_session_repository.dart';
import '../data/repositories/ojisan_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../domain/loss_calculator.dart';
import '../domain/models.dart';
import '../domain/reward.dart';
import '../domain/snooze_rules.dart';
import '../domain/wake_check.dart';

/// What [SessionService.recoverPending] found at startup.
class RecoveryOutcome {
  const RecoveryOutcome({
    this.resumed,
    this.settled = const [],
    this.snoozing = const [],
  });

  /// A session that is still within the hour and should go back on screen.
  final AlarmSession? resumed;

  /// Sessions written off by the 60 minute safety valve, newest first.
  final List<AlarmSession> settled;

  /// Sessions that are snoozed and not yet due back. Still ringing, still
  /// costing money under the default clock mode — but silent, so they do not
  /// go on screen. Their platform alarm needs re-arming, and nothing else.
  final List<AlarmSession> snoozing;

  bool get isEmpty =>
      resumed == null && settled.isEmpty && snoozing.isEmpty;
}

/// Owns the money side of a ring: opening a session, and settling it exactly
/// once against the wallet and the ojisan's takings.
class SessionService {
  SessionService(this._sessions, this._wallet, this._ojisan, {Random? random})
    : _random = random ?? Random();

  final AlarmSessionRepository _sessions;
  final WalletRepository _wallet;
  final OjisanRepository _ojisan;

  /// Injectable so the draw behind [WakeCheckType.random] can be tested.
  final Random _random;

  /// Opens a session, freezing the pledge and the balance as they are now.
  Future<AlarmSession> start({
    required Alarm alarm,
    required DateTime firedAt,
    String? id,
  }) async {
    final wallet = await _wallet.read();
    final session = AlarmSession(
      id: id ?? 'session-${firedAt.millisecondsSinceEpoch}-${alarm.id}',
      alarmId: alarm.id,
      firedAt: firedAt,
      kakugoSnapshot: alarm.kakugo,
      coinsAtFire: wallet.coins,
      graceMinutes: alarm.graceMinutes,
      // The draw happens once, here, and is written down with the rest of the
      // frozen terms: a relaunch mid-ring must find the same check waiting,
      // not roll again for an easier one.
      wakeCheckResolved: alarm.wakeCheck == WakeCheckType.random
          ? resolveWakeCheck(alarm.wakeCheck, _random)
          : null,
    );
    await _sessions.save(session);
    return session;
  }

  /// The user cleared the wake check.
  Future<AlarmSession> dismiss(AlarmSession session, DateTime dismissedAt) =>
      settle(finalizeSession(session, dismissedAt));

  /// Writes [settled] down and moves the coins.
  ///
  /// A no-op unless the stored session is still ringing, so a double dismiss
  /// — or a settle racing the recovery pass — cannot charge twice.
  Future<AlarmSession> settle(AlarmSession settled) async {
    final stored = await _sessions.getById(settled.id);
    if (stored != null && !stored.isRinging) return stored;

    await _sessions.save(settled);

    if (settled.status == SessionStatus.failed) {
      if (settled.loss > 0) {
        await _wallet.update((w) => w.copyWith(coins: w.coins - settled.loss));
      }
      // A plain alarm's failure belongs in the history, but the ojisan made
      // nothing off it, so it does not count towards his growth.
      if (settled.kakugoSnapshot != null) {
        await _ojisan.update(
          (o) => o.copyWith(
            totalOversleeps: o.totalOversleeps + 1,
            totalEarned: o.totalEarned + settled.loss,
          ),
        );
      }
    } else {
      final reward = rewardTokens(settled.kakugoSnapshot);
      await _wallet.update((w) => w.copyWith(tokens: w.tokens + reward));
    }

    return settled;
  }

  /// Applies the 60 minute safety valve to everything left ringing by a crash
  /// or a kill, and reports what should go back on screen.
  Future<RecoveryOutcome> recoverPending(DateTime now) async {
    final ringing = await _sessions.getRingingAll();
    if (ringing.isEmpty) return const RecoveryOutcome();

    AlarmSession? resumed;
    final settled = <AlarmSession>[];
    final snoozing = <AlarmSession>[];

    for (final session in ringing) {
      // The valve first: an hour past firedAt is written off even if the user
      // snoozed their way there. Snooze never buys extra time.
      final recovered = recoverSession(session, now);
      if (!recovered.isRinging) {
        settled.add(await settle(recovered));
        continue;
      }
      // Silent and not yet due back: leave it exactly where it is.
      if (isSnoozePending(recovered, now)) {
        snoozing.add(recovered);
        continue;
      }
      // Keep the newest live one; anything older is superseded.
      if (resumed == null || session.firedAt.isAfter(resumed.firedAt)) {
        resumed = recovered;
      }
    }

    settled.sort((a, b) => b.firedAt.compareTo(a.firedAt));
    return RecoveryOutcome(
      resumed: resumed,
      settled: settled,
      snoozing: snoozing,
    );
  }
}
