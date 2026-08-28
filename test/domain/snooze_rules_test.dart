import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/snooze_rules.dart';

final firedAt = DateTime(2026, 8, 27, 7);

AlarmSession session({
  List<DateTime> snoozes = const [],
  DateTime? currentRingAt,
  SessionStatus status = SessionStatus.ringing,
  Kakugo? kakugo,
}) => AlarmSession(
  id: 's1',
  alarmId: 'a1',
  firedAt: firedAt,
  status: status,
  snoozes: snoozes,
  currentRingAt: currentRingAt,
  kakugoSnapshot: kakugo,
);

const alarm = Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  snooze: Snooze(intervalMinutes: 5, maxCount: 3),
);

void main() {
  group('canSnoozeNow', () {
    test('an alarm without snooze never offers the button', () {
      const plain = Alarm(id: 'a1', hour: 7, minute: 0);
      expect(canSnoozeNow(plain, session()), isFalse);
      expect(snoozesRemaining(plain, session()), 0);
    });

    test('maxCount 0 means no button, not unlimited', () {
      const none = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        snooze: Snooze(maxCount: 0),
      );
      expect(canSnoozeNow(none, session()), isFalse);
    });

    test('the button goes away on the last allowed press', () {
      for (var used = 0; used <= 4; used++) {
        final s = session(snoozes: [for (var i = 0; i < used; i++) firedAt]);
        expect(canSnoozeNow(alarm, s), used < 3, reason: '$used used');
        expect(snoozesRemaining(alarm, s), used < 3 ? 3 - used : 0);
      }
    });

    test('a hand edited maxCount cannot widen the rule', () {
      const cheat = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        snooze: Snooze(maxCount: 99),
      );
      final used = session(snoozes: [for (var i = 0; i < 10; i++) firedAt]);
      expect(canSnoozeNow(cheat, used), isFalse, reason: 'clamped to 10');
    });
  });

  group('applySnooze', () {
    test('records the press and moves the ring by the interval', () {
      final at = firedAt.add(const Duration(minutes: 2));
      final s = applySnooze(session(), at, const Snooze(intervalMinutes: 5));

      expect(s.snoozes, [at]);
      expect(s.currentRingAt, firedAt.add(const Duration(minutes: 7)));
      expect(s.firedAt, firedAt, reason: 'the scheduled time never moves');
      expect(s.status, SessionStatus.ringing, reason: 'the same morning');
    });

    test('presses stack, each from the moment it was pressed', () {
      var s = session();
      for (final minute in const [2, 8, 14]) {
        s = applySnooze(
          s,
          firedAt.add(Duration(minutes: minute)),
          const Snooze(intervalMinutes: 5),
        );
      }
      expect(s.snoozes, hasLength(3));
      expect(s.currentRingAt, firedAt.add(const Duration(minutes: 19)));
    });

    test('a stored interval outside 1-30 is clamped', () {
      expect(
        nextRingAt(firedAt, const Snooze(intervalMinutes: 999)),
        firedAt.add(const Duration(minutes: maxSnoozeIntervalMinutes)),
      );
      expect(
        nextRingAt(firedAt, const Snooze(intervalMinutes: 0)),
        firedAt.add(const Duration(minutes: minSnoozeIntervalMinutes)),
      );
    });
  });

  group('isSnoozePending', () {
    final snoozed = session(
      snoozes: [firedAt.add(const Duration(minutes: 2))],
      currentRingAt: firedAt.add(const Duration(minutes: 7)),
    );

    test('silent until the re-ring, live from it', () {
      expect(
        isSnoozePending(snoozed, firedAt.add(const Duration(minutes: 6))),
        isTrue,
      );
      expect(
        isSnoozePending(snoozed, firedAt.add(const Duration(minutes: 7))),
        isFalse,
        reason: 'it is ringing again',
      );
    });

    test('a session that was never snoozed is never pending', () {
      expect(isSnoozePending(session(), firedAt), isFalse);
    });

    test('a settled session is never pending, however it looks', () {
      final done = session(
        status: SessionStatus.failed,
        snoozes: [firedAt],
        currentRingAt: firedAt.add(const Duration(hours: 1)),
      );
      expect(isSnoozePending(done, firedAt), isFalse);
    });
  });

  group('labels', () {
    test('the re-ring time reads as a clock, zero padded', () {
      expect(snoozeUntilLabel(DateTime(2026, 8, 27, 7, 5)), 'スヌーズ中 7:05');
      expect(snoozeUntilLabel(DateTime(2026, 8, 27, 23, 0)), 'スヌーズ中 23:00');
      // No loss: the notification names the re-ring and the way out, and says
      // nothing about money that is not moving.
      expect(snoozeNotificationText(DateTime(2026, 8, 27, 7, 5)), (
        title: 'スヌーズ中',
        body: '7:05 に再鳴動します。起きたら『解除』を押してください。',
      ));
      // With loss it puts the running meter in the middle, spec 12.1.
      expect(snoozeNotificationText(DateTime(2026, 8, 27, 7, 5), loss: 300), (
        title: 'スヌーズ中',
        body: '7:05 に再鳴動します。これまでの損失 300 コイン。起きたら『解除』を押してください。',
      ));
    });

    test('a pledge with a penalty puts the price on the button', () {
      expect(
        snoozeButtonLabel(
          const Kakugo(ratePerMinute: 100, cap: 1000, snoozePenalty: 50),
        ),
        'スヌーズ（−50 コイン）',
      );
    });

    test('no pledge, and a free one, say only スヌーズ', () {
      expect(snoozeButtonLabel(null), 'スヌーズ');
      expect(
        snoozeButtonLabel(const Kakugo(ratePerMinute: 100, cap: 1000)),
        'スヌーズ',
      );
    });
  });
}
