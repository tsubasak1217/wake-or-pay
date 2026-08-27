import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/oversleep_contact_rules.dart';

final firedAt = DateTime(2026, 8, 27, 7);
DateTime at({int minutes = 0, int seconds = 0}) =>
    firedAt.add(Duration(minutes: minutes, seconds: seconds));

const contact = OversleepContact(
  name: '田中太郎',
  phone: '090-0000-0000',
  triggerMinutesAfterGrace: 10,
);

AlarmSession session({
  int graceMinutes = 1,
  Kakugo? kakugo = const Kakugo(ratePerMinute: 100, cap: 1000),
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
      expect(contactTriggerAt(session(), contact), at(minutes: 11));
      expect(
        contactTriggerAt(session(graceMinutes: 5), contact),
        at(minutes: 15),
      );
    });

    test('nobody to contact, nothing to schedule', () {
      expect(contactTriggerAt(session(), null), isNull);
      expect(
        contactTriggerAt(session(), const OversleepContact(name: '  ')),
        isNull,
        reason: 'a nameless contact is not a contact',
      );
    });

    test('a hand edited delay cannot escape 0-60', () {
      expect(
        contactTriggerAt(
          session(),
          const OversleepContact(name: 'x', triggerMinutesAfterGrace: 9999),
        ),
        at(minutes: 1 + maxContactTriggerMinutes),
      );
      expect(
        contactTriggerAt(
          session(),
          const OversleepContact(name: 'x', triggerMinutesAfterGrace: -5),
        ),
        at(minutes: 1 + minContactTriggerMinutes),
      );
    });

    test('0 means the moment the grace runs out', () {
      expect(minContactTriggerMinutes, 0);
      // 7:00 + 1 minute of grace + 0 = 7:01, the first billable second.
      expect(
        contactTriggerAt(
          session(),
          const OversleepContact(name: 'x', triggerMinutesAfterGrace: 0),
        ),
        at(minutes: 1),
      );
      expect(
        contactTriggerAt(
          session(graceMinutes: 5),
          const OversleepContact(name: 'x', triggerMinutesAfterGrace: 0),
        ),
        at(minutes: 5),
      );
    });

    group('under snooze', () {
      final snoozed = [at(minutes: 2)];
      final reRing = at(minutes: 7);

      test('規定時刻から加算し続ける: the timer does not stop', () {
        final s = session(snoozes: snoozed, currentRingAt: reRing);
        expect(
          contactTriggerAt(s, contact),
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
        expect(contactTriggerAt(s, contact), at(minutes: 18));
      });

      test('a plain alarm always counts from firedAt', () {
        final s = session(
          kakugo: null,
          snoozes: snoozed,
          currentRingAt: reRing,
        );
        expect(contactTriggerAt(s, contact), at(minutes: 11));
      });
    });
  });

  group('contactRemaining and contactIsDue', () {
    test('counts down and then sits at zero', () {
      expect(
        contactRemaining(firedAt, session(), contact),
        const Duration(minutes: 11),
      );
      expect(
        contactRemaining(at(minutes: 8, seconds: 30), session(), contact),
        const Duration(minutes: 2, seconds: 30),
      );
      expect(
        contactRemaining(at(minutes: 11), session(), contact),
        Duration.zero,
      );
      expect(
        contactRemaining(at(minutes: 90), session(), contact),
        Duration.zero,
      );
      expect(contactRemaining(firedAt, session(), null), isNull);
    });

    test('due exactly on the minute, not a second before', () {
      expect(
        contactIsDue(at(minutes: 10, seconds: 59), session(), contact),
        isFalse,
      );
      expect(contactIsDue(at(minutes: 11), session(), contact), isTrue);
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

  group('wording', () {
    test('the countdown line matches the spec sentence', () {
      expect(
        contactCountdownLine(const Duration(minutes: 2, seconds: 30), contact),
        'あと 2:30 で 田中太郎 さんに連絡が行きます',
      );
      expect(contactCountdownLine(Duration.zero, contact), '田中太郎 さんに連絡が行きました');
    });

    test('long delays read as hours and minutes, not as 65:00', () {
      expect(contactCountdown(const Duration(minutes: 65)), '1時間5分');
      expect(contactCountdown(const Duration(seconds: 9)), '0:09');
      expect(contactCountdown(const Duration(seconds: -9)), '0:00');
    });

    test('the spoken lines avoid numerals a TTS engine has to guess at', () {
      expect(
        contactSpeechText(ContactSpeechCue.threeMinutes, contact),
        'あと3分で 田中太郎 さんに連絡が行きます',
      );
      expect(
        contactSpeechText(ContactSpeechCue.oneMinute, contact),
        'あと1分で 田中太郎 さんに連絡が行きます',
      );
      expect(
        contactSpeechText(ContactSpeechCue.thirtySeconds, contact),
        'あと30秒で 田中太郎 さんに連絡が行きます',
      );
      expect(
        contactSpeechText(ContactSpeechCue.sent, contact),
        '田中太郎 さんに連絡しました',
      );
      expect(
        contactSpeechText(ContactSpeechCue.start, contact),
        contains('10分後に 田中太郎 さんに連絡が行きます'),
      );
    });

    test('the notification admits that nothing was sent', () {
      final text = contactSentNotificationText('田中太郎');
      expect(text.body, '田中太郎 さんへの連絡が送信されました（開発中：実際には送信していません）');
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
        mailMode: MailMode.custom,
        mailMessage: '起こして',
        phoneMode: PhoneMode.custom,
        recordingPath: '/tmp/a.m4a',
        triggerMinutesAfterGrace: 12,
      );
      final live = resolveOversleepContact(rich, [entry()]);
      expect(live.mailMessage, '起こして');
      expect(live.recordingPath, '/tmp/a.m4a');
      expect(live.triggerMinutesAfterGrace, 12);
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
    });

    test('resolveAlarmContact leaves a contactless alarm alone', () {
      const alarm = Alarm(id: 'a', hour: 7, minute: 0);
      expect(resolveAlarmContact(alarm, [entry()]), alarm);
    });

    test('the countdown line reads the resolved name', () {
      final live = resolveOversleepContact(snapshot, [entry(name: '新しい名前')]);
      expect(
        contactCountdownLine(const Duration(minutes: 1), live),
        'あと 1:00 で 新しい名前 さんに連絡が行きます',
      );
    });
  });
}
