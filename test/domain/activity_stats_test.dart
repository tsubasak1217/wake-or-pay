import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/activity_stats.dart';
import 'package:wake_or_pay/domain/models.dart';

final _today = DateTime(2026, 8, 30, 9);

AlarmSession session({
  String id = 's',
  required DateTime firedAt,
  SessionStatus status = SessionStatus.success,
  int loss = 0,
  HostageType? hostage,
}) => AlarmSession(
  id: id,
  alarmId: 'a1',
  firedAt: firedAt,
  status: status,
  loss: loss,
  kakugoSnapshot: hostage == null
      ? null
      : Kakugo(hostage: hostage, ratePerMinute: 100, cap: 2000),
);

void main() {
  group('dailyOutcomes', () {
    test('covers the last 30 days, oldest first, today last', () {
      final outcomes = dailyOutcomes(const [], _today);

      expect(outcomes.length, 30);
      expect(outcomes.first.date, DateTime(2026, 8, 1));
      expect(outcomes.last.date, DateTime(2026, 8, 30));
      expect(outcomes.every((o) => o.result == DayResult.none), isTrue);
      expect(outcomes.every((o) => o.penalty == 0), isTrue);
    });

    test('a settled ring colours its own day', () {
      final outcomes = dailyOutcomes([
        session(firedAt: DateTime(2026, 8, 29, 7)),
        session(
          id: 's2',
          firedAt: DateTime(2026, 8, 28, 7),
          status: SessionStatus.failed,
          loss: 300,
        ),
      ], _today);

      final byDay = {for (final o in outcomes) o.date: o};
      expect(byDay[DateTime(2026, 8, 29)]!.result, DayResult.success);
      expect(byDay[DateTime(2026, 8, 28)]!.result, DayResult.failed);
      expect(byDay[DateTime(2026, 8, 28)]!.penalty, 300);
      expect(byDay[DateTime(2026, 8, 27)]!.result, DayResult.none);
    });

    test('one failed ring makes the whole day a failure', () {
      final outcomes = dailyOutcomes([
        session(id: 's1', firedAt: DateTime(2026, 8, 30, 6)),
        session(
          id: 's2',
          firedAt: DateTime(2026, 8, 30, 7),
          status: SessionStatus.failed,
          loss: 500,
        ),
        session(id: 's3', firedAt: DateTime(2026, 8, 30, 8)),
      ], _today);

      expect(outcomes.last.result, DayResult.failed);
      expect(outcomes.last.penalty, 500);
    });

    test('order does not matter: the failure still wins', () {
      final failed = session(
        id: 's2',
        firedAt: DateTime(2026, 8, 30, 7),
        status: SessionStatus.failed,
      );
      final ok = session(id: 's1', firedAt: DateTime(2026, 8, 30, 6));

      expect(dailyOutcomes([failed, ok], _today).last.result, DayResult.failed);
      expect(dailyOutcomes([ok, failed], _today).last.result, DayResult.failed);
    });

    test('a ringing session has no outcome and costs nothing yet', () {
      final outcomes = dailyOutcomes([
        session(
          firedAt: DateTime(2026, 8, 30, 7),
          status: SessionStatus.ringing,
          loss: 400,
        ),
      ], _today);

      expect(outcomes.last.result, DayResult.none);
      expect(outcomes.last.penalty, 0);
    });

    test('anything outside the window is left out', () {
      final outcomes = dailyOutcomes([
        session(id: 'old', firedAt: DateTime(2026, 7, 31, 7)),
        session(id: 'future', firedAt: DateTime(2026, 8, 31, 7)),
      ], _today);

      expect(outcomes.every((o) => o.result == DayResult.none), isTrue);
    });

    test('the window is settable, and zero days is an empty strip', () {
      expect(dailyOutcomes(const [], _today, days: 7).length, 7);
      expect(dailyOutcomes(const [], _today, days: 0), isEmpty);
      expect(dailyOutcomes(const [], _today, days: -3), isEmpty);
    });

    test('counts are days, not rings', () {
      final outcomes = dailyOutcomes([
        session(id: 's1', firedAt: DateTime(2026, 8, 30, 6)),
        session(id: 's2', firedAt: DateTime(2026, 8, 30, 8)),
        session(id: 's3', firedAt: DateTime(2026, 8, 29, 6)),
        session(
          id: 's4',
          firedAt: DateTime(2026, 8, 28, 6),
          status: SessionStatus.failed,
        ),
      ], _today);

      expect(successDays(outcomes), 2);
      expect(oversleptDays(outcomes), 1);
    });
  });

  group('penalties', () {
    final sessions = [
      session(
        id: 'a',
        firedAt: DateTime(2026, 8, 20, 7),
        status: SessionStatus.failed,
        loss: 200,
      ),
      session(
        id: 'b',
        firedAt: DateTime(2026, 8, 25, 7),
        status: SessionStatus.failed,
        loss: 1300,
        hostage: HostageType.card,
      ),
      // Woke up: settled, and free.
      session(id: 'c', firedAt: DateTime(2026, 8, 26, 7)),
      // Still ringing: whatever it says it has lost is not owed yet.
      session(
        id: 'd',
        firedAt: DateTime(2026, 8, 27, 7),
        status: SessionStatus.ringing,
        loss: 999,
      ),
    ];

    test('only settled rings that cost something, newest first', () {
      expect(penaltySessions(sessions).map((s) => s.id), ['b', 'a']);
    });

    test('総支払額 sums the settled losses and ignores a live ring', () {
      expect(totalPenalty(sessions), 1500);
      expect(totalPenalty(const []), 0);
    });

    test('a card pledge is recognised as a card pledge', () {
      expect(isCardHostage(sessions[1]), isTrue);
      expect(isCardHostage(sessions[0]), isFalse);
      expect(isCardHostage(sessions[2]), isFalse);
    });
  });
}
