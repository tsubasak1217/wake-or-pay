import 'dart:math' as math;

import 'models.dart';

/// How long a ringing session may survive an app kill before it is written off
/// as a failure. Safety valve, per spec 3.
const recoveryDeadline = Duration(minutes: 60);

/// Coins burned so far in [session] as of [now].
///
/// Pure. Whole minutes only: 7:00:59 still costs 0, 7:01:00 costs one minute.
/// Never exceeds the pledged cap, and never exceeds the balance the user had
/// when the alarm fired.
int lossAt(DateTime now, AlarmSession session) {
  final kakugo = session.kakugoSnapshot;
  if (kakugo == null) return 0;

  final elapsed = now.difference(session.firedAt);
  if (elapsed.isNegative) return 0;

  final raw = elapsed.inMinutes * kakugo.ratePerMinute;
  return math.max(0, math.min(raw, math.min(kakugo.cap, session.coinsAtFire)));
}

/// Judged on time, never on money: cleared inside the first minute is a
/// success, later is oversleeping — even when it cost nothing because the
/// wallet was empty, the cap was 0, or there was no pledge at all.
SessionStatus judgeStatus(Duration elapsed) =>
    elapsed.inMinutes <= 0 ? SessionStatus.success : SessionStatus.failed;

/// Settles [session] because the user cleared the wake check at [dismissedAt].
AlarmSession finalizeSession(AlarmSession session, DateTime dismissedAt) =>
    session.copyWith(
      dismissedAt: dismissedAt,
      loss: lossAt(dismissedAt, session),
      status: judgeStatus(dismissedAt.difference(session.firedAt)),
    );

/// Settles a session that was left ringing when the app died.
///
/// Returns [session] unchanged while it is still within [recoveryDeadline] —
/// the ring screen simply resumes. Past the deadline the session is written off
/// as failed with the loss frozen at `firedAt + 60min`, even when that loss is
/// 0 (a plain alarm left ringing for an hour is still an overslept morning).
AlarmSession recoverSession(AlarmSession session, DateTime now) {
  if (session.status != SessionStatus.ringing) return session;

  final deadline = session.firedAt.add(recoveryDeadline);
  if (now.isBefore(deadline)) return session;

  return finalizeSession(session, deadline);
}
