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
AlarmSession applySnooze(
  AlarmSession session,
  DateTime now,
  Snooze snooze,
) => session.copyWith(
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

/// The notification posted when the button is pressed, per spec 4. Pure.
({String title, String body}) snoozeNotificationText(DateTime ringAt) => (
  title: 'スヌーズ中',
  body: '${snoozeRingAtLabel(ringAt)} に再鳴動',
);

/// What the snooze button says. Pure.
///
/// Under a pledge it has to state the price: a button that quietly costs 50
/// coins is exactly the kind of thing this app must not do.
String snoozeButtonLabel(Kakugo? kakugo) {
  final penalty = kakugo == null
      ? 0
      : normalizeSnoozePenalty(kakugo.snoozePenalty);
  return penalty > 0 ? 'スヌーズ（−$penalty コイン）' : 'スヌーズ';
}
