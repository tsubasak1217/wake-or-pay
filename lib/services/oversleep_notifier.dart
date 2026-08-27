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
  Future<ContactEvent?> notify({
    required AlarmSession session,
    required OversleepContact contact,
    required DateTime at,
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
    required OversleepContact contact,
    required DateTime at,
  }) async {
    final event = ContactEvent(
      id: 'contact-${at.millisecondsSinceEpoch}-${session.id}',
      sessionId: session.id,
      firedAt: at,
      contactName: contact.name,
      channel: channelFor(contact),
      // The alarm's own time, not the trigger time: that is what the message
      // is about.
      detail: detailFor(contact, session.firedAt, userName: _userName()),
    );
    await _events.save(event);

    final text = contactSentNotificationText(contact.name);
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
/// A route counts only when the user switched it on *and* there is an address
/// to use. A phone call is the loudest thing available, so it comes first.
List<ContactChannel> channelsFor(OversleepContact contact) => [
  if (contact.willPhone) ContactChannel.phone,
  if (contact.willEmail) ContactChannel.email,
];

/// The single channel the event row is filed under. Pure.
///
/// The row has one column and a contact can use both routes, so this is the
/// loudest of them; [detailFor] is where every route that went out is written
/// down. With no route at all there is nothing to do but keep the record.
ContactChannel channelFor(OversleepContact contact) {
  final channels = channelsFor(contact);
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
  OversleepContact contact,
  DateTime at, {
  required String userName,
}) {
  final call = callContentFor(contact, at, userName: userName);
  final parts = [
    if (contact.willPhone)
      call.recordingPath != null ? '電話（カスタム録音）' : '電話（自動音声）：${call.script}',
    if (contact.willEmail)
      '${contact.mailMode == MailMode.custom ? 'メール（カスタムメッセージ）' : 'メール（デフォルト）'}'
          '：${mailBodyFor(contact, at, userName: userName)}',
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
    if (!alarm.willContact) return null;
    final snapshot = alarm.contact!;
    if (!contactIsDue(now, session, snapshot)) return null;
    if ((await _events.forSession(session.id)).isNotEmpty) return null;

    final contact = resolveOversleepContact(snapshot, await _book());
    return _notifier.notify(session: session, contact: contact, at: now);
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
