import 'loss_calculator.dart';
import 'models.dart';
import 'send_result.dart';

/// The contact as it should be **shown and used right now**.
///
/// [OversleepContact] holds a *snapshot* of a 連絡帳 entry — taken the moment
/// the person was picked — so that deleting them from the book never leaves an
/// alarm with nobody to call. The cost of that snapshot is drift: renaming
/// 田中太郎 in the book used to leave every alarm pointing at him still saying
/// the old name on every screen, and still mailing the old address.
///
/// So the snapshot is a **fallback**, not the truth: while the entry still
/// exists the live one wins. A route the edited entry can no longer reach is
/// switched off here too — an alarm cannot mail an address that was deleted,
/// and cannot text a number that was.
///
/// Pure: the caller supplies the book. A contact that never came from the book
/// ([OversleepContact.contactId] null), or one whose entry has since been
/// deleted, comes back untouched.
OversleepContact resolveOversleepContact(
  OversleepContact contact,
  Iterable<ContactEntry> book,
) {
  final id = contact.contactId;
  if (id == null) return contact;
  for (final entry in book) {
    if (entry.id != id) continue;
    return contact.copyWith(
      name: entry.name,
      phone: entry.phone,
      clearPhone: entry.phone == null,
      email: entry.email,
      clearEmail: entry.email == null,
      phoneEnabled: contact.phoneEnabled && entry.hasPhone,
      emailEnabled: contact.emailEnabled && entry.hasEmail,
      smsEnabled: contact.smsEnabled && entry.hasPhone,
    );
  }
  return contact;
}

/// [resolveOversleepContact] for an alarm that may have nobody on it. Pure.
OversleepContact? resolveOversleepContactOrNull(
  OversleepContact? contact,
  Iterable<ContactEntry> book,
) => contact == null ? null : resolveOversleepContact(contact, book);

/// [alarm] with its contact snapshot brought back up to date. Pure.
Alarm resolveAlarmContact(Alarm alarm, Iterable<ContactEntry> book) {
  final contact = alarm.contact;
  if (contact == null) return alarm;
  return alarm.copyWith(contact: resolveOversleepContact(contact, book));
}

/// Who hears about this alarm, as one phrase. Pure.
///
/// 「田中太郎 さん」 / 「Discord 2件」 / 「田中太郎 さん と Discord 2件」, and the empty
/// string when nobody does. Every sentence about the notification — the
/// countdown on the ringing screen, each spoken cue, the row on the alarm
/// list, the log entry — is built on this one phrase, so the screen and the
/// voice can never name different recipients.
///
/// The honorific rides along with the name because the group half takes none:
/// 「Discord 2件 さん」 would be nonsense.
String oversleepTargetLabel({String? contactName, int webhookCount = 0}) {
  final name = contactName?.trim() ?? '';
  final parts = [
    if (name.isNotEmpty) '$name さん',
    if (webhookCount > 0) 'Discord $webhookCount件',
  ];
  return parts.join(' と ');
}

/// How many of [share]'s targets still exist. Pure.
///
/// An alarm stores webhook **ids**, and there is deliberately no foreign key
/// behind them: deleting a 共有先 must never break an alarm that pointed at it.
/// The price is dangling ids, and this is where they stop counting — a share
/// that named two rooms and lost one announces itself to one room, and every
/// screen has to say one.
///
/// [known] is the app-wide list. A caller that does not have it passes nothing
/// and gets the stored count, which is the best answer available before the
/// rows arrive.
int liveShareTargetCount(
  OversleepShare? share,
  Iterable<DiscordWebhook>? known,
) {
  final ids = share?.webhookIds ?? const <String>{};
  if (known == null) return ids.length;
  return ids.where((id) => known.any((w) => w.id == id)).length;
}

/// [oversleepTargetLabel] for a whole alarm, with the contact resolved against
/// the live 連絡帳. Pure.
///
/// Reads the alarm's `will…` rules rather than the raw fields, so a contact
/// on an alarm with no pledge — or a share with no targets left — is named
/// nowhere, exactly as it is notified nowhere.
///
/// [webhooks] is the app-wide 共有先 list when the caller has it; without it
/// the stored ids are counted as they stand. See [liveShareTargetCount].
String oversleepTargetLabelForAlarm(
  Alarm alarm,
  Iterable<ContactEntry> book, {
  Iterable<DiscordWebhook>? webhooks,
}) => oversleepTargetLabel(
  contactName: alarm.willContact
      ? resolveOversleepContact(alarm.contact!, book).name
      : null,
  webhookCount: alarm.willShare
      ? liveShareTargetCount(alarm.share, webhooks)
      : 0,
);

/// When the notification for [session] goes out, or null if nobody is told.
/// Pure, per spec 5 as revised by 11.3.
///
/// Counted from the same clock the loss is billed on: the grace window first,
/// then the user's chosen delay. Under 「次に鳴る時刻を起点にし直す」 that clock is
/// the current ring, so snoozing pushes the trigger out with everything else;
/// under 「規定時刻から加算し続ける」 it is the scheduled time, so snoozing does not
/// stop the timer any more than it stops the burn.
///
/// The delay lives on the **alarm** since 改訂4, because one number drives both
/// the personal contact and the group share.
DateTime? contactTriggerAt(AlarmSession session, Alarm? alarm) {
  if (alarm == null || !alarm.willNotify) return null;
  return lossClockBase(session).add(
    Duration(
      minutes:
          normalizeGraceMinutes(session.graceMinutes) + alarm.triggerMinutes,
    ),
  );
}

