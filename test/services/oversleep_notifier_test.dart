import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/discord_post.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/send_result.dart';
import 'package:wake_or_pay/services/alarm_service.dart';
import 'package:wake_or_pay/services/oversleep_notifier.dart';
import 'package:wake_or_pay/services/sms_sender.dart';

import '../helpers.dart';

const contact = OversleepContact(
  name: '田中太郎',
  phone: '090-0000-0000',
  phoneEnabled: true,
);

const share = OversleepShare(webhookIds: {'w1', 'w2'});

const pledged = Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
  contact: contact,
  oversleepTriggerMinutes: 10,
);

/// The same alarm with nobody on it and only a room to announce itself to.
const shareOnly = Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
  share: share,
  oversleepTriggerMinutes: 10,
);

final firedAt = DateTime(2026, 8, 27, 7);
DateTime at({int minutes = 0, int seconds = 0}) =>
    firedAt.add(Duration(minutes: minutes, seconds: seconds));

/// The app's own user: the subject of every default sentence below. Deliberately
/// not the contact's name, which is who the message goes *to*.
const userName = '山田花子';

/// The two 共有先 the shares above point at, so a post has somewhere to go.
///
/// An alarm stores ids with no foreign key behind them, so a test that does
/// not seed these is testing the dangling-id case, not the delivery one.
Future<void> seedWebhooks(ProviderContainer container) async {
  final repo = container.read(discordWebhookRepositoryProvider);
  await repo.save(
    DiscordWebhook(
      id: 'w1',
      url: 'https://discord.com/api/webhooks/1/aaa',
      displayName: 'みんなのサーバー/#一般',
      createdAt: DateTime(2026),
    ),
  );
  await repo.save(
    DiscordWebhook(
      id: 'w2',
      url: 'https://discord.com/api/webhooks/2/bbb',
      displayName: '寝坊部/#通報',
      createdAt: DateTime(2026, 1, 2),
    ),
  );
}

late FakeDiscordWebhookSender sender;

/// The SMTP half. Never reaches a server; an address in a test is somebody's
/// real inbox.
late FakeMailSender mails;

Future<({ProviderContainer container, AlarmSession session})> ringing(
  Alarm alarm, {
  String user = userName,
  String discordUserId = '',
  Map<String, DiscordPostResult> failFor = const {},
  bool webhooks = true,
  bool mailConfigured = false,
  SendResult mailResult = const SendResult.success(),
  SendResult smsResult = const SendResult.success(),
}) async {
  sender = FakeDiscordWebhookSender(failFor: failFor);
  mails = FakeMailSender(result: mailResult);
  final container = await testContainer(
    prefs: {
      if (user.isNotEmpty) 'profile.userName': user,
      if (discordUserId.isNotEmpty) 'profile.discordUserId': discordUserId,
      if (mailConfigured) ...configuredMailPrefs(),
    },
    extra: [
      fakeAlarmServiceOverride(),
      fakeDiscordSenderOverride(sender),
      fakeMailSenderOverride(mails),
      recordingSmsSenderOverride(RecordingSmsSender(result: smsResult)),
      if (mailConfigured) seededSecretStoreOverride(),
    ],
  );
  if (webhooks) await seedWebhooks(container);
  await container.read(alarmRepositoryProvider).save(alarm);
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 5000));
  final session = await container
      .read(sessionServiceProvider)
      .start(alarm: alarm, firedAt: firedAt);
  return (container: container, session: session);
}

