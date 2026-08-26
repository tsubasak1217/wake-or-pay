import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/loss_calculator.dart';
import 'package:wake_or_pay/domain/models.dart';

final firedAt = DateTime(2026, 8, 27, 7);

AlarmSession session({
  Kakugo? kakugo = const Kakugo(ratePerMinute: 100, cap: 1000),
  int coinsAtFire = 100000,
  SessionStatus status = SessionStatus.ringing,
}) => AlarmSession(
  id: 's1',
  alarmId: 'a1',
  firedAt: firedAt,
  kakugoSnapshot: kakugo,
  coinsAtFire: coinsAtFire,
  status: status,
);

DateTime at({int minutes = 0, int seconds = 0}) =>
    firedAt.add(Duration(minutes: minutes, seconds: seconds));

void main() {
  group('lossAt', () {
    test('no kakugo costs nothing, however long it rings', () {
      expect(lossAt(at(minutes: 600), session(kakugo: null)), 0);
    });

    test('59s is still zero minutes, 60s is one', () {
      expect(lossAt(at(seconds: 59), session()), 0);
      expect(lossAt(at(seconds: 60), session()), 100);
      expect(lossAt(at(minutes: 1, seconds: 59), session()), 100);
      expect(lossAt(at(minutes: 2), session()), 200);
    });

    test('exactly at firedAt, and before it, costs nothing', () {
      expect(lossAt(firedAt, session()), 0);
      expect(lossAt(firedAt.subtract(const Duration(hours: 1)), session()), 0);
    });

    test('cap stops the burn but not the clock', () {
      final s = session(kakugo: const Kakugo(ratePerMinute: 100, cap: 250));
      expect(lossAt(at(minutes: 2), s), 200);
      expect(lossAt(at(minutes: 3), s), 250);
      expect(lossAt(at(minutes: 600), s), 250);
    });

    test('balance at fire time is a harder cap than the pledged cap', () {
      final s = session(
        kakugo: const Kakugo(ratePerMinute: 100, cap: 1000),
        coinsAtFire: 320,
      );
      expect(lossAt(at(minutes: 3), s), 300);
      expect(lossAt(at(minutes: 4), s), 320);
      expect(lossAt(at(minutes: 60), s), 320);
    });

    test('empty wallet burns nothing', () {
      expect(lossAt(at(minutes: 60), session(coinsAtFire: 0)), 0);
    });

    test('rate 0 burns nothing', () {
      final s = session(kakugo: const Kakugo(ratePerMinute: 0, cap: 1000));
      expect(lossAt(at(minutes: 60), s), 0);
    });

    test('cap 0 burns nothing', () {
      final s = session(kakugo: const Kakugo(ratePerMinute: 500, cap: 0));
      expect(lossAt(at(minutes: 60), s), 0);
    });
  });

  group('judgeStatus', () {
    test('under one minute is success', () {
      expect(judgeStatus(Duration.zero), SessionStatus.success);
      expect(judgeStatus(const Duration(seconds: 59)), SessionStatus.success);
      expect(
        judgeStatus(const Duration(seconds: 59, milliseconds: 999)),
        SessionStatus.success,
      );
    });

    test('one minute or more is failure', () {
      expect(judgeStatus(const Duration(seconds: 60)), SessionStatus.failed);
      expect(judgeStatus(const Duration(hours: 3)), SessionStatus.failed);
    });

    test('a clock that went backwards is not punished', () {
      expect(judgeStatus(const Duration(minutes: -5)), SessionStatus.success);
    });
  });

  group('finalizeSession', () {
    test('dismissed within the first minute is a success', () {
      final s = finalizeSession(session(), at(seconds: 59));
      expect(s.loss, 0);
      expect(s.status, SessionStatus.success);
      expect(s.dismissedAt, at(seconds: 59));
    });

    test('dismissed after a minute is a failure that costs', () {
      final s = finalizeSession(session(), at(minutes: 7, seconds: 30));
      expect(s.loss, 700);
      expect(s.status, SessionStatus.failed);
    });

    test('a plain alarm dismissed at 59s is a success', () {
      final s = finalizeSession(session(kakugo: null), at(seconds: 59));
      expect(s.loss, 0);
      expect(s.status, SessionStatus.success);
    });

    test('a plain alarm dismissed at 60s is a failure that costs nothing', () {
      final s = finalizeSession(session(kakugo: null), at(seconds: 60));
      expect(s.loss, 0);
      expect(s.status, SessionStatus.failed);
    });

    test('an empty wallet still oversleeps: failed, loss 0', () {
      final s = finalizeSession(session(coinsAtFire: 0), at(minutes: 5));
      expect(s.loss, 0);
      expect(s.status, SessionStatus.failed);
    });

    test('cap 0 and rate 0 also oversleep', () {
      expect(
        finalizeSession(
          session(kakugo: const Kakugo(ratePerMinute: 500, cap: 0)),
          at(minutes: 5),
        ).status,
        SessionStatus.failed,
      );
      expect(
        finalizeSession(
          session(kakugo: const Kakugo(ratePerMinute: 0, cap: 5000)),
          at(minutes: 5),
        ).status,
        SessionStatus.failed,
      );
    });
  });

  group('recoverSession', () {
    test('still within the hour: resume the ring untouched', () {
      final s = session();
      expect(recoverSession(s, at(minutes: 59, seconds: 59)), s);
    });

    test('exactly 60 minutes: written off as failed', () {
      final s = recoverSession(session(), at(minutes: 60));
      expect(s.status, SessionStatus.failed);
      expect(s.dismissedAt, at(minutes: 60));
      expect(s.loss, 1000); // 60 * 100 capped at 1000
    });

    test('loss is frozen at the deadline, not at discovery time', () {
      final s = recoverSession(
        session(kakugo: const Kakugo(ratePerMinute: 1, cap: 100000)),
        at(minutes: 600),
      );
      expect(s.loss, 60);
      expect(s.dismissedAt, at(minutes: 60));
    });

    test('a plain alarm left ringing an hour is still an oversleep', () {
      final s = recoverSession(session(kakugo: null), at(minutes: 90));
      expect(s.status, SessionStatus.failed);
      expect(s.loss, 0);
    });

    test('already settled sessions are left alone', () {
      final done = session(status: SessionStatus.success);
      expect(recoverSession(done, at(minutes: 600)), done);
    });
  });
}
