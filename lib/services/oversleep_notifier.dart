import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/repositories/contact_event_repository.dart';
import '../domain/discord_post.dart';
import '../domain/models.dart';
import '../domain/oversleep_contact_rules.dart';
import '../domain/send_result.dart';
import 'alarm_settings_builder.dart';
import 'app_notifier.dart';
import 'discord_sender.dart';
import 'mail_sender.dart';

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

/// The implementation this phase ships: **Discord and mail are really sent**,
/// the phone call and the SMS are still only recorded.
///
/// A webhook is an HTTPS POST and a mail is an SMTP conversation, both of
/// which the phone can hold on its own; a call and a text need Android
/// permissions that D2 and D3 bring. What must never happen is the app
/// claiming either group is the other — see [contactSentNotificationText].
class OversleepDispatchNotifier implements OversleepNotifier {
  OversleepDispatchNotifier(
    this._events,
    this._notifications,
    this._sender,
    this._mail, {
    required this.userName,
    required this.discordUserId,
    required this.webhooks,
  });

  final ContactEventRepository _events;
  final AppNotifier _notifications;
  final DiscordWebhookSender _sender;
  final MailSender _mail;

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
    final personal = await _runPersonalRoutes(
      session: session,
      at: at,
      contact: contact,
    );

    final text = contactSentNotificationText(
      target,
      discordSent: results.where((r) => r.ok).length,
      discordFailed: results.where((r) => !r.ok).length,
      sentRoutes: [
        for (final run in personal)
          if (run.result.ok) contactChannelLabel(run.channel),
      ],
      failedRoutes: [
        for (final run in personal)
          if (!run.result.ok) contactChannelLabel(run.channel),
      ],
      pendingRoutes: [
        for (final channel in pendingChannelsFor(contact))
          contactChannelLabel(channel),
      ],
    );
    await _notifications.show(
      id: contactNotificationId(platformAlarmId(session.alarmId)),
      title: text.title,
      body: text.body,
    );
    return event;
  }

  /// Runs every personal route this app can actually perform, and files one
  /// row for each.
  ///
  /// One row per route, beside the summary row above, for the same reason the
  /// Discord half gets one per webhook: 「連絡しました」 is worth nothing the
  /// morning after if it cannot say *which* route reached them and which one
  /// bounced.
  ///
  /// Each route is awaited and each failure is a value, so an SMTP server that
  /// is down cannot stop the one beside it — nor the notification that says so.
  Future<List<({ContactChannel channel, SendResult result})>>
  _runPersonalRoutes({
    required AlarmSession session,
    required DateTime at,
    OversleepContact? contact,
  }) async {
    if (contact == null) return const [];
    final runs = <({ContactChannel channel, SendResult result})>[];

    if (contact.willEmail) {
      // The alarm's own time, not the trigger time: that is what the message
      // is about, and it is the time the contact will look for on the clock.
      final mail = buildOversleepMail(
        contact,
        session.firedAt,
        userName: userName(),
      );
      runs.add((
        channel: ContactChannel.email,
        result: await _mail.send(
          to: mail.to,
          subject: mail.subject,
          body: mail.body,
        ),
      ));
    }

    for (final run in runs) {
      await _events.save(
        ContactEvent(
          // The channel is on the end because the primary key is this string:
          // the mail row and the summary row fire in the same millisecond of
          // the same session, and without it one would overwrite the other.
          id: 'contact-${at.millisecondsSinceEpoch}-${session.id}'
              '-${run.channel.name}',
          sessionId: session.id,
          firedAt: at,
          contactName: contact.name,
          channel: run.channel,
          detail: run.result.label,
        ),
      );
    }
    return runs;
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

/// The routes [contact] asked for that this build cannot actually perform.
/// Pure.
///
/// The honest half of [contactSentNotificationText]: a user who switched 電話
/// on is owed a sentence saying it did not ring, rather than a notification
/// that quietly implies it did. It shrinks as D2 and D3 land, and the day it
/// is empty the sentence disappears on its own.
List<ContactChannel> pendingChannelsFor(OversleepContact? contact) => [
  if (contact?.willPhone ?? false) ContactChannel.phone,
  if (contact?.willSms ?? false) ContactChannel.sms,
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
    ref.watch(mailSenderProvider),
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
