import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/repositories/contact_event_repository.dart';
import '../domain/models.dart';
import '../domain/oversleep_contact_rules.dart';
import 'alarm_settings_builder.dart';
import 'app_notifier.dart';

/// How the app tells someone that an alarm was slept through.
///
/// An interface because the next phase replaces it wholesale: a server that
/// actually places the call or sends the mail. Everything above this line —
/// the timing, the once-per-session rule, the countdown, the speech — is
/// finished and will not move when that lands.
abstract class OversleepNotifier {
  /// Returns the event that was recorded, or null if nothing was.
  ///
  /// [contact] and [share] are both optional and at least one of them is
  /// present: an alarm may tell a person, a set of Discord 共有先, or both.
  Future<ContactEvent?> notify({
    required AlarmSession session,
    required DateTime at,
    OversleepContact? contact,
    OversleepShare? share,
  });
}

/// The implementation this phase ships: **nothing is sent**.
///
/// It writes the trigger into `contact_events` and posts a notification that
/// says, in as many words, that no message actually went out. Letting the user
/// believe a call was placed when it was not would be worse than not having
/// the feature at all.
class LoggingOversleepNotifier implements OversleepNotifier {
  LoggingOversleepNotifier(this._events, this._notifications, this._userName);

  final ContactEventRepository _events;
  final AppNotifier _notifications;

  /// Read at trigger time rather than held, so renaming yourself takes effect
  /// on alarms that were written before the rename.
  final String Function() _userName;

  @override
  Future<ContactEvent?> notify({
    required AlarmSession session,
    required DateTime at,
    OversleepContact? contact,
    OversleepShare? share,
  }) async {
    // The one phrase the countdown, the speech and this row all name the
    // recipient with, so the log never disagrees with what was said out loud.
    final target = oversleepTargetLabel(
      contactName: contact?.isUsable ?? false ? contact!.name : null,
      webhookCount: share?.webhookIds.length ?? 0,
    );
    final event = ContactEvent(
      id: 'contact-${at.millisecondsSinceEpoch}-${session.id}',
      sessionId: session.id,
      firedAt: at,
      contactName: target,
      channel: channelFor(contact, share),
      // The alarm's own time, not the trigger time: that is what the message
      // is about.
      detail: detailFor(
        session.firedAt,
        contact: contact,
        share: share,
        userName: _userName(),
      ),
    );
    await _events.save(event);

    final text = contactSentNotificationText(target);
    await _notifications.show(
      id: contactNotificationId(platformAlarmId(session.alarmId)),
      title: text.title,
      body: text.body,
    );
    return event;
  }
}

/// Every route the next phase would have taken, in the order it would take
/// them. Pure.
///
/// A route counts only when the user switched it on *and* there is somewhere
/// for it to go. A phone call is the loudest thing available, so it comes
/// first; Discord is last because it reaches a room rather than a person.
List<ContactChannel> channelsFor({
  OversleepContact? contact,
  OversleepShare? share,
}) => [
  if (contact?.willPhone ?? false) ContactChannel.phone,
  if (contact?.willSms ?? false) ContactChannel.sms,
  if (contact?.willEmail ?? false) ContactChannel.email,
  if (share?.isUsable ?? false) ContactChannel.discord,
];

/// The single channel the event row is filed under. Pure.
///
/// The row has one column and an alarm can use every route at once, so this is
/// the loudest of them; [detailFor] is where every route that went out is
/// written down. With no route at all there is nothing to do but keep the
/// record.
ContactChannel channelFor(OversleepContact? contact, OversleepShare? share) {
  final channels = channelsFor(contact: contact, share: share);
  return channels.isEmpty ? ContactChannel.log : channels.first;
}

/// What would have been sent, on which route, in which mode — kept so the
/// history can show it. Pure.
///
/// Nothing is actually sent, so this string is the entire evidence that the
/// app decided to send it. It names each route and its mode by the same words
/// the editor uses.
///
/// [userName] is the app's user — the subject of the default sentence, not the
/// contact it is sent to.
String? detailFor(
  DateTime at, {
  OversleepContact? contact,
  OversleepShare? share,
  required String userName,
}) {
  String mode(MessageMode m) =>
      m == MessageMode.custom ? 'カスタムメッセージ' : 'デフォルト';

  final parts = [
    // The call plays nothing since 改訂4 — it rings, and the contact's own
    // voice is the message — so there is no body to write down for it.
    if (contact?.willPhone ?? false) '電話',
    if (contact?.willSms ?? false)
      'SMS（${mode(contact!.messageMode)}）'
          '：${oversleepSmsBodyFor(contact, at, userName: userName)}',
    if (contact?.willEmail ?? false)
      'メール（${mode(contact!.messageMode)}）'
          '：${oversleepMailBodyFor(contact, at, userName: userName)}',
    if (share?.isUsable ?? false)
      'Discord ${share!.webhookIds.length}件（${mode(share.messageMode)}）'
          '：${oversleepShareBodyFor(share, at)}'
          '${share.hasRecording ? '＋録音' : ''}',
  ];
  return parts.isEmpty ? null : parts.join(' / ');
}

/// Decides *whether* to fire, and fires at most once per session.
///
/// The once-per-session rule is enforced against the stored events rather than
/// a flag in memory, so a relaunch mid-ring — or the ring screen being rebuilt
/// — cannot send a second one.
class ContactDispatcher {
  ContactDispatcher(this._events, this._notifier, {ContactBookReader? book})
    : _book = book ?? _emptyBook;

  static Future<List<ContactEntry>> _emptyBook() async =>
      const <ContactEntry>[];

  final ContactEventRepository _events;
  final OversleepNotifier _notifier;

  /// The 連絡帳, read at trigger time. The alarm carries a snapshot of the
  /// person it names, and that snapshot is only the fallback: while the entry
  /// still exists it is the entry that is mailed and named, so an address
  /// corrected last night is the one used this morning.
  final ContactBookReader _book;

  /// Returns the event if one was recorded now, null in every other case:
  /// nobody to contact, not due yet, or already sent for this session.
  Future<ContactEvent?> fireIfDue({
    required Alarm alarm,
    required AlarmSession session,
    required DateTime now,
  }) async {
    // Either half is enough: an alarm that only announces itself to a Discord
    // room is every bit as much a notification as one that calls a person.
    if (!alarm.willNotify) return null;
    if (!contactIsDue(now, session, alarm)) return null;
    if ((await _events.forSession(session.id)).isNotEmpty) return null;

    final snapshot = alarm.willContact ? alarm.contact : null;
    return _notifier.notify(
      session: session,
      at: now,
      contact: snapshot == null
          ? null
          : resolveOversleepContact(snapshot, await _book()),
      share: alarm.willShare ? alarm.share : null,
    );
  }
}

/// How [ContactDispatcher] gets at the 連絡帳 without knowing about drift.
typedef ContactBookReader = Future<List<ContactEntry>> Function();

final oversleepNotifierProvider = Provider<OversleepNotifier>(
  (ref) => LoggingOversleepNotifier(
    ref.watch(contactEventRepositoryProvider),
    ref.watch(appNotifierProvider),
    // read, not watch: the name is wanted at the moment of firing, and a
    // rename should not tear this provider down mid-session.
    () => ref.read(profileRepositoryProvider).read().userName,
  ),
);

final contactDispatcherProvider = Provider(
  (ref) => ContactDispatcher(
    ref.watch(contactEventRepositoryProvider),
    ref.watch(oversleepNotifierProvider),
    book: () => ref.read(contactBookRepositoryProvider).getAll(),
  ),
);
