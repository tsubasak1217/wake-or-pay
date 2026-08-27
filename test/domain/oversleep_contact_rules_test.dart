import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/oversleep_contact_rules.dart';

final firedAt = DateTime(2026, 8, 27, 7);
DateTime at({int minutes = 0, int seconds = 0}) =>
    firedAt.add(Duration(minutes: minutes, seconds: seconds));

const taro = OversleepContact(name: '田中太郎', phone: '090-0000-0000');

/// The phrase every sentence below is built on, spelled out once so a test
/// reads the same way the screen does.
const target = '田中太郎 さん';

const pledge = Kakugo(ratePerMinute: 100, cap: 1000);

/// The alarm the rules are read off since 改訂4: the delay lives here, and so
/// does the pledge without which nobody is told anything.
Alarm alarm({
  OversleepContact? contact = taro,
  OversleepShare? share,
  Kakugo? kakugo = pledge,
  int? triggerMinutes = 10,
}) => Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  kakugo: kakugo,
  contact: contact,
  share: share,
  oversleepTriggerMinutes: triggerMinutes,
);

AlarmSession session({
  int graceMinutes = 1,
  Kakugo? kakugo = pledge,
  List<DateTime> snoozes = const [],
  DateTime? currentRingAt,
}) => AlarmSession(
  id: 's1',
  alarmId: 'a1',
  firedAt: firedAt,
  graceMinutes: graceMinutes,
  kakugoSnapshot: kakugo,
  snoozes: snoozes,
  currentRingAt: currentRingAt,
);

