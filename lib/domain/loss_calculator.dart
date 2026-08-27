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

/// Where the minute clock starts for [session]. Pure.
///
/// Normally the scheduled fire time. Under a pledge that opted into
/// 「次に鳴る時刻を起点にし直す」 it is the start of the *current* ring instead, so a
/// snoozed alarm stops billing while it is silent and gets its grace window
/// afresh when it comes back. Never the other way round: a plain alarm and a
/// 「規定時刻から加算し続ける」 pledge both keep counting from [AlarmSession.firedAt].
DateTime lossClockBase(AlarmSession session) =>
    session.kakugoSnapshot?.snoozeResetsClock ?? false
    ? session.currentRingAt
    : session.firedAt;

/// How much of the grace window is left at [now]. Zero once it has run out.
/// Pure.
Duration graceRemaining(DateTime now, AlarmSession session) {
  final left = lossClockBase(session)
      .add(Duration(minutes: normalizeGraceMinutes(session.graceMinutes)))
      .difference(now);
  return left.isNegative ? Duration.zero : left;
}

/// Coins burned so far in [session] as of [now].
///
/// Pure. Two parts, per spec 4:
///
/// * the minute part — whole minutes past the grace window, counted from
///   [lossClockBase], times the rate. In reset-clock mode this is 0 for as long
///   as the alarm is silent, because [AlarmSession.currentRingAt] is still in
///   the future, and the grace applies again once it comes back.
/// * the snooze part — one flat penalty per press, charged the instant the
///   button is pressed and never refunded.
///
/// Their sum is clamped to the pledged cap and to the balance the user had when
/// the alarm fired, whichever is smaller. The snooze part is inside that clamp:
/// no arrangement of presses can burn more than the pledge said.
int lossAt(DateTime now, AlarmSession session) {
  final kakugo = session.kakugoSnapshot;
  if (kakugo == null) return 0;

  final elapsed = now.difference(lossClockBase(session));
  final minutePart = elapsed.isNegative
      ? 0
      : billableMinutes(elapsed, session.graceMinutes) * kakugo.ratePerMinute;
  final snoozePart =
      session.snoozes.length * normalizeSnoozePenalty(kakugo.snoozePenalty);

  final ceiling = math.min(kakugo.cap, session.coinsAtFire);
  return math.max(0, math.min(minutePart + snoozePart, ceiling));
}

/// Judged on time, never on money: cleared inside the grace window is a
/// success, later is oversleeping — even when it cost nothing because the
/// wallet was empty, the cap was 0, or there was no pledge at all.
///
/// [snoozed] settles it on its own. Pressing snooze is a decision not to get
/// up, so the morning is failed however quickly the check is cleared
/// afterwards, and however little it cost — a plain alarm with no pledge
/// included. [elapsed] is always measured from `firedAt`, never from the
/// re-ring: the clock modes decide what a snooze *costs*, not whether it counts.
SessionStatus judgeStatus(
  Duration elapsed, {
  required int graceMinutes,
  bool snoozed = false,
}) => !snoozed && elapsed.inMinutes < normalizeGraceMinutes(graceMinutes)
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
        snoozed: session.wasSnoozed,
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
