import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/activity_stats.dart';
import 'package:wake_or_pay/domain/models.dart';

final _today = DateTime(2026, 8, 30, 9);

AlarmSession session({
  String id = 's',
  required DateTime firedAt,
  DateTime? dismissedAt,
  SessionStatus status = SessionStatus.success,
  int loss = 0,
  HostageType? hostage,
}) => AlarmSession(
  id: id,
  alarmId: 'a1',
  firedAt: firedAt,
  dismissedAt: dismissedAt,
  status: status,
  loss: loss,
  kakugoSnapshot: hostage == null
      ? null
      : Kakugo(hostage: hostage, ratePerMinute: 100, cap: 2000),
);

/// A ring that was slept through. [dismissedAt] null is the row a crash left
/// behind: a 寝坊 with no end on it.
AlarmSession slept({
  required String id,
  required DateTime firedAt,
  DateTime? dismissedAt,
  int loss = 0,
  HostageType? hostage,
}) => session(
  id: id,
  firedAt: firedAt,
  dismissedAt: dismissedAt,
  status: SessionStatus.failed,
  loss: loss,
  hostage: hostage,
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

  // -------------------------------------------------------------------------
  // 今月の寝坊ペナルティ
  // -------------------------------------------------------------------------

  group('monthlyPenalty', () {
    PendingCharge charge(String sessionId, int amount) => PendingCharge(
      sessionId: sessionId,
      alarmId: 'a1',
      amount: amount,
      createdAt: DateTime(2026, 8, 25, 7, 10),
    );

    test('an empty history costs nothing at all', () {
      expect(
        monthlyPenalty(const [], const [], _today),
        const MonthlyPenalty(),
      );
    });

    test('coins and 円 are split by the ledger, not by the pledge', () {
      final rows = [
        // Coin pledge: burnt coins.
        slept(id: 'a', firedAt: DateTime(2026, 8, 2, 7), loss: 200),
        // Card pledge with a charge behind it: 円.
        slept(
          id: 'b',
          firedAt: DateTime(2026, 8, 10, 7),
          loss: 1300,
          hostage: HostageType.card,
        ),
        // Card pledge whose card was taken back before it settled — no charge
        // was written, so this came out of the coins like any other.
        slept(
          id: 'c',
          firedAt: DateTime(2026, 8, 12, 7),
          loss: 500,
          hostage: HostageType.card,
        ),
      ];

      final month = monthlyPenalty(rows, [charge('b', 1300)], _today);

      expect(month.coins, 700);
      expect(month.yen, 1300);
      expect(month.oversleepCount, 3);
    });

    test('総寝坊時間 is the sum of the failed rings that were dismissed', () {
      final month = monthlyPenalty([
        slept(
          id: 'a',
          firedAt: DateTime(2026, 8, 2, 7),
          dismissedAt: DateTime(2026, 8, 2, 7, 15),
        ),
        slept(
          id: 'b',
          firedAt: DateTime(2026, 8, 3, 7),
          dismissedAt: DateTime(2026, 8, 3, 7, 10),
        ),
        // Never dismissed: it counts as a 寝坊 but adds no minutes.
        slept(id: 'c', firedAt: DateTime(2026, 8, 4, 7), dismissedAt: null),
        // A clock that went backwards subtracts nothing.
        slept(
          id: 'd',
          firedAt: DateTime(2026, 8, 5, 7),
          dismissedAt: DateTime(2026, 8, 5, 6),
        ),
      ], const [], _today);

      expect(month.oversleepCount, 4);
      expect(month.oversleep, const Duration(minutes: 25));
    });

    test('a success this month costs nothing and is not a 寝坊', () {
      final month = monthlyPenalty([
        session(firedAt: DateTime(2026, 8, 20, 7)),
      ], const [], _today);

      expect(month.oversleepCount, 0);
      expect(month.coins, 0);
    });

    test('last month and next month are somebody else’s problem', () {
      final rows = [
        slept(id: 'july', firedAt: DateTime(2026, 7, 31, 23), loss: 900),
        slept(id: 'aug', firedAt: DateTime(2026, 8, 1, 0, 5), loss: 100),
        slept(id: 'sep', firedAt: DateTime(2026, 9, 1, 0, 5), loss: 900),
      ];

      final month = monthlyPenalty(rows, const [], _today);

      expect(month.coins, 100);
      expect(month.oversleepCount, 1);
    });

    test('a live ring has cost nothing yet', () {
      final month = monthlyPenalty([
        session(
          firedAt: DateTime(2026, 8, 30, 7),
          status: SessionStatus.ringing,
          loss: 999,
        ),
      ], const [], _today);

      expect(month, const MonthlyPenalty());
    });
  });

  // -------------------------------------------------------------------------
  // 起床時間の遷移
  // -------------------------------------------------------------------------

  group('wakeTimes', () {
    test('one dot per day, the earliest dismissal on it, oldest first', () {
      final points = wakeTimes([
        session(
          id: 'late',
          firedAt: DateTime(2026, 8, 29, 8),
          dismissedAt: DateTime(2026, 8, 29, 8, 30),
        ),
        session(
          id: 'early',
          firedAt: DateTime(2026, 8, 29, 6),
          dismissedAt: DateTime(2026, 8, 29, 6, 5),
        ),
        session(
          id: 'yesterday',
          firedAt: DateTime(2026, 8, 28, 7),
          dismissedAt: DateTime(2026, 8, 28, 7, 12),
        ),
      ], _today);

      expect(points, [
        WakePoint(day: DateTime(2026, 8, 28), at: const Duration(hours: 7, minutes: 12)),
        WakePoint(day: DateTime(2026, 8, 29), at: const Duration(hours: 6, minutes: 5)),
      ]);
    });

    test('a slept-through morning is still a morning', () {
      final points = wakeTimes([
        slept(
          id: 'a',
          firedAt: DateTime(2026, 8, 29, 7),
          dismissedAt: DateTime(2026, 8, 29, 9, 30),
        ),
      ], _today);

      expect(points.single.at, const Duration(hours: 9, minutes: 30));
    });

    test('a day with nothing dismissed gets no dot', () {
      final points = wakeTimes([
        session(
          firedAt: DateTime(2026, 8, 29, 7),
          status: SessionStatus.ringing,
          dismissedAt: null,
        ),
      ], _today);

      expect(points, isEmpty);
    });

    test('the window keeps the last 30 days and nothing older', () {
      final points = wakeTimes([
        session(
          id: 'old',
          firedAt: DateTime(2026, 7, 31, 7),
          dismissedAt: DateTime(2026, 7, 31, 7, 5),
        ),
        session(
          id: 'in',
          firedAt: DateTime(2026, 8, 1, 7),
          dismissedAt: DateTime(2026, 8, 1, 7, 5),
        ),
      ], _today);

      expect(points.map((p) => p.day), [DateTime(2026, 8, 1)]);
      expect(wakeTimes(const [], _today, days: 0), isEmpty);
    });

    test('the whole history ignores the window', () {
      final rows = [
        session(
          id: 'ancient',
          firedAt: DateTime(2025, 1, 1, 7),
          dismissedAt: DateTime(2025, 1, 1, 7, 5),
        ),
        session(
          id: 'recent',
          firedAt: DateTime(2026, 8, 1, 7),
          dismissedAt: DateTime(2026, 8, 1, 7, 5),
        ),
      ];

      expect(allWakeTimes(rows).length, 2);
      expect(wakeTimes(rows, _today).length, 1);
    });
  });

  group('averageTimeOfDay', () {
    test('is null over no mornings, not midnight', () {
      expect(averageTimeOfDay(const []), isNull);
    });

    test('averages the times of day', () {
      final average = averageTimeOfDay([
        WakePoint(day: DateTime(2026, 8, 1), at: const Duration(hours: 6)),
        WakePoint(day: DateTime(2026, 8, 2), at: const Duration(hours: 8)),
        WakePoint(
          day: DateTime(2026, 8, 3),
          at: const Duration(hours: 7, minutes: 36),
        ),
      ]);

      expect(average, const Duration(hours: 7, minutes: 12));
      expect(timeOfDayLabel(average!), '7:12');
    });

    test('the label pads the minutes and never runs past a day', () {
      expect(timeOfDayLabel(const Duration(hours: 6, minutes: 5)), '6:05');
      expect(timeOfDayLabel(const Duration(minutes: -10)), '0:00');
      expect(timeOfDayLabel(const Duration(hours: 25)), '1:00');
    });
  });

  // -------------------------------------------------------------------------
  // ペナルティ履歴
  // -------------------------------------------------------------------------

  group('penaltyByDay', () {
    final rows = [
      slept(id: 'a', firedAt: DateTime(2026, 8, 20, 7), loss: 200),
      slept(id: 'b', firedAt: DateTime(2026, 8, 20, 9), loss: 300),
      slept(
        id: 'c',
        firedAt: DateTime(2026, 8, 25, 7),
        loss: 1300,
        hostage: HostageType.card,
      ),
      session(id: 'ok', firedAt: DateTime(2026, 8, 26, 7)),
      session(
        id: 'live',
        firedAt: DateTime(2026, 8, 27, 7),
        status: SessionStatus.ringing,
        loss: 999,
      ),
    ];
    final charges = [
      PendingCharge(
        sessionId: 'c',
        alarmId: 'a1',
        amount: 1300,
        createdAt: DateTime(2026, 8, 25, 7, 10),
      ),
    ];

    test('sums the day and splits it by the pocket it came out of', () {
      final byDay = penaltyByDay(rows, charges);

      expect(byDay[DateTime(2026, 8, 20)], (coins: 500, yen: 0));
      expect(byDay[DateTime(2026, 8, 25)], (coins: 0, yen: 1300));
      // Free days and live rings are not days that cost anything.
      expect(byDay.containsKey(DateTime(2026, 8, 26)), isFalse);
      expect(byDay.containsKey(DateTime(2026, 8, 27)), isFalse);
      expect(penaltyByDay(const [], const []), isEmpty);
    });

    test('sessionsOn is that day’s settled rings, newest first', () {
      expect(
        sessionsOn(rows, DateTime(2026, 8, 20, 23)).map((s) => s.id),
        ['b', 'a'],
      );
      // A success belongs to its day too — the log is the whole morning.
      expect(sessionsOn(rows, DateTime(2026, 8, 26)).map((s) => s.id), ['ok']);
      // A ring still going has not settled.
      expect(sessionsOn(rows, DateTime(2026, 8, 27)), isEmpty);
    });

    test('the ledger says which rows were billed to the card', () {
      expect(wasBilledToCard(rows[2], charges), isTrue);
      expect(wasBilledToCard(rows[0], charges), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // 連絡ログのアーカイブ
  // -------------------------------------------------------------------------

  group('monthsWithEvents', () {
    ContactEvent event(String id, DateTime at) => ContactEvent(
      id: id,
      sessionId: 's',
      firedAt: at,
      contactName: '田中太郎さん',
      channel: ContactChannel.sms,
    );

    test('nothing logged is no grid at all', () {
      expect(monthsWithEvents(const [], _today), isEmpty);
    });

    test('newest year first, and a year with no events is not shown', () {
      final years = monthsWithEvents([
        event('a', DateTime(2024, 5, 1)),
        event('b', DateTime(2026, 3, 1)),
      ], _today);

      expect(years.map((y) => y.year), [2026, 2024]);
    });

    test('a past year shows all twelve tiles, the empty ones inactive', () {
      final year = monthsWithEvents([
        event('a', DateTime(2024, 5, 1)),
        event('b', DateTime(2024, 12, 31)),
      ], _today).single;

      expect(year.months.length, 12);
      expect(year.active, {5, 12});
    });

    test('this year stops at this month — a future month has no tile', () {
      final year = monthsWithEvents([
        event('a', DateTime(2026, 2, 1)),
      ], _today).single;

      expect(year.year, 2026);
      expect(year.months, [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(year.active, {2});
    });

    test('an event dated in the future is left out with its month', () {
      final years = monthsWithEvents([
        event('now', DateTime(2026, 8, 1)),
        event('soon', DateTime(2026, 9, 1)),
        event('later', DateTime(2027, 1, 1)),
      ], _today);

      expect(years.map((y) => y.year), [2026]);
      expect(years.single.active, {8});
    });

    test('eventsInMonth picks one month out, newest first', () {
      final events = [
        event('a', DateTime(2026, 8, 1, 7)),
        event('b', DateTime(2026, 8, 20, 7)),
        event('c', DateTime(2026, 7, 20, 7)),
      ];

      expect(eventsInMonth(events, 2026, 8).map((e) => e.id), ['b', 'a']);
      expect(eventsInMonth(events, 2026, 6), isEmpty);
    });
  });
}
