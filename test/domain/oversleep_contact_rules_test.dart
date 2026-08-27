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
}
