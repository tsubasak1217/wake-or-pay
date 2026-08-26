import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/schedule.dart';

Alarm alarmAt(int hour, int minute, {Set<int> days = const {}}) =>
    Alarm(id: 'a1', hour: hour, minute: minute, repeatDays: days);

void main() {
  // 2026-08-27 is a Thursday (weekday 4).
  final thursday0800 = DateTime(2026, 8, 27, 8);

  group('nextFireTime, one shot', () {
    test('later today', () {
      expect(
        nextFireTime(alarmAt(9, 30), thursday0800),
        DateTime(2026, 8, 27, 9, 30),
      );
    });

    test('already passed today: tomorrow', () {
      expect(
        nextFireTime(alarmAt(7, 0), thursday0800),
        DateTime(2026, 8, 28, 7),
      );
    });

    test('exactly now counts as passed', () {
      expect(
        nextFireTime(alarmAt(8, 0), thursday0800),
        DateTime(2026, 8, 28, 8),
      );
    });

    test('rolls over month ends', () {
      expect(
        nextFireTime(alarmAt(6, 0), DateTime(2026, 8, 31, 7)),
        DateTime(2026, 9, 1, 6),
      );
    });
  });

  group('nextFireTime, repeating', () {
    test('today is a repeat day and the time is ahead', () {
      expect(
        nextFireTime(alarmAt(9, 0, days: {4}), thursday0800),
        DateTime(2026, 8, 27, 9),
      );
    });

    test('today is a repeat day but the time has passed: next week', () {
      expect(
        nextFireTime(alarmAt(7, 0, days: {4}), thursday0800),
        DateTime(2026, 9, 3, 7),
      );
    });

    test('picks the nearest of several days', () {
      // Mon/Wed/Fri from a Thursday morning -> Friday.
      expect(
        nextFireTime(alarmAt(7, 0, days: {1, 3, 5}), thursday0800),
        DateTime(2026, 8, 28, 7),
      );
    });

    test('wraps to the following week', () {
      // Wednesday only, from Thursday -> next Wednesday.
      expect(
        nextFireTime(alarmAt(7, 0, days: {3}), thursday0800),
        DateTime(2026, 9, 2, 7),
      );
    });

    test('Sunday is 7', () {
      expect(
        nextFireTime(alarmAt(7, 0, days: {7}), thursday0800),
        DateTime(2026, 8, 30, 7),
      );
    });

    test('every day behaves like a daily alarm', () {
      final everyDay = alarmAt(7, 0, days: {1, 2, 3, 4, 5, 6, 7});
      expect(nextFireTime(everyDay, thursday0800), DateTime(2026, 8, 28, 7));
      expect(
        nextFireTime(alarmAt(9, 0, days: {1, 2, 3, 4, 5, 6, 7}), thursday0800),
        DateTime(2026, 8, 27, 9),
      );
    });

    test('an invalid weekday set is rejected rather than looping', () {
      expect(
        () => nextFireTime(alarmAt(7, 0, days: {0}), thursday0800),
        throwsArgumentError,
      );
    });
  });
}
