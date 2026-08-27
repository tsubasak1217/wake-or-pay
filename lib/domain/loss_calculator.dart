import 'dart:math' as math;

import 'models.dart';

/// How long a ringing session may survive an app kill before it is written off
/// as a failure. Safety valve, per spec 3.
const recoveryDeadline = Duration(minutes: 60);

/// Whole minutes overslept beyond the grace window, i.e. how many minutes are
/// actually charged for. Pure.
///
/// The first charged minute is the one that ends the grace: with a one minute
/// grace, 7:01 bills one minute; with five, 7:04 bills nothing and 7:05 bills
/// one. Never negative.
int billableMinutes(Duration elapsed, int graceMinutes) =>
    math.max(0, elapsed.inMinutes - normalizeGraceMinutes(graceMinutes) + 1);

/// How much of the grace window is left at [now]. Zero once it has run out.
/// Pure.
Duration graceRemaining(DateTime now, AlarmSession session) {
  final left = session.firedAt
      .add(Duration(minutes: normalizeGraceMinutes(session.graceMinutes)))
      .difference(now);
  return left.isNegative ? Duration.zero : left;
}

/// Coins burned so far in [session] as of [now].
///
/// Pure. Whole minutes only, counted from the end of the grace window: with the
/// default one minute grace, 7:00:59 still costs 0 and 7:01:00 costs one
/// minute's rate. Never exceeds the pledged cap, and never exceeds the balance
/// the user had when the alarm fired.
int lossAt(DateTime now, AlarmSession session) {
  final kakugo = session.kakugoSnapshot;
  if (kakugo == null) return 0;

  final elapsed = now.difference(session.firedAt);
  if (elapsed.isNegative) return 0;

  final raw =
      billableMinutes(elapsed, session.graceMinutes) * kakugo.ratePerMinute;
  return math.max(0, math.min(raw, math.min(kakugo.cap, session.coinsAtFire)));
}

/// Judged on time, never on money: cleared inside the grace window is a
/// success, later is oversleeping — even when it cost nothing because the
/// wallet was empty, the cap was 0, or there was no pledge at all.
SessionStatus judgeStatus(Duration elapsed, {required int graceMinutes}) =>
    elapsed.inMinutes < normalizeGraceMinutes(graceMinutes)
    ? SessionStatus.success
    : SessionStatus.failed;

/// Settles [session] because the user cleared the wake check at [dismissedAt].
AlarmSession finalizeSession(AlarmSession session, DateTime dismissedAt) =>
    session.copyWith(
      dismissedAt: dismissedAt,
      loss: lossAt(dismissedAt, session),
      status: judgeStatus(
        dismissedAt.difference(session.firedAt),
        graceMinutes: session.graceMinutes,
      ),
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
