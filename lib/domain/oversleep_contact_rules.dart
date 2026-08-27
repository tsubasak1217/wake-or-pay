import 'loss_calculator.dart';
import 'models.dart';

/// When the contact for [session] is triggered, or null if there is nobody to
/// contact. Pure, per spec 5.
///
/// Counted from the same clock the loss is billed on: the grace window first,
/// then the user's chosen delay. Under 「次に鳴る時刻を起点にし直す」 that clock is
/// the current ring, so snoozing pushes the trigger out with everything else;
/// under 「規定時刻から加算し続ける」 it is the scheduled time, so snoozing does not
/// stop the timer any more than it stops the burn.
DateTime? contactTriggerAt(AlarmSession session, OversleepContact? contact) {
  if (contact == null || !contact.isUsable) return null;
  return lossClockBase(session).add(
    Duration(
      minutes:
          normalizeGraceMinutes(session.graceMinutes) +
          normalizeContactTriggerMinutes(contact.triggerMinutesAfterGrace),
    ),
  );
}

/// How long until the contact goes out. Zero once it is due, null when there
/// is nobody to contact. Pure.
Duration? contactRemaining(
  DateTime now,
  AlarmSession session,
  OversleepContact? contact,
) {
  final triggerAt = contactTriggerAt(session, contact);
  if (triggerAt == null) return null;
  final left = triggerAt.difference(now);
  return left.isNegative ? Duration.zero : left;
}

/// Whether the contact is due at [now]. Pure.
///
/// Says nothing about whether it has *already* been sent — that is one per
/// session and is tracked by the caller.
bool contactIsDue(
  DateTime now,
  AlarmSession session,
  OversleepContact? contact,
) {
  final triggerAt = contactTriggerAt(session, contact);
  return triggerAt != null && !now.isBefore(triggerAt);
}

/// The moments the app says the countdown out loud, per spec 5.
enum ContactSpeechCue { start, threeMinutes, oneMinute, thirtySeconds, sent }

/// Which cue [remaining] has reached, or null when there is nothing to say
/// yet. Pure.
///
/// Cues are cumulative and one-way: a caller speaks a cue the first time it
/// comes back and remembers it, so a countdown that ticks every second says
/// each line exactly once. [ContactSpeechCue.start] is never returned here —
/// it belongs to the moment the screen opens, not to a remaining time.
ContactSpeechCue? cueFor(Duration remaining) {
  if (remaining <= Duration.zero) return ContactSpeechCue.sent;
  if (remaining <= const Duration(seconds: 30)) {
    return ContactSpeechCue.thirtySeconds;
  }
  if (remaining <= const Duration(minutes: 1)) {
    return ContactSpeechCue.oneMinute;
  }
  if (remaining <= const Duration(minutes: 3)) {
    return ContactSpeechCue.threeMinutes;
  }
  return null;
}

/// A countdown as 「2:30」, or 「1時間5分」 for the long delays the slider allows.
/// Pure.
String contactCountdown(Duration remaining) {
  final seconds = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  if (seconds >= 3600) {
    final hours = seconds ~/ 3600;
    return '$hours時間${(seconds % 3600) ~/ 60}分';
  }
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// The line on the ringing screen. Pure.
String contactCountdownLine(Duration remaining, OversleepContact contact) =>
    remaining <= Duration.zero
    ? '${contact.name} さんに連絡が行きました'
    : 'あと ${contactCountdown(remaining)} で ${contact.name} さんに連絡が行きます';

/// What the synthesised voice says for [cue]. Pure.
///
/// Deliberately plain sentences with no numerals a TTS engine has to guess at:
/// 「3分」 and 「30秒」 read correctly in Japanese, 「2:30」 does not.
String contactSpeechText(ContactSpeechCue cue, OversleepContact contact) {
  final name = contact.name;
  return switch (cue) {
    ContactSpeechCue.start =>
      'このまま寝ていると、'
          '${normalizeContactTriggerMinutes(contact.triggerMinutesAfterGrace)}'
          '分後に $name さんに連絡が行きます',
    ContactSpeechCue.threeMinutes => 'あと3分で $name さんに連絡が行きます',
    ContactSpeechCue.oneMinute => 'あと1分で $name さんに連絡が行きます',
    ContactSpeechCue.thirtySeconds => 'あと30秒で $name さんに連絡が行きます',
    ContactSpeechCue.sent => '$name さんに連絡しました',
  };
}

/// The notification posted when the contact fires, per spec 5. Pure.
///
/// It says out loud that nothing was actually sent. Letting a user believe a
/// message went out when it did not would be worse than not having the feature.
({String title, String body}) contactSentNotificationText(String name) =>
    (title: '$name さんへの連絡', body: '$name さんへの連絡が送信されました（開発中：実際には送信していません）');
