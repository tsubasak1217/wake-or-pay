import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/alarm_service.dart';
import 'package:wake_or_pay/services/oversleep_notifier.dart';

import '../helpers.dart';

const contact = OversleepContact(
  name: '田中太郎',
  phone: '090-0000-0000',
  phoneEnabled: true,
  triggerMinutesAfterGrace: 10,
);

const pledged = Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
  contact: contact,
);

final firedAt = DateTime(2026, 8, 27, 7);
DateTime at({int minutes = 0, int seconds = 0}) =>
    firedAt.add(Duration(minutes: minutes, seconds: seconds));

/// The app's own user: the subject of every default sentence below. Deliberately
/// not the contact's name, which is who the message goes *to*.
const userName = '山田花子';

Future<({ProviderContainer container, AlarmSession session})> ringing(
  Alarm alarm, {
  String user = userName,
}) async {
  final container = await testContainer(
    prefs: {if (user.isNotEmpty) 'profile.userName': user},
    extra: [fakeAlarmServiceOverride()],
  );
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

        expect(event!.contactName, '田中太郎');
        expect(event.sessionId, r.session.id);
        expect(event.firedAt, at(minutes: 11));
        expect(
          event.channel,
          ContactChannel.phone,
          reason: 'a number is loudest',
        );
        expect(
          event.detail,
          '電話（自動音声）：山田花子 さんは 07:00 のアラームを解除できていません。寝坊しています。',
          reason:
              'the route, the mode, and the words — the app user is the '
              'subject, 田中太郎 is only who hears it',
        );

        final stored = await r.container
            .read(contactEventRepositoryProvider)
            .getRecent();
        expect(stored.single, event);

        final posted = notifierOf(r.container).posted.single;
        expect(posted.body, '田中太郎 さんへの連絡が送信されました（開発中：実際には送信していません）');
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

    test('a pledge with no contact fires nothing', () async {
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

    test(
      'the channel falls back from phone to mail to a bare record',
      () async {
        expect(channelFor(contact), ContactChannel.phone);
        expect(
          channelFor(
            const OversleepContact(
              name: 'x',
              email: 'a@b.c',
              emailEnabled: true,
            ),
          ),
          ContactChannel.email,
        );
        expect(
          channelFor(const OversleepContact(name: 'x')),
          ContactChannel.log,
        );
        expect(
          channelFor(
            const OversleepContact(name: 'x', phone: '   ', phoneEnabled: true),
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
          ),
          ContactChannel.email,
          reason: 'a number nobody switched on is not a route',
        );
      },
    );

    test('both routes at once are both recorded, each with its mode', () async {
      const both = OversleepContact(
        name: '母',
        phone: '090-0000-0000',
        email: 'haha@example.com',
        phoneEnabled: true,
        emailEnabled: true,
        phoneMode: PhoneMode.custom,
        recordingPath: '/tmp/a.m4a',
        mailMode: MailMode.custom,
        mailMessage: 'おきて',
      );
      expect(channelsFor(both), [ContactChannel.phone, ContactChannel.email]);
      expect(
        detailFor(both, DateTime(2026, 8, 27, 6, 5), userName: userName),
        '電話（カスタム録音） / メール（カスタムメッセージ）：おきて',
      );
    });

    test('the default modes name themselves and carry the app sentence', () {
      const auto = OversleepContact(
        name: '母',
        email: 'haha@example.com',
        emailEnabled: true,
      );
      expect(
        detailFor(auto, DateTime(2026, 8, 27, 6, 5), userName: userName),
        'メール（デフォルト）：【Wake or Pay】山田花子 さんは 06:05 の'
        'アラームを解除できていません。寝坊しています。',
        reason: '母 is the one being told, not the one oversleeping',
      );
      expect(
        detailFor(auto, DateTime(2026, 8, 27, 6, 5), userName: ''),
        'メール（デフォルト）：【Wake or Pay】$oversleepUserNameFallback さんは 06:05 の'
        'アラームを解除できていません。寝坊しています。',
        reason: 'no name set still must not fall back to the contact',
      );
    });

    test('a contact with no route switched on records nothing sent', () async {
      expect(
        detailFor(
          const OversleepContact(name: 'x'),
          DateTime(2026, 8, 27),
          userName: userName,
        ),
        isNull,
      );
      expect(
        detailFor(
          const OversleepContact(name: 'x', phone: '090-0000-0000'),
          DateTime(2026, 8, 27),
          userName: userName,
        ),
        isNull,
        reason: 'a number with its toggle off goes nowhere',
      );
    });

    test('the reset clock mode pushes the trigger out with the ring', () async {
      const resets = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        snooze: Snooze(intervalMinutes: 5, maxCount: 3),
        kakugo: Kakugo(ratePerMinute: 100, cap: 2000, snoozeResetsClock: true),
        contact: contact,
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
