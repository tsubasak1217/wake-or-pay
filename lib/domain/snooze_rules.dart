import 'format.dart';
import 'models.dart';

/// Whether the ringing screen should offer a snooze button right now. Pure.
///
/// Two gates, both from spec 4: the alarm has to allow snoozing at all, and the
/// session has to have presses left. A `maxCount` of 0 means the button never
/// appears — it is not "unlimited", and there is deliberately no unlimited.
bool canSnoozeNow(Alarm alarm, AlarmSession session) {
  final snooze = alarm.snooze;
  if (snooze == null) return false;
  return session.snoozes.length < normalizeSnoozeMaxCount(snooze.maxCount);
}

/// How many presses are left. Pure.
int snoozesRemaining(Alarm alarm, AlarmSession session) {
  final snooze = alarm.snooze;
  if (snooze == null) return 0;
  final left =
      normalizeSnoozeMaxCount(snooze.maxCount) - session.snoozes.length;
  return left < 0 ? 0 : left;
}

/// When a press at [now] brings the alarm back. Pure.
DateTime nextRingAt(DateTime now, Snooze snooze) =>
    now.add(Duration(minutes: normalizeSnoozeInterval(snooze.intervalMinutes)));

/// [session] with one more press recorded and the ring moved. Pure.
///
/// The press time goes in the list — that is what the penalty counts — and
/// `currentRingAt` becomes the re-ring, which is what the reset clock mode
/// bills from and what the contact timer follows.
AlarmSession applySnooze(AlarmSession session, DateTime now, Snooze snooze) =>
    session.copyWith(
      snoozes: [...session.snoozes, now],
      currentRingAt: nextRingAt(now, snooze),
    );

/// A session that is snoozed and not yet back: still ringing as far as the
/// database is concerned, but silent, and not something to put on screen. Pure.
bool isSnoozePending(AlarmSession session, DateTime now) =>
    session.isRinging &&
    session.wasSnoozed &&
    now.isBefore(session.currentRingAt);

/// The re-ring time, as the notification and the alarm list write it. Pure.
String snoozeRingAtLabel(DateTime ringAt) =>
    '${ringAt.hour}:${ringAt.minute.toString().padLeft(2, '0')}';

/// The line the alarm list shows on a snoozed alarm. Pure.
String snoozeUntilLabel(DateTime ringAt) =>
    'スヌーズ中 ${snoozeRingAtLabel(ringAt)}';

/// The ongoing 「スヌーズ中」 notification, spec 12.1. Pure.
///
/// Body: the re-ring time, the loss so far when there is any, and the prompt to
/// press 解除. The loss line is dropped at 0 — a plain alarm, or a reset-clock
/// pledge still inside its grace — because 「これまでの損失 0 コイン」 on a
/// notification is the same kind of noise 「1分ごとに 0 コイン」 is on the ring
/// screen. A glance at the body is meant to reveal money is moving; when none
/// is, it should say so by staying quiet about it.
({String title, String body}) snoozeNotificationText(
  DateTime ringAt, {
  int loss = 0,
}) => (
  title: 'スヌーズ中',
  body: [
    '${snoozeRingAtLabel(ringAt)} に再鳴動します。',
    if (loss > 0) 'これまでの損失 $loss コイン。',
    '起きたら『解除』を押してください。',
  ].join(''),
);

/// What the snooze button says. Pure.
///
/// Under a pledge it has to state the price: a button that quietly costs 50
/// coins is exactly the kind of thing this app must not do.
String snoozeButtonLabel(Kakugo? kakugo) {
  // 人質なし costs nothing per press, so the button must not name a price it
  // will never charge.
  final penalty = kakugo == null || !kakugo.hostage.burns
      ? 0
      : normalizeSnoozePenalty(kakugo.snoozePenalty);
  return penalty > 0
      ? 'スヌーズ（−${hostageAmount(penalty, kakugo!.hostage)}）'
      : 'スヌーズ';
}

/// The line under the snooze button, or null when there is no price to explain.
/// Pure.
///
/// The button names a price, and the price is real the moment it is pressed —
/// but it is only ever *charged* on a failed morning. Get up inside the grace
/// window and the whole loss, presses included, is written off, so the button
/// must not read as a bill that cannot be undone.
String? snoozePenaltyRefundNote(Kakugo? kakugo) {
  final penalty = kakugo == null || !kakugo.hostage.burns
      ? 0
      : normalizeSnoozePenalty(kakugo.snoozePenalty);
  return penalty > 0 ? '猶予内に起きれば取り消されます' : null;
}