void main() {
  group('contactTriggerAt', () {
    test('grace first, then the chosen delay', () {
      // 7:00 + 1 minute of grace + 10 = 7:11.
      expect(contactTriggerAt(session(), alarm()), at(minutes: 11));
      expect(
        contactTriggerAt(session(graceMinutes: 5), alarm()),
        at(minutes: 15),
      );
    });

    test('nobody to contact, nothing to schedule', () {
      expect(contactTriggerAt(session(), null), isNull);
      expect(
        contactTriggerAt(session(), alarm(contact: null)),
        isNull,
        reason: 'a pledge with nobody on it tells nobody',
      );
      expect(
        contactTriggerAt(
          session(),
          alarm(contact: const OversleepContact(name: '  ')),
        ),
        isNull,
        reason: 'a nameless contact is not a contact',
      );
      expect(
        contactTriggerAt(session(), alarm(kakugo: null)),
        isNull,
        reason: 'contacting is part of 覚悟の設定',
      );
    });

    test('a hand edited delay cannot escape 0-60', () {
      expect(
        contactTriggerAt(session(), alarm(triggerMinutes: 9999)),
        at(minutes: 1 + maxContactTriggerMinutes),
      );
      expect(
        contactTriggerAt(session(), alarm(triggerMinutes: -5)),
        at(minutes: 1 + minContactTriggerMinutes),
      );
    });

    test('a row with no delay of its own falls back to the default', () {
      expect(
        contactTriggerAt(session(), alarm(triggerMinutes: null)),
        at(minutes: 1 + defaultContactTriggerMinutes),
      );
    });

    test('0 means the moment the grace runs out', () {
      expect(minContactTriggerMinutes, 0);
      // 7:00 + 1 minute of grace + 0 = 7:01, the first billable second.
      expect(
        contactTriggerAt(session(), alarm(triggerMinutes: 0)),
        at(minutes: 1),
      );
      expect(
        contactTriggerAt(session(graceMinutes: 5), alarm(triggerMinutes: 0)),
        at(minutes: 5),
      );
    });

    test('a share with no contact is scheduled just the same', () {
      // 改訂4: an alarm that only announces itself to a Discord room is every
      // bit as much a notification as one that calls a person.
      expect(
        contactTriggerAt(
          session(),
          alarm(
            contact: null,
            share: const OversleepShare(webhookIds: {'w1'}),
          ),
        ),
        at(minutes: 11),
      );
      expect(
        contactTriggerAt(
          session(),
          alarm(contact: null, share: const OversleepShare()),
        ),
        isNull,
        reason: 'a share with nowhere to post is not a share',
      );
    });

    group('under snooze', () {
      final snoozed = [at(minutes: 2)];
      final reRing = at(minutes: 7);

      test('規定時刻から加算し続ける: the timer does not stop', () {
        final s = session(snoozes: snoozed, currentRingAt: reRing);
        expect(
          contactTriggerAt(s, alarm()),
          at(minutes: 11),
          reason: 'still counted from the scheduled time',
        );
      });

      test('次に鳴る時刻を起点にし直す: the timer follows the re-ring', () {
        final s = session(
          kakugo: const Kakugo(
            ratePerMinute: 100,
            cap: 1000,
            snoozeResetsClock: true,
          ),
          snoozes: snoozed,
          currentRingAt: reRing,
        );
        expect(contactTriggerAt(s, alarm()), at(minutes: 18));
      });

      test('a plain alarm always counts from firedAt', () {
        final s = session(
          kakugo: null,
          snoozes: snoozed,
          currentRingAt: reRing,
        );
        expect(contactTriggerAt(s, alarm()), at(minutes: 11));
      });
    });
  });

  group('contactRemaining and contactIsDue', () {
    test('counts down and then sits at zero', () {
      expect(
        contactRemaining(firedAt, session(), alarm()),
        const Duration(minutes: 11),
      );
      expect(
        contactRemaining(at(minutes: 8, seconds: 30), session(), alarm()),
        const Duration(minutes: 2, seconds: 30),
      );
      expect(
        contactRemaining(at(minutes: 11), session(), alarm()),
        Duration.zero,
      );
      expect(
        contactRemaining(at(minutes: 90), session(), alarm()),
        Duration.zero,
      );
      expect(contactRemaining(firedAt, session(), null), isNull);
    });

    test('due exactly on the minute, not a second before', () {
      expect(
        contactIsDue(at(minutes: 10, seconds: 59), session(), alarm()),
        isFalse,
      );
      expect(contactIsDue(at(minutes: 11), session(), alarm()), isTrue);
      expect(contactIsDue(at(minutes: 600), session(), null), isFalse);
    });
  });

  group('cueFor', () {
    test('each mark, once it is reached', () {
      expect(cueFor(const Duration(minutes: 10)), isNull);
      expect(
        cueFor(const Duration(minutes: 3, seconds: 1)),
        isNull,
        reason: 'not yet at three minutes',
      );
      expect(cueFor(const Duration(minutes: 3)), ContactSpeechCue.threeMinutes);
      expect(
        cueFor(const Duration(minutes: 1, seconds: 1)),
        ContactSpeechCue.threeMinutes,
      );
      expect(cueFor(const Duration(minutes: 1)), ContactSpeechCue.oneMinute);
      expect(cueFor(const Duration(seconds: 31)), ContactSpeechCue.oneMinute);
      expect(
        cueFor(const Duration(seconds: 30)),
        ContactSpeechCue.thirtySeconds,
      );
      expect(
        cueFor(const Duration(seconds: 1)),
        ContactSpeechCue.thirtySeconds,
      );
      expect(cueFor(Duration.zero), ContactSpeechCue.sent);
      expect(cueFor(const Duration(seconds: -5)), ContactSpeechCue.sent);
    });

    test('a second-by-second countdown says each line exactly once', () {
      // What the ringing screen does: keep a set, speak the first time a cue
      // appears in it. Ticking every second from four minutes out must produce
      // three minutes, one minute, thirty seconds and sent — in that order.
      final said = <ContactSpeechCue>{};
      final order = <ContactSpeechCue>[];
      for (var s = 240; s >= 0; s--) {
        final cue = cueFor(Duration(seconds: s));
        if (cue != null && said.add(cue)) order.add(cue);
      }
      expect(order, [
        ContactSpeechCue.threeMinutes,
        ContactSpeechCue.oneMinute,
        ContactSpeechCue.thirtySeconds,
        ContactSpeechCue.sent,
      ]);
    });
  });

  group('oversleepTargetLabel', () {
    test('the person, the room, or both', () {
      expect(oversleepTargetLabel(contactName: '田中太郎'), '田中太郎 さん');
      expect(oversleepTargetLabel(webhookCount: 2), 'Discord 2件');
      expect(
        oversleepTargetLabel(contactName: '田中太郎', webhookCount: 2),
        '田中太郎 さん と Discord 2件',
      );
    });

    test('nobody at all is the empty phrase', () {
      expect(oversleepTargetLabel(), '');
      expect(oversleepTargetLabel(contactName: '   '), '');
      expect(oversleepTargetLabel(webhookCount: 0), '');
    });

    test('the honorific rides with the name and never with the room', () {
      expect(
        oversleepTargetLabel(webhookCount: 1),
        isNot(contains('さん')),
        reason: '「Discord 1件 さん」 would be nonsense',
      );
    });

    test('an alarm names only what it would actually notify', () {
      const share = OversleepShare(webhookIds: {'w1', 'w2'});
      expect(
        oversleepTargetLabelForAlarm(alarm(share: share), const []),
        '田中太郎 さん と Discord 2件',
      );
      expect(
        oversleepTargetLabelForAlarm(alarm(contact: null, share: share), const [
        ]),
        'Discord 2件',
      );
      expect(oversleepTargetLabelForAlarm(alarm(), const []), '田中太郎 さん');
      expect(
        oversleepTargetLabelForAlarm(alarm(kakugo: null, share: share), const []),
        '',
        reason: 'no pledge, no notification, so nobody to name',
      );
    });

    test('the label reads the live 連絡帳, not the snapshot', () {
      final book = [
        ContactEntry(
          id: 'c1',
          name: '田中太郎（部長）',
          phone: '090-0000-0000',
          createdAt: DateTime(2026),
        ),
      ];
      final withId = alarm(
        contact: const OversleepContact(
          contactId: 'c1',
          name: '古い名前',
          phone: '090-0000-0000',
        ),
      );
      expect(oversleepTargetLabelForAlarm(withId, book), '田中太郎（部長） さん');
    });
  });

  group('wording', () {
    test('the countdown line matches the spec sentence', () {
      expect(
        contactCountdownLine(const Duration(minutes: 2, seconds: 30), target),
        'あと 2:30 で 田中太郎 さんに連絡が行きます',
      );
      expect(contactCountdownLine(Duration.zero, target), '田中太郎 さんに連絡が行きました');
    });

    test('a share-only alarm needs no further plumbing to read right', () {
      final shareOnly = oversleepTargetLabelForAlarm(
        alarm(contact: null, share: const OversleepShare(webhookIds: {'w1',
          'w2'})),
        const [],
      );
      expect(
        contactCountdownLine(const Duration(minutes: 2, seconds: 30),
            shareOnly),
        'あと 2:30 で Discord 2件に連絡が行きます',
      );
      expect(
        contactSpeechText(ContactSpeechCue.sent, shareOnly),
        'Discord 2件に連絡しました',
      );
    });

    test('both halves are named in one sentence', () {
      final both = oversleepTargetLabelForAlarm(
        alarm(share: const OversleepShare(webhookIds: {'w1'})),
        const [],
      );
      expect(
        contactCountdownLine(const Duration(minutes: 1), both),
        'あと 1:00 で 田中太郎 さん と Discord 1件に連絡が行きます',
      );
      expect(
        contactSpeechText(ContactSpeechCue.start, both, triggerMinutes: 7),
        'このまま寝ていると、7分後に 田中太郎 さん と Discord 1件に連絡が行きます',
      );
    });

    test('long delays read as hours and minutes, not as 65:00', () {
      expect(contactCountdown(const Duration(minutes: 65)), '1時間5分');
      expect(contactCountdown(const Duration(seconds: 9)), '0:09');
      expect(contactCountdown(const Duration(seconds: -9)), '0:00');
    });

    test('the spoken lines avoid numerals a TTS engine has to guess at', () {
      expect(
        contactSpeechText(ContactSpeechCue.threeMinutes, target),
        'あと3分で 田中太郎 さんに連絡が行きます',
      );
      expect(
        contactSpeechText(ContactSpeechCue.oneMinute, target),
        'あと1分で 田中太郎 さんに連絡が行きます',
      );
      expect(
        contactSpeechText(ContactSpeechCue.thirtySeconds, target),
        'あと30秒で 田中太郎 さんに連絡が行きます',
      );
      expect(
        contactSpeechText(ContactSpeechCue.sent, target),
        '田中太郎 さんに連絡しました',
      );
      expect(
        contactSpeechText(ContactSpeechCue.start, target, triggerMinutes: 10),
        contains('10分後に 田中太郎 さんに連絡が行きます'),
      );
    });

    test('the opening line cannot promise a delay the alarm cannot hold', () {
      expect(
        contactSpeechText(ContactSpeechCue.start, target, triggerMinutes: 9999),
        contains('$maxContactTriggerMinutes分後に'),
      );
    });

    test('the notification says what each half actually did', () {
      expect(contactSentNotificationText(target).title, '田中太郎 さんへの連絡');

      expect(
        contactSentNotificationText(target, failedRoutes: const ['電話']).body,
        '電話をかけられませんでした',
        reason: 'a call nobody placed must never read as one that was',
      );
      expect(
        contactSentNotificationText(target, sentRoutes: const ['電話']).body,
        '電話をかけました',
        reason: '「電話を送信しました」 is not a sentence',
      );
      expect(
        contactSentNotificationText(target, discordSent: 2).body,
        'Discord 2件に投稿しました',
        reason: 'and a post that really went out must not deny itself',
      );
      expect(
        contactSentNotificationText(target, sentRoutes: const ['メール']).body,
        'メールを送信しました',
      );
      expect(
        contactSentNotificationText(target, failedRoutes: const ['メール']).body,
        'メールは送信できませんでした',
        reason: 'and a mail that bounced must not read as one that arrived',
      );
      expect(
        contactSentNotificationText(
          target,
          discordSent: 1,
          discordFailed: 1,
          sentRoutes: const ['電話', 'SMS'],
          failedRoutes: const ['メール'],
        ).body,
        'Discord 1件に投稿しました。Discord 1件は送信できませんでした。'
        '電話をかけました。SMSを送信しました。メールは送信できませんでした',
      );
      expect(
        contactSentNotificationText(target).body,
        '田中太郎 さんへの連絡を記録しました',
        reason: 'no route left — every 共有先 on it had been deleted',
      );
    });

    group('oversleepCallLine', () {
      ContactEvent row(String suffix, String? detail) => ContactEvent(
        id: 'contact-1-s1$suffix',
        sessionId: 's1',
        firedAt: DateTime(2026, 8, 27, 7, 5),
        contactName: '田中太郎',
        channel: ContactChannel.phone,
        detail: detail,
      );

      test('nothing at all until a call has been attempted', () {
        expect(oversleepCallLine(const []), isNull);
        expect(
          oversleepCallLine([row('', '電話 / メール…')]),
          isNull,
          reason: 'the summary row is not the call',
        );
        expect(oversleepCallLine([row('-email', '成功')]), isNull);
      });

      test('a call that connected, and one that did not', () {
        expect(oversleepCallLine([row('-phone', '成功')]), '田中太郎 に電話をかけました');
        expect(
          oversleepCallLine([row('-phone', '失敗（権限がありません）')]),
          '田中太郎 に電話をかけられませんでした',
          reason: 'a call that never went out must not read as one that did',
        );
      });
    });
  });

  group('連絡帳との突き合わせ', () {
    ContactEntry entry({
      String name = '田中太郎',
      String? phone = '090-0000-0000',
      String? email = 'taro@example.com',
    }) => ContactEntry(
      id: 'c1',
      name: name,
      phone: phone,
      email: email,
      createdAt: DateTime(2026),
    );

    const snapshot = OversleepContact(
      contactId: 'c1',
      name: '田中太郎',
      phone: '090-0000-0000',
      email: 'taro@example.com',
      phoneEnabled: true,
      emailEnabled: true,
    );

    test('the live entry wins over the snapshot the alarm carries', () {
      final live = resolveOversleepContact(snapshot, [
        entry(name: '田中太郎（部長）', email: 'bucho@example.com'),
      ]);
      expect(live.name, '田中太郎（部長）');
      expect(live.email, 'bucho@example.com');
      expect(live.phone, '090-0000-0000', reason: 'unchanged in the book');
      expect(live.contactId, 'c1');
    });

    test('nothing else on the contact is touched', () {
      const rich = OversleepContact(
        contactId: 'c1',
        name: '古い名前',
        phone: '090-0000-0000',
        messageMode: MessageMode.custom,
        message: '起こして',
      );
      final live = resolveOversleepContact(rich, [entry()]);
      expect(live.messageMode, MessageMode.custom);
      expect(live.message, '起こして');
    });

    test('a deleted entry leaves the snapshot alone', () {
      expect(resolveOversleepContact(snapshot, const []), snapshot);
    });

    test('a contact that never came from the book is untouched', () {
      const loose = OversleepContact(name: '誰か', phone: '090-1111-1111');
      expect(resolveOversleepContact(loose, [entry()]), loose);
    });

    test('an address deleted in the book switches its route off', () {
      final live = resolveOversleepContact(snapshot, [entry(phone: null)]);
      expect(live.phone, isNull);
      expect(live.phoneEnabled, isFalse, reason: 'nothing left to call');
      expect(live.emailEnabled, isTrue);
      expect(live.willPhone, isFalse);
    });

    test('a number deleted in the book takes the SMS with it', () {
      const texting = OversleepContact(
        contactId: 'c1',
        name: '田中太郎',
        phone: '090-0000-0000',
        smsEnabled: true,
      );
      final live = resolveOversleepContact(texting, [entry(phone: null)]);
      expect(live.smsEnabled, isFalse, reason: 'nothing left to text');
      expect(live.willSms, isFalse);
    });

    test('an address added in the book does not switch its route on', () {
      const mailOnly = OversleepContact(
        contactId: 'c1',
        name: '田中太郎',
        email: 'taro@example.com',
        emailEnabled: true,
      );
      final live = resolveOversleepContact(mailOnly, [entry()]);
      expect(live.phone, '090-0000-0000', reason: 'now reachable');
      expect(live.phoneEnabled, isFalse, reason: 'but the user never asked');
      expect(live.smsEnabled, isFalse);
    });

    test('resolveAlarmContact leaves a contactless alarm alone', () {
      const plain = Alarm(id: 'a', hour: 7, minute: 0);
      expect(resolveAlarmContact(plain, [entry()]), plain);
    });

    test('the countdown line reads the resolved name', () {
      final live = resolveOversleepContact(snapshot, [entry(name: '新しい名前')]);
      expect(
        contactCountdownLine(
          const Duration(minutes: 1),
          oversleepTargetLabel(contactName: live.name),
        ),
        'あと 1:00 で 新しい名前 さんに連絡が行きます',
      );
    });
  });
}