void main() {
  group('ContactDispatcher', () {
    test('nothing happens before the trigger time', () async {
      final r = await ringing(pledged);
      final dispatcher = r.container.read(contactDispatcherProvider);

      expect(
        await dispatcher.fireIfDue(
          alarm: pledged,
          session: r.session,
          now: at(minutes: 10, seconds: 59),
        ),
        isNull,
      );
      expect(
        await r.container.read(contactEventRepositoryProvider).getRecent(),
        isEmpty,
      );
      expect(notifierOf(r.container).posted, isEmpty);
    });

    test(
      'at the trigger it logs the event and says nothing was sent',
      () async {
        final r = await ringing(pledged);

        final event = await r.container
            .read(contactDispatcherProvider)
            .fireIfDue(
              alarm: pledged,
              session: r.session,
              now: at(minutes: 11),
            );

        expect(event!.contactName, '田中太郎 さん');
        expect(event.sessionId, r.session.id);
        expect(event.firedAt, at(minutes: 11));
        expect(
          event.channel,
          ContactChannel.phone,
          reason: 'a call is the loudest thing available',
        );
        expect(
          event.detail,
          '電話',
          reason: 'the call plays nothing, so there is no body to write down',
        );

        final stored = await r.container
            .read(contactEventRepositoryProvider)
            .getRecent();
        expect(stored.single, event);

        final posted = notifierOf(r.container).posted.single;
        expect(
          posted.body,
          '電話は開発中で、記録だけが残ります',
          reason: 'the call really was not placed, and it says so',
        );
        expect(sender.posts, isEmpty, reason: 'no share on this alarm');
      },
    );

    test('once per session, however many times it is asked', () async {
      final r = await ringing(pledged);
      final dispatcher = r.container.read(contactDispatcherProvider);

      expect(
        await dispatcher.fireIfDue(
          alarm: pledged,
          session: r.session,
          now: at(minutes: 11),
        ),
        isNotNull,
      );
      for (final minute in const [12, 13, 60]) {
        expect(
          await dispatcher.fireIfDue(
            alarm: pledged,
            session: r.session,
            now: at(minutes: minute),
          ),
          isNull,
          reason: 'already sent',
        );
      }
      expect(
        await r.container.read(contactEventRepositoryProvider).getRecent(),
        hasLength(1),
      );
    });

    test('a share-only alarm is every bit as much a notification', () async {
      final r = await ringing(shareOnly);
      final dispatcher = r.container.read(contactDispatcherProvider);

      expect(
        await dispatcher.fireIfDue(
          alarm: shareOnly,
          session: r.session,
          now: at(minutes: 10, seconds: 59),
        ),
        isNull,
        reason: 'the same clock as a contact',
      );

      final event = await dispatcher.fireIfDue(
        alarm: shareOnly,
        session: r.session,
        now: at(minutes: 11),
      );
      expect(event!.contactName, 'Discord 2件');
      expect(event.channel, ContactChannel.discord);
      expect(
        event.detail,
        'Discord 2件（デフォルト）：07:00 のアラームを解除できていません。',
      );
      expect(
        notifierOf(r.container).posted.single.body,
        'Discord 2件に投稿しました',
        reason: 'this half really did go out, so it must not claim otherwise',
      );
      expect(sender.posts, hasLength(2));

      // And still exactly once, on the share half as on the personal one.
      for (final minute in const [12, 60]) {
        expect(
          await dispatcher.fireIfDue(
            alarm: shareOnly,
            session: r.session,
            now: at(minutes: minute),
          ),
          isNull,
        );
      }
      expect(
        sender.posts,
        hasLength(2),
        reason: 'the once-per-session rule guards the posting too',
      );
      expect(
        await r.container.read(contactEventRepositoryProvider).getRecent(),
        hasLength(3),
        reason: 'the summary row, plus one row per 共有先 posted to',
      );
    });

    test('a plain alarm never contacts anyone, contact or not', () async {
      const plain = Alarm(id: 'a1', hour: 7, minute: 0, contact: contact);
      final r = await ringing(plain);

      expect(
        await r.container
            .read(contactDispatcherProvider)
            .fireIfDue(alarm: plain, session: r.session, now: at(minutes: 60)),
        isNull,
        reason: 'contacting is part of 覚悟の設定',
      );
    });

    test('a pledge with nobody on it fires nothing', () async {
      const noContact = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
      );
      final r = await ringing(noContact);

      expect(
        await r.container
            .read(contactDispatcherProvider)
            .fireIfDue(
              alarm: noContact,
              session: r.session,
              now: at(minutes: 60),
            ),
        isNull,
      );
    });

    test('the live 連絡帳 wins over the snapshot at trigger time', () async {
      const fromBook = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
        contact: OversleepContact(
          contactId: 'c1',
          name: '古い名前',
          phone: '090-0000-0000',
          phoneEnabled: true,
        ),
        oversleepTriggerMinutes: 10,
      );
      final r = await ringing(fromBook);
      await r.container
          .read(contactBookRepositoryProvider)
          .save(
            ContactEntry(
              id: 'c1',
              name: '新しい名前',
              phone: '090-0000-0000',
              createdAt: DateTime(2026),
            ),
          );

      final event = await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: fromBook, session: r.session, now: at(minutes: 11));
      expect(event!.contactName, '新しい名前 さん');
    });
  });

  group('Discord の実送信', () {
    /// Every row this session filed under Discord, oldest 共有先 first.
    Future<List<ContactEvent>> discordRows(ProviderContainer c) async =>
        (await c.read(contactEventRepositoryProvider).getRecent())
            .where((e) => e.channel == ContactChannel.discord)
            .where((e) => e.id.contains('-discord-'))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    test('one post and one row per 共有先', () async {
      final r = await ringing(shareOnly, discordUserId: '123456789');

      await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: shareOnly, session: r.session, now: at(minutes: 11));

      expect(sender.posts.map((p) => p.url), [
        'https://discord.com/api/webhooks/1/aaa',
        'https://discord.com/api/webhooks/2/bbb',
      ]);
      expect(
        sender.posts.first.content,
        '<@123456789> が寝坊をしています！\n> 07:00 のアラームを解除できていません。',
        reason: 'the ID is read from the profile at the moment of firing',
      );
      expect(sender.posts.first.recordingPath, isNull);

      final rows = await discordRows(r.container);
      expect(rows.map((e) => e.contactName), ['みんなのサーバー/#一般', '寝坊部/#通報']);
      expect(rows.map((e) => e.detail), ['成功', '成功']);
      expect(
        rows.map((e) => e.id).toSet(),
        hasLength(2),
        reason: 'two 共有先 in the same millisecond must not be one row',
      );
      expect(rows.every((e) => e.sessionId == r.session.id), isTrue);
    });

    test('no Discord ID falls back to the profile name', () async {
      final r = await ringing(shareOnly);
      await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: shareOnly, session: r.session, now: at(minutes: 11));

      expect(
        sender.posts.first.content,
        startsWith('山田花子 が寝坊をしています！'),
      );
    });

    test('a failing 共有先 is recorded and does not stop the other', () async {
      final r = await ringing(
        shareOnly,
        failFor: const {
          'https://discord.com/api/webhooks/1/aaa': DiscordPostResult(
            ok: false,
            statusCode: 404,
          ),
        },
      );

      await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: shareOnly, session: r.session, now: at(minutes: 11));

      expect(
        sender.posts,
        hasLength(2),
        reason: 'a revoked webhook must not silence the room that still works',
      );
      final rows = await discordRows(r.container);
      expect(rows.map((e) => e.detail), ['失敗（HTTP 404）', '成功']);
      expect(
        notifierOf(r.container).posted.single.body,
        'Discord 1件に投稿しました。Discord 1件は送信できませんでした',
      );
    });

    test('the recording is handed to the sender when there is one', () async {
      const withRecording = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
        share: OversleepShare(
          webhookIds: {'w1'},
          recordingPath: '/tmp/a1-recording.m4a',
        ),
        oversleepTriggerMinutes: 10,
      );
      final r = await ringing(withRecording);

      await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(
            alarm: withRecording,
            session: r.session,
            now: at(minutes: 11),
          );

      expect(sender.posts.single.recordingPath, '/tmp/a1-recording.m4a');
    });

    test('an id whose 共有先 was deleted is skipped, not posted', () async {
      final r = await ringing(shareOnly, webhooks: false);

      final event = await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: shareOnly, session: r.session, now: at(minutes: 11));

      expect(event, isNotNull, reason: 'the session still fired');
      expect(sender.posts, isEmpty);
      expect(await discordRows(r.container), isEmpty);
      expect(
        notifierOf(r.container).posted.single.body,
        'Discord 2件への連絡を記録しました',
        reason: 'nothing went out, and nothing claims it did',
      );
    });

    test('both halves: Discord went, the phone call did not', () async {
      const both = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
        contact: contact,
        share: OversleepShare(webhookIds: {'w1'}),
        oversleepTriggerMinutes: 10,
      );
      final r = await ringing(both);

      await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: both, session: r.session, now: at(minutes: 11));

      expect(sender.posts, hasLength(1));
      expect(
        notifierOf(r.container).posted.single.body,
        'Discord 1件に投稿しました。電話は開発中で、記録だけが残ります',
      );
    });
  });

  group('メールの実送信', () {
    const mailContact = OversleepContact(
      name: '田中太郎',
      email: 'taro@example.com',
      emailEnabled: true,
    );
    const mailed = Alarm(
      id: 'a1',
      hour: 7,
      minute: 0,
      kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
      contact: mailContact,
      oversleepTriggerMinutes: 10,
    );

    /// The メール route's **own** row, not the summary row beside it — which
    /// is also filed under email when that is the only route on the alarm.
    /// The suffix on the id is what tells them apart.
    Future<List<ContactEvent>> mailRows(ProviderContainer c) async =>
        (await c.read(contactEventRepositoryProvider).getRecent())
            .where((e) => e.id.endsWith('-email'))
            .toList();

    test('the mail really goes out, with the alarm time in it', () async {
      final r = await ringing(mailed, mailConfigured: true);

      await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: mailed, session: r.session, now: at(minutes: 11));

      final sent = mails.sent.single;
      expect(sent.to, 'taro@example.com');
      expect(sent.subject, oversleepMailSubject);
      expect(sent.body, contains(userName));
      expect(
        sent.body,
        contains('07:00'),
        reason: "the alarm's own time, not the trigger time",
      );

      expect(
        notifierOf(r.container).posted.single.body,
        'メールを送信しました',
        reason: 'and it no longer apologises for a route that worked',
      );
      expect(mailRows(r.container), completion(hasLength(1)));
      expect((await mailRows(r.container)).single.detail, '成功');
    });

    test('a refused mail is a row and a sentence, never a throw', () async {
      final r = await ringing(
        mailed,
        mailConfigured: true,
        mailResult: const SendResult.failure(SendFailure.auth),
      );

      final event = await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: mailed, session: r.session, now: at(minutes: 11));

      expect(event, isNotNull, reason: 'the session still fired');
      expect(
        notifierOf(r.container).posted.single.body,
        'メールは送信できませんでした',
      );
      expect((await mailRows(r.container)).single.detail, '失敗（認証に失敗しました）');
    });

    test('a dead SMTP server does not stop the Discord post beside it',
        () async {
      const both = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
        contact: mailContact,
        share: OversleepShare(webhookIds: {'w1'}),
        oversleepTriggerMinutes: 10,
      );
      final r = await ringing(
        both,
        mailConfigured: true,
        mailResult: const SendResult.failure(SendFailure.network),
      );

      await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: both, session: r.session, now: at(minutes: 11));

      expect(sender.posts, hasLength(1));
      expect(
        notifierOf(r.container).posted.single.body,
        'Discord 1件に投稿しました。メールは送信できませんでした',
      );
    });

    test('メール off on the contact sends nothing at all', () async {
      final r = await ringing(pledged, mailConfigured: true);

      await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: pledged, session: r.session, now: at(minutes: 11));

      expect(mails.sent, isEmpty);
      expect(await mailRows(r.container), isEmpty);
    });
  });

  group('SMS の実送信', () {
    const smsContact = OversleepContact(
      name: '田中太郎',
      phone: '090-1234-5678',
      smsEnabled: true,
    );
    const texted = Alarm(
      id: 'a1',
      hour: 7,
      minute: 0,
      kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
      contact: smsContact,
      oversleepTriggerMinutes: 10,
    );

    Future<ContactEvent?> smsRow(ProviderContainer c) async =>
        (await c.read(contactEventRepositoryProvider).getRecent())
            .where((e) => e.id.endsWith('-sms'))
            .firstOrNull;

    test('the text really goes out, to the normalised number', () async {
      final r = await ringing(texted);

      await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: texted, session: r.session, now: at(minutes: 11));

      final sent = smsSenderOf(r.container).sent.single;
      expect(sent.to, '09012345678', reason: 'the radio wants digits');
      expect(sent.body, contains(userName));
      expect(sent.body, contains('07:00'));
      expect(sent.body, isNot(contains('【Wake or Pay】')));

      expect(notifierOf(r.container).posted.single.body, 'SMSを送信しました');
      expect((await smsRow(r.container))!.detail, '成功');
    });

    test('a refused permission is a row and a sentence, never a throw',
        () async {
      final r = await ringing(
        texted,
        smsResult: const SendResult.failure(SendFailure.permission),
      );

      final event = await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: texted, session: r.session, now: at(minutes: 11));

      expect(event, isNotNull);
      expect(notifierOf(r.container).posted.single.body, 'SMSは送信できませんでした');
      expect((await smsRow(r.container))!.detail, '失敗（権限がありません）');
    });

    test('SMS goes before メール, and both are reported', () async {
      const both = OversleepContact(
        name: '田中太郎',
        phone: '090-1234-5678',
        email: 'taro@example.com',
        smsEnabled: true,
        emailEnabled: true,
      );
      const alarm = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
        contact: both,
        oversleepTriggerMinutes: 10,
      );
      final r = await ringing(alarm, mailConfigured: true);

      await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: alarm, session: r.session, now: at(minutes: 11));

      expect(smsSenderOf(r.container).sent, hasLength(1));
      expect(mails.sent, hasLength(1));
      expect(
        notifierOf(r.container).posted.single.body,
        'SMS・メールを送信しました',
        reason: 'the loudest route is named first, as everywhere else',
      );
    });

    test('SMS off on the contact texts nobody', () async {
      final r = await ringing(pledged);

      await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: pledged, session: r.session, now: at(minutes: 11));

      expect(smsSenderOf(r.container).sent, isEmpty);
      expect(await smsRow(r.container), isNull);
    });
  });

  group('channelsFor', () {
    test('電話 → SMS → メール → Discord, and only what is live', () {
      expect(channelsFor(contact: contact), [ContactChannel.phone]);
      expect(
        channelsFor(
          contact: const OversleepContact(
            name: 'x',
            phone: '090-0000-0000',
            email: 'a@b.c',
            phoneEnabled: true,
            smsEnabled: true,
            emailEnabled: true,
          ),
          share: share,
        ),
        [
          ContactChannel.phone,
          ContactChannel.sms,
          ContactChannel.email,
          ContactChannel.discord,
        ],
      );
      expect(channelsFor(share: share), [ContactChannel.discord]);
      expect(channelsFor(), isEmpty);
    });

    test('the row is filed under the loudest route it took', () {
      expect(channelFor(contact, null), ContactChannel.phone);
      expect(
        channelFor(
          const OversleepContact(name: 'x', email: 'a@b.c', emailEnabled: true),
          null,
        ),
        ContactChannel.email,
      );
      expect(
        channelFor(
          const OversleepContact(name: 'x', phone: '090', smsEnabled: true),
          share,
        ),
        ContactChannel.sms,
        reason: 'a text beats a room',
      );
      expect(channelFor(null, share), ContactChannel.discord);
      expect(channelFor(const OversleepContact(name: 'x'), null),
          ContactChannel.log);
      expect(
        channelFor(
          const OversleepContact(name: 'x', phone: '   ', phoneEnabled: true),
          null,
        ),
        ContactChannel.log,
        reason: 'whitespace is not a phone number',
      );
      expect(
        channelFor(
          const OversleepContact(
            name: 'x',
            phone: '090-0000-0000',
            email: 'a@b.c',
            emailEnabled: true,
          ),
          null,
        ),
        ContactChannel.email,
        reason: 'a number nobody switched on is not a route',
      );
    });
  });

  group('detailFor', () {
    final at = DateTime(2026, 8, 27, 6, 5);

    test('the personal half alone, each route with its mode', () {
      const both = OversleepContact(
        name: '母',
        phone: '090-0000-0000',
        email: 'haha@example.com',
        phoneEnabled: true,
        smsEnabled: true,
        emailEnabled: true,
        messageMode: MessageMode.custom,
        message: 'おきて',
      );
      expect(
        detailFor(at, contact: both, userName: userName),
        '電話 / SMS（カスタムメッセージ）：おきて / メール（カスタムメッセージ）：おきて',
        reason: 'one message the user wrote once, on both written routes',
      );
    });

    test('the group half alone', () {
      expect(
        detailFor(at, share: share, userName: userName),
        'Discord 2件（デフォルト）：06:05 のアラームを解除できていません。',
        reason: 'the post already says who it is about on the line above',
      );
      expect(
        detailFor(
          at,
          share: share.copyWith(
            messageMode: MessageMode.custom,
            message: '起きろ',
            recordingPath: '/tmp/a.m4a',
          ),
          userName: userName,
        ),
        'Discord 2件（カスタムメッセージ）：起きろ＋録音',
      );
    });

    test('both halves, in the order the routes would be taken', () {
      expect(
        detailFor(
          at,
          contact: const OversleepContact(
            name: '母',
            phone: '090-0000-0000',
            email: 'haha@example.com',
            phoneEnabled: true,
            smsEnabled: true,
            emailEnabled: true,
          ),
          share: share,
          userName: userName,
        ),
        '電話'
        ' / SMS（デフォルト）：山田花子 さんは 06:05 のアラームを解除できていません。寝坊しています。'
        ' / メール（デフォルト）：【Wake or Pay】山田花子 さんは 06:05 の'
        'アラームを解除できていません。寝坊しています。'
        ' / Discord 2件（デフォルト）：06:05 のアラームを解除できていません。',
      );
    });

    test('the default sentence names the app user, never the contact', () {
      const auto = OversleepContact(
        name: '母',
        email: 'haha@example.com',
        emailEnabled: true,
      );
      expect(
        detailFor(at, contact: auto, userName: userName),
        'メール（デフォルト）：【Wake or Pay】山田花子 さんは 06:05 の'
        'アラームを解除できていません。寝坊しています。',
        reason: '母 is the one being told, not the one oversleeping',
      );
      expect(
        detailFor(at, contact: auto, userName: ''),
        'メール（デフォルト）：【Wake or Pay】$oversleepUserNameFallback さんは 06:05 の'
        'アラームを解除できていません。寝坊しています。',
        reason: 'no name set still must not fall back to the contact',
      );
    });

    test('nothing switched on records nothing sent', () {
      expect(
        detailFor(at, contact: const OversleepContact(name: 'x'),
            userName: userName),
        isNull,
      );
      expect(
        detailFor(
          at,
          contact: const OversleepContact(name: 'x', phone: '090-0000-0000'),
          userName: userName,
        ),
        isNull,
        reason: 'a number with its toggle off goes nowhere',
      );
      expect(
        detailFor(at, share: const OversleepShare(), userName: userName),
        isNull,
        reason: 'a share with nowhere to post is not a share',
      );
      expect(detailFor(at, userName: userName), isNull);
    });
  });

  group('under snooze', () {
    test('the reset clock mode pushes the trigger out with the ring', () async {
      const resets = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        snooze: Snooze(intervalMinutes: 5, maxCount: 3),
        kakugo: Kakugo(ratePerMinute: 100, cap: 2000, snoozeResetsClock: true),
        contact: contact,
        oversleepTriggerMinutes: 10,
      );
      final r = await ringing(resets);
      final service =
          r.container.read(alarmServiceProvider) as FakeAlarmService;
      await service.snooze(r.session.id, now: at(minutes: 2));

      final snoozed = (await r.container
          .read(alarmSessionRepositoryProvider)
          .getById(r.session.id))!;
      final dispatcher = r.container.read(contactDispatcherProvider);

      // Without the snooze this would have fired at 7:11. The re-ring is at
      // 7:07, so it is 7:18 now.
      expect(
        await dispatcher.fireIfDue(
          alarm: resets,
          session: snoozed,
          now: at(minutes: 11),
        ),
        isNull,
      );
      expect(
        await dispatcher.fireIfDue(
          alarm: resets,
          session: snoozed,
          now: at(minutes: 18),
        ),
        isNotNull,
      );
    });

    test('the continuous clock mode does not stop the timer', () async {
      const continuous = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        snooze: Snooze(intervalMinutes: 5, maxCount: 3),
        kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
        contact: contact,
        oversleepTriggerMinutes: 10,
      );
      final r = await ringing(continuous);
      final service =
          r.container.read(alarmServiceProvider) as FakeAlarmService;
      await service.snooze(r.session.id, now: at(minutes: 2));

      final snoozed = (await r.container
          .read(alarmSessionRepositoryProvider)
          .getById(r.session.id))!;

      expect(
        await r.container
            .read(contactDispatcherProvider)
            .fireIfDue(
              alarm: continuous,
              session: snoozed,
              now: at(minutes: 11),
            ),
        isNotNull,
        reason: 'still 7:11, snooze or no snooze',
      );
    });
  });
}
