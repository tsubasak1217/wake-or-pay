import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/loss_calculator.dart';
import 'package:wake_or_pay/domain/models.dart';

final firedAt = DateTime(2026, 8, 27, 7);

AlarmSession session({
  Kakugo? kakugo = const Kakugo(ratePerMinute: 100, cap: 1000),
  int coinsAtFire = 100000,
  SessionStatus status = SessionStatus.ringing,
  int graceMinutes = 1,
  List<DateTime> snoozes = const [],
  DateTime? currentRingAt,
}) => AlarmSession(
  id: 's1',
  alarmId: 'a1',
  firedAt: firedAt,
  kakugoSnapshot: kakugo,
  coinsAtFire: coinsAtFire,
  status: status,
  graceMinutes: graceMinutes,
  snoozes: snoozes,
  currentRingAt: currentRingAt,
);

/// Big enough that the cap never bites, so a test about grace is only about
/// grace.
const bigKakugo = Kakugo(ratePerMinute: 100, cap: 1000000);

DateTime at({int minutes = 0, int seconds = 0}) =>
    firedAt.add(Duration(minutes: minutes, seconds: seconds));

void main() {
  group('lossAt', () {
    test('no kakugo costs nothing, however long it rings', () {
      expect(lossAt(at(minutes: 600), session(kakugo: null)), 0);
    });

    test('人質なし costs nothing either, rate and snoozes included', () {
      // 連絡だけの覚悟 in its current spelling: the pledge is real, the morning
      // is still judged and the contact still told, but nothing is at stake.
      final s = session(
        kakugo: const Kakugo(
          hostage: HostageType.none,
          ratePerMinute: 500,
          cap: 10000,
          snoozePenalty: 500,
        ),
        snoozes: [at(minutes: 2), at(minutes: 5)],
      );
      expect(lossAt(at(minutes: 1), s), 0);
      expect(lossAt(at(minutes: 600), s), 0);
      expect(finalizeSession(s, at(minutes: 30)).loss, 0);
      expect(
        finalizeSession(s, at(minutes: 30)).status,
        SessionStatus.failed,
        reason: 'the morning is still judged on time',
      );
    });

    test('59s is still zero minutes, 60s is one', () {
      expect(lossAt(at(seconds: 59), session()), 0);
      expect(lossAt(at(seconds: 60), session()), 100);
      expect(lossAt(at(minutes: 1, seconds: 59), session()), 100);
      expect(lossAt(at(minutes: 2), session()), 200);
    });

    test('0 コイン/分 burns nothing by the minute, ever', () {
      // 連絡だけの覚悟: the punishment is the phone call, not the wallet.
      final s = session(kakugo: const Kakugo(ratePerMinute: 0, cap: 1000));
      expect(lossAt(at(minutes: 1), s), 0);
      expect(lossAt(at(minutes: 30), s), 0);
      expect(lossAt(at(minutes: 600), s), 0);
      expect(finalizeSession(s, at(minutes: 30)).loss, 0);
      expect(
        finalizeSession(s, at(minutes: 30)).status,
        SessionStatus.failed,
        reason: 'costing nothing is still oversleeping',
      );
    });

    test('0 コイン/分 with a snooze penalty still charges the presses', () {
      final s = session(
        kakugo: const Kakugo(ratePerMinute: 0, cap: 1000, snoozePenalty: 50),
        snoozes: [at(minutes: 1), at(minutes: 6)],
      );
      expect(lossAt(at(minutes: 30), s), 100, reason: '2 presses at 50');
      expect(
        lossAt(at(minutes: 600), s),
        100,
        reason: 'time adds nothing on top',
      );
    });

    test('0 コイン/分 with a snooze penalty is still capped', () {
      final s = session(
        kakugo: const Kakugo(ratePerMinute: 0, cap: 120, snoozePenalty: 50),
        snoozes: [at(minutes: 1), at(minutes: 2), at(minutes: 3)],
      );
      expect(lossAt(at(minutes: 10), s), 120);
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

  group('grace', () {
    test('grace 1 is exactly the old rule: 59s free, 60s costs', () {
      final s = session(graceMinutes: 1);
      expect(lossAt(at(seconds: 59), s), 0);
      expect(lossAt(at(seconds: 60), s), 100);
      expect(lossAt(at(minutes: 7, seconds: 1), s), 700);
    });

    test('grace 5 bills nothing until the fifth minute is up', () {
      final s = session(graceMinutes: 5, kakugo: bigKakugo);
      expect(lossAt(at(minutes: 4, seconds: 59), s), 0, reason: '7:04:59');
      expect(lossAt(at(minutes: 5), s), 100, reason: '7:05:00');
      expect(lossAt(at(minutes: 6), s), 200, reason: '7:06:00');
      expect(lossAt(at(minutes: 10), s), 600);
    });

    test('the middle of the range shifts the whole table', () {
      for (final grace in const [1, 2, 3, 4, 5]) {
        final s = session(graceMinutes: grace, kakugo: bigKakugo);
        expect(lossAt(at(minutes: grace - 1, seconds: 59), s), 0);
        expect(lossAt(at(minutes: grace), s), 100);
        expect(lossAt(at(minutes: grace + 3), s), 400);
      }
    });

    test('a stored grace outside 1-5 cannot widen or shrink the window', () {
      expect(lossAt(at(minutes: 1), session(graceMinutes: 99)), 0);
      expect(lossAt(at(minutes: 5), session(graceMinutes: 99)), 100);
      expect(lossAt(at(minutes: 1), session(graceMinutes: 0)), 100);
      expect(lossAt(at(minutes: 1), session(graceMinutes: -3)), 100);
    });

    test('billableMinutes never goes negative', () {
      expect(billableMinutes(Duration.zero, 5), 0);
      expect(billableMinutes(const Duration(minutes: -10), 1), 0);
      expect(billableMinutes(const Duration(minutes: 60), 5), 56);
    });

    test('graceRemaining counts down and then stays at zero', () {
      final s = session(graceMinutes: 3);
      expect(graceRemaining(firedAt, s), const Duration(minutes: 3));
      expect(graceRemaining(at(seconds: 42), s), const Duration(seconds: 138));
      expect(graceRemaining(at(minutes: 3), s), Duration.zero);
      expect(graceRemaining(at(minutes: 30), s), Duration.zero);
    });

    test('a plain alarm has a grace window too', () {
      final s = session(kakugo: null, graceMinutes: 4);
      expect(graceRemaining(firedAt, s), const Duration(minutes: 4));
      expect(
        judgeStatus(
          const Duration(minutes: 3, seconds: 59),
          graceMinutes: s.graceMinutes,
        ),
        SessionStatus.success,
      );
    });
  });

  group('judgeStatus', () {
    test('inside the one minute grace is success', () {
      expect(
        judgeStatus(Duration.zero, graceMinutes: 1),
        SessionStatus.success,
      );
      expect(
        judgeStatus(const Duration(seconds: 59), graceMinutes: 1),
        SessionStatus.success,
      );
      expect(
        judgeStatus(
          const Duration(seconds: 59, milliseconds: 999),
          graceMinutes: 1,
        ),
        SessionStatus.success,
      );
    });

    test('one minute or more is failure at grace 1', () {
      expect(
        judgeStatus(const Duration(seconds: 60), graceMinutes: 1),
        SessionStatus.failed,
      );
      expect(
        judgeStatus(const Duration(hours: 3), graceMinutes: 1),
        SessionStatus.failed,
      );
    });

    test('grace 5 flips at exactly five minutes', () {
      expect(
        judgeStatus(const Duration(minutes: 4, seconds: 59), graceMinutes: 5),
        SessionStatus.success,
      );
      expect(
        judgeStatus(const Duration(minutes: 5), graceMinutes: 5),
        SessionStatus.failed,
      );
    });

    test('a clock that went backwards is not punished', () {
      expect(
        judgeStatus(const Duration(minutes: -5), graceMinutes: 1),
        SessionStatus.success,
      );
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

    test('with grace 5, 4:59 is a free success and 5:00 costs a minute', () {
      final s = session(graceMinutes: 5, kakugo: bigKakugo);

      final inTime = finalizeSession(s, at(minutes: 4, seconds: 59));
      expect(inTime.status, SessionStatus.success);
      expect(inTime.loss, 0);

      final late = finalizeSession(s, at(minutes: 5));
      expect(late.status, SessionStatus.failed);
      expect(late.loss, 100);

      expect(finalizeSession(s, at(minutes: 6)).loss, 200);
    });

    test('the settled session keeps the grace it fired with', () {
      final s = finalizeSession(session(graceMinutes: 4), at(minutes: 10));
      expect(s.graceMinutes, 4);
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

  // Spec 4: the snooze half of the loss. rate 100/min, 50 coins a press, and a
  // cap far out of reach unless a test is about the cap.
  group('snooze', () {
    const continuous = Kakugo(
      ratePerMinute: 100,
      cap: 1000000,
      snoozePenalty: 50,
    );
    const resets = Kakugo(
      ratePerMinute: 100,
      cap: 1000000,
      snoozePenalty: 50,
      snoozeResetsClock: true,
    );

    List<DateTime> presses(int n) => [
      for (var i = 0; i < n; i++) at(minutes: 2 + i * 5),
    ];

    group('規定時刻から加算し続ける', () {
      test('grace 1: the minute part never notices the snoozes', () {
        for (final (count, expected) in const [
          (0, 1000),
          (1, 1050),
          (3, 1150),
        ]) {
          final s = session(
            kakugo: continuous,
            graceMinutes: 1,
            snoozes: presses(count),
            // Silent right now, and it makes no difference: the clock runs
            // from firedAt.
            currentRingAt: at(minutes: 12),
          );
          expect(
            lossAt(at(minutes: 10), s),
            expected,
            reason: '$count presses',
          );
        }
      });

      test('grace 5: the same table, five minutes cheaper', () {
        for (final (count, expected) in const [(0, 600), (1, 650), (3, 750)]) {
          final s = session(
            kakugo: continuous,
            graceMinutes: 5,
            snoozes: presses(count),
          );
          expect(
            lossAt(at(minutes: 10), s),
            expected,
            reason: '$count presses',
          );
        }
      });

      test('the penalty lands the instant the button is pressed', () {
        final s = session(
          kakugo: continuous,
          snoozes: presses(1),
          currentRingAt: at(minutes: 7),
        );
        // 7:02:00, still inside nothing much: one billed minute plus one press.
        expect(lossAt(at(minutes: 2), s), 250);
      });
    });

    group('次に鳴る時刻を起点にし直す', () {
      AlarmSession resetSession({int count = 1, int graceMinutes = 1}) =>
          session(
            kakugo: resets,
            graceMinutes: graceMinutes,
            snoozes: presses(count),
            currentRingAt: at(minutes: 7),
          );

      test('grace 1: silent minutes cost nothing but the press does', () {
        final s = resetSession();
        expect(lossAt(at(minutes: 5), s), 50, reason: 'still snoozing');
        expect(lossAt(at(minutes: 7), s), 50, reason: 're-ring, grace afresh');
        expect(lossAt(at(minutes: 7, seconds: 59), s), 50);
        expect(lossAt(at(minutes: 8), s), 150, reason: 'first billed minute');
        expect(lossAt(at(minutes: 10), s), 350);
      });

      test('grace 5 applies again from the re-ring', () {
        final s = resetSession(graceMinutes: 5);
        expect(lossAt(at(minutes: 11, seconds: 59), s), 50);
        expect(lossAt(at(minutes: 12), s), 150);
        expect(lossAt(at(minutes: 15), s), 450);
      });

      test('0 presses is exactly the old rule', () {
        final s = session(
          kakugo: resets,
          snoozes: const [],
          // Never snoozed, so currentRingAt is firedAt.
        );
        expect(lossAt(at(seconds: 59), s), 0);
        expect(lossAt(at(minutes: 10), s), 1000);
      });

      test('3 presses stack while the clock keeps restarting', () {
        final s = resetSession(count: 3);
        expect(lossAt(at(minutes: 6), s), 150, reason: 'silent, 3 x 50');
        expect(lossAt(at(minutes: 10), s), 450, reason: '3 billed min + 150');
      });

      test('the grace countdown restarts too', () {
        final s = resetSession();
        expect(graceRemaining(at(minutes: 7), s), const Duration(minutes: 1));
        expect(graceRemaining(at(minutes: 8), s), Duration.zero);
        // Continuous mode never gets a second window.
        final c = session(
          kakugo: continuous,
          snoozes: presses(1),
          currentRingAt: at(minutes: 7),
        );
        expect(graceRemaining(at(minutes: 7), c), Duration.zero);
      });
    });

    test('the cap clamps the snooze part too', () {
      final s = session(
        kakugo: const Kakugo(ratePerMinute: 100, cap: 100, snoozePenalty: 50),
        snoozes: presses(3),
      );
      expect(lossAt(firedAt, s), 100, reason: '150 of penalty, capped at 100');
      expect(lossAt(at(minutes: 30), s), 100);
    });

    test('the balance at fire time clamps it harder still', () {
      final s = session(
        kakugo: const Kakugo(ratePerMinute: 100, cap: 1000, snoozePenalty: 50),
        coinsAtFire: 80,
        snoozes: presses(3),
      );
      expect(lossAt(at(minutes: 30), s), 80);
    });

    test(
      'a stored penalty outside the allowed range is clamped on the way out',
      () {
        // Absurd penalty, nothing else to bite: only the normalising clamp can
        // hold it, and it holds it at the ceiling.
        final s = session(
          kakugo: const Kakugo(
            ratePerMinute: 1,
            cap: 9999999,
            snoozePenalty: 999999,
          ),
          // Above the ceiling too, so the balance is not what does the cutting.
          coinsAtFire: 9999999,
          snoozes: presses(1),
        );
        expect(lossAt(firedAt, s), maxSnoozePenalty);
        expect(maxSnoozePenalty, lessThan(999999), reason: 'it really was cut');

        // And with a real cap and a real balance, those bite first.
        expect(
          lossAt(
            firedAt,
            session(
              kakugo: const Kakugo(
                ratePerMinute: 1,
                cap: 700,
                snoozePenalty: 99999,
              ),
              snoozes: presses(1),
            ),
          ),
          700,
        );
        expect(
          lossAt(
            firedAt,
            session(
              kakugo: const Kakugo(
                ratePerMinute: 1,
                cap: 700,
                snoozePenalty: 99999,
              ),
              coinsAtFire: 120,
              snoozes: presses(1),
            ),
          ),
          120,
        );
      },
    );

    group('judgeStatus', () {
      test('one press fails the morning however fast the check goes', () {
        expect(
          judgeStatus(Duration.zero, graceMinutes: 5, snoozed: true),
          SessionStatus.failed,
        );
        expect(
          judgeStatus(
            const Duration(seconds: 1),
            graceMinutes: 5,
            snoozed: false,
          ),
          SessionStatus.success,
        );
      });

      test('snoozed but loss 0 is still failed', () {
        // A plain alarm: nothing at stake, snoozed once, cleared in 30 seconds.
        final s = finalizeSession(
          session(kakugo: null, snoozes: presses(1)),
          at(seconds: 30),
        );
        expect(s.loss, 0);
        expect(s.status, SessionStatus.failed);

        // And a pledge whose snooze is free: same answer.
        final free = finalizeSession(
          session(
            kakugo: const Kakugo(
              ratePerMinute: 100,
              cap: 1000,
              snoozePenalty: 0,
              snoozeResetsClock: true,
            ),
            snoozes: presses(1),
            currentRingAt: at(minutes: 7),
          ),
          at(minutes: 7, seconds: 30),
        );
        expect(free.loss, 0, reason: 'inside the fresh grace window');
        expect(free.status, SessionStatus.failed);
      });

      test('finalizing carries the presses into the settled session', () {
        final s = finalizeSession(
          session(kakugo: continuous, snoozes: presses(2)),
          at(minutes: 10),
        );
        expect(s.snoozes, hasLength(2));
        expect(s.loss, 1100);
        expect(s.status, SessionStatus.failed);
      });
    });

    test('the 60 minute valve still measures from firedAt', () {
      final s = recoverSession(
        session(
          kakugo: resets,
          snoozes: presses(1),
          currentRingAt: at(minutes: 55),
        ),
        at(minutes: 60),
      );
      expect(s.status, SessionStatus.failed);
      expect(
        s.dismissedAt,
        at(minutes: 60),
        reason: 'not pushed out by snooze',
      );
      // 5 minutes of the current ring bill 5 (the grace minute is the first
      // billed one), plus one press.
      expect(s.loss, 550);
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