/// How long until the notification goes out. Zero once it is due, null when
/// nobody is told. Pure.
Duration? contactRemaining(DateTime now, AlarmSession session, Alarm? alarm) {
  final triggerAt = contactTriggerAt(session, alarm);
  if (triggerAt == null) return null;
  final left = triggerAt.difference(now);
  return left.isNegative ? Duration.zero : left;
}

/// Whether the notification is due at [now]. Pure.
///
/// Says nothing about whether it has *already* been sent — that is one per
/// session and is tracked by the caller.
bool contactIsDue(DateTime now, AlarmSession session, Alarm? alarm) {
  final triggerAt = contactTriggerAt(session, alarm);
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
///
/// [target] is [oversleepTargetLabel]'s phrase, so a share-only alarm reads
/// 「あと 2:30 で Discord 2件に連絡が行きます」 with no further plumbing.
String contactCountdownLine(Duration remaining, String target) =>
    remaining <= Duration.zero
    ? '$targetに連絡が行きました'
    : 'あと ${contactCountdown(remaining)} で $targetに連絡が行きます';

/// What the synthesised voice says for [cue]. Pure.
///
/// Deliberately plain sentences with no numerals a TTS engine has to guess at:
/// 「3分」 and 「30秒」 read correctly in Japanese, 「2:30」 does not.
String contactSpeechText(
  ContactSpeechCue cue,
  String target, {
  int triggerMinutes = defaultContactTriggerMinutes,
}) => switch (cue) {
  ContactSpeechCue.start =>
    'このまま寝ていると、'
        '${normalizeContactTriggerMinutes(triggerMinutes)}'
        '分後に $targetに連絡が行きます',
  ContactSpeechCue.threeMinutes => 'あと3分で $targetに連絡が行きます',
  ContactSpeechCue.oneMinute => 'あと1分で $targetに連絡が行きます',
  ContactSpeechCue.thirtySeconds => 'あと30秒で $targetに連絡が行きます',
  ContactSpeechCue.sent => '$targetに連絡しました',
};

/// The notification posted when the contact fires, per spec 5. Pure.
///
/// It says, route by route, what actually happened — because the routes no
/// longer agree with each other. A single sentence covering the lot would have
/// to be a lie about half of them: 「実際には送信していません」 is a lie about a mail
/// that reached somebody's inbox, and dropping the caveat is a lie about a
/// phone call nobody placed. Each group says its own piece.
///
/// [discordSent] and [discordFailed] count 共有先 posted to and 共有先 that
/// refused. [sentRoutes] and [failedRoutes] name the personal routes that were
/// attempted — 「電話」, 「SMS」, 「メール」 — and which of them worked. A route
/// the app could not take at all, such as a call from the background isolate,
/// is a failure here: from the sleeper's side there is no difference between a
/// call that could not be placed and one that would not connect.
({String title, String body}) contactSentNotificationText(
  String target, {
  int discordSent = 0,
  int discordFailed = 0,
  List<String> sentRoutes = const [],
  List<String> failedRoutes = const [],
}) {
  // 「電話を送信しました」 is not a sentence. A call is placed, not sent, so it
  // gets its own clause and the written routes share the other one.
  const phone = '電話';
  final sent = sentRoutes.where((r) => r != phone);
  final failed = failedRoutes.where((r) => r != phone);
  final parts = [
    if (discordSent > 0) 'Discord $discordSent件に投稿しました',
    if (discordFailed > 0) 'Discord $discordFailed件は送信できませんでした',
    if (sentRoutes.contains(phone)) '電話をかけました',
    if (failedRoutes.contains(phone)) '電話をかけられませんでした',
    if (sent.isNotEmpty) '${sent.join('・')}を送信しました',
    if (failed.isNotEmpty) '${failed.join('・')}は送信できませんでした',
  ];
  return (
    title: '$targetへの連絡',
    body: parts.isEmpty ? '$targetへの連絡を記録しました' : parts.join('。'),
  );
}

/// The id of the one row that says "this session has been notified". Pure.
///
/// **No timestamp in it**, per spec 11.7: it is the row the ringing screen and
/// the background isolate race to claim, and two ids a millisecond apart would
/// let both of them win and send everything twice.
String contactSummaryRowId(String sessionId) => 'contact-$sessionId';

/// The suffix the per-route log rows carry on their id, so the summary row —
/// which is filed under the loudest channel and shares the same timestamp —
/// can be told apart from the route's own row.
String contactRouteRowSuffix(ContactChannel channel) => '-${channel.name}';

/// 「田中太郎 に電話をかけました」 for the ringing screen, or null when no call was
/// attempted for this session. Pure, per spec 11.5.
///
/// It reads the rows the dispatcher wrote rather than being told by the
/// dispatcher, so the line on screen is the log: if it says the call was
/// placed, there is a row saying so, and if the call failed the screen says
/// that instead of quietly showing nothing.
String? oversleepCallLine(Iterable<ContactEvent> events) {
  for (final event in events) {
    if (!event.id.endsWith(contactRouteRowSuffix(ContactChannel.phone))) {
      continue;
    }
    return event.detail == sendSuccessLabel
        ? '${event.contactName} に電話をかけました'
        : '${event.contactName} に電話をかけられませんでした';
  }
  return null;
}

/// What each route is called in a sentence and in a log row. Pure.
String contactChannelLabel(ContactChannel channel) => switch (channel) {
  ContactChannel.phone => '電話',
  ContactChannel.sms => 'SMS',
  ContactChannel.email => 'メール',
  ContactChannel.discord => 'Discord',
  ContactChannel.log => '記録',
};
