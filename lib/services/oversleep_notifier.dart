import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/repositories/contact_event_repository.dart';
import '../domain/discord_post.dart';
import '../domain/models.dart';
import '../domain/oversleep_contact_rules.dart';
import 'alarm_settings_builder.dart';
import 'app_notifier.dart';
import 'discord_sender.dart';

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

/// The implementation this phase ships: **Discord is really sent**, the rest
/// is still only recorded.
///
/// The split is C3's whole shape. A webhook is an HTTPS POST the phone can
/// make on its own, so it goes out for real; a phone call, an SMS and a mail
/// need permissions and an SMTP account that stage D brings, so they stay a
/// row in the log. What must never happen is the app claiming either one of
/// those is the other — see [contactSentNotificationText].
class OversleepDispatchNotifier implements OversleepNotifier {
  OversleepDispatchNotifier(
    this._events,
    this._notifications,
    this._sender, {
    required this.userName,
    required this.discordUserId,
    required this.webhooks,
  });

  final ContactEventRepository _events;
  final AppNotifier _notifications;
  final DiscordWebhookSender _sender;

  /// Read at trigger time rather than held, so renaming yourself — or filling
  /// the Discord ID in last night — takes effect on alarms that were written
  /// before it.
  final String Function() userName;
  final String Function() discordUserId;

  /// The app-wide 共有先 table, also read at trigger time: an alarm stores ids
  /// and there is deliberately no foreign key behind them, so an id whose row
  /// has since been deleted is simply skipped here.
  final Future<List<DiscordWebhook>> Function() webhooks;

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
        userName: userName(),
      ),
    );
    // Written **before** anything is posted, per spec 11.7: the once-per-
    // session guard reads these rows, so a relaunch mid-post must find the
    // session already marked as fired rather than send a second round.
    await _events.save(event);

    final results = await _postToShareTargets(
      session: session,
      at: at,
      share: share,
    );

    final text = contactSentNotificationText(
      target,
      discordSent: results.where((r) => r.ok).length,
      discordFailed: results.where((r) => !r.ok).length,
      otherRoutes: channelsFor(
        contact: contact,
      ).any((c) => c != ContactChannel.discord),
    );
    await _notifications.show(
      id: contactNotificationId(platformAlarmId(session.alarmId)),
      title: text.title,
      body: text.body,
    );
    return event;
  }

  /// Posts to every live 共有先 on [share] and files one row for each.
  ///
  /// One row per webhook rather than one for the lot: 「2件中1件が失敗」 is
  /// useless without saying *which*, and the whole reason to keep a log of a
  /// morning nobody was awake for is to be able to read afterwards which room
  /// actually heard about it.
  Future<List<DiscordPostResult>> _postToShareTargets({
    required AlarmSession session,
    required DateTime at,
    OversleepShare? share,
  }) async {
    if (share == null || !share.isUsable) return const [];
    final known = await webhooks();
    final content = discordOversleepContent(
      discordUserId: discordUserId(),
      userName: userName(),
      message: oversleepShareBodyFor(share, session.firedAt),
    );

    final results = <DiscordPostResult>[];
    for (final webhook in known.where((w) => share.webhookIds.contains(w.id))) {
      final result = await _sender.post(
        url: webhook.url,
        content: content,
        recordingPath: share.recordingPath,
      );
      results.add(result);
      await _events.save(
        ContactEvent(
          // The webhook's id is on the end because the primary key is this
          // string: two 共有先 firing in the same millisecond of the same
          // session would otherwise be one row overwriting the other, and the
          // failure would look exactly like a post that never happened.
          id: 'contact-${at.millisecondsSinceEpoch}-${session.id}'
              '-discord-${webhook.id}',
          sessionId: session.id,
          firedAt: at,
          contactName: webhook.displayName,
          channel: ContactChannel.discord,
          detail: result.label,
        ),
      );
    }
    return results;
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
/// For the personal routes, which stage D still owes, this string is the
/// entire evidence that the app decided to send anything at all; for the
/// Discord half it is the body that really went out, and the per-webhook rows
/// beside it say whether each 共有先 took it. It names each route and its mode
/// by the same words the editor uses.
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
  (ref) => OversleepDispatchNotifier(
    ref.watch(contactEventRepositoryProvider),
    ref.watch(appNotifierProvider),
    ref.watch(discordWebhookSenderProvider),
    // read, not watch: the profile is wanted at the moment of firing, and a
    // rename should not tear this provider down mid-session.
    userName: () => ref.read(profileRepositoryProvider).read().userName,
    discordUserId: () => ref.read(profileRepositoryProvider).read()
        .discordUserId,
    // The table, not the cached list: this runs once, at the trigger, and the
    // stream may not have delivered yet on a screen that was just launched.
    webhooks: () => ref.read(discordWebhookRepositoryProvider).getAll(),
  ),
);

final contactDispatcherProvider = Provider(
  (ref) => ContactDispatcher(
    ref.watch(contactEventRepositoryProvider),
    ref.watch(oversleepNotifierProvider),
    book: () => ref.read(contactBookRepositoryProvider).getAll(),
  ),
);
