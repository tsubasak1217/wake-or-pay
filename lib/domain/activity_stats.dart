import 'package:flutter/foundation.dart';

import 'models.dart';

/// How one calendar day of alarms turned out.
///
/// [failed] wins over [success]: a day with three rings, one of them slept
/// through, is a day the user overslept — the chart must not launder it into a
/// success because the other two were fine.
enum DayResult { none, success, failed }

/// One column of the アクティビティ chart.
@immutable
class DayOutcome {
  const DayOutcome({
    required this.date,
    required this.result,
    this.penalty = 0,
  });

  /// Local midnight of the day this column stands for.
  final DateTime date;

  final DayResult result;

  /// Coins lost that day, across every settled ring on it.
  final int penalty;

  @override
  bool operator ==(Object other) =>
      other is DayOutcome &&
      other.date == date &&
      other.result == result &&
      other.penalty == penalty;

  @override
  int get hashCode => Object.hash(date, result, penalty);

  @override
  String toString() => 'DayOutcome($date, ${result.name}, $penalty)';
}

/// Midnight of the day [t] falls on, in local time. Pure.
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// The last [days] calendar days ending on [today] **inclusive**, oldest first.
///
/// Pure. [sessions] may be in any order and may contain rings that have not
/// settled yet — a ringing session has no outcome, so it neither colours a day
/// nor contributes a penalty.
///
/// A day with no settled ring at all is [DayResult.none], which is a different
/// thing from a day that went well and is drawn differently.
List<DayOutcome> dailyOutcomes(
  List<AlarmSession> sessions,
  DateTime today, {
  int days = 30,
}) {
  if (days <= 0) return const [];

  final end = dayOf(today);
  final start = end.subtract(Duration(days: days - 1));

  final results = <DateTime, DayResult>{};
  final penalties = <DateTime, int>{};

  for (final session in sessions) {
    if (session.status == SessionStatus.ringing) continue;
    final day = dayOf(session.firedAt);
    if (day.isBefore(start) || day.isAfter(end)) continue;

    penalties.update(
      day,
      (n) => n + session.loss,
      ifAbsent: () => session.loss,
    );
    final failed = session.status == SessionStatus.failed;
    results.update(
      day,
      (r) => r == DayResult.failed || failed ? DayResult.failed : r,
      ifAbsent: () => failed ? DayResult.failed : DayResult.success,
    );
  }

  return [
    for (var i = 0; i < days; i++)
      () {
        // Built by adding days to a local midnight rather than by adding
        // Durations to `start`, so a DST change cannot slide a column off its
        // own date.
        final day = DateTime(start.year, start.month, start.day + i);
        return DayOutcome(
          date: day,
          result: results[day] ?? DayResult.none,
          penalty: penalties[day] ?? 0,
        );
      }(),
  ];
}

/// How many of [outcomes] went each way. Days, not rings — the chart above the
/// line is one column per day, and the count under it has to agree with it.
int successDays(List<DayOutcome> outcomes) =>
    outcomes.where((o) => o.result == DayResult.success).length;

int oversleptDays(List<DayOutcome> outcomes) =>
    outcomes.where((o) => o.result == DayResult.failed).length;

/// Every settled ring that actually cost something, newest first. Pure.
List<AlarmSession> penaltySessions(List<AlarmSession> sessions) =>
    sessions
        .where((s) => s.status != SessionStatus.ringing && s.loss > 0)
        .toList()
      ..sort((a, b) => b.firedAt.compareTo(a.firedAt));

/// 総支払額 — every coin a settled ring has ever taken. Pure.
int totalPenalty(List<AlarmSession> sessions) => sessions
    .where((s) => s.status != SessionStatus.ringing)
    .fold(0, (sum, s) => sum + s.loss);

/// True when this session's loss is owed to the registered card rather than
/// taken out of the coin balance. Pure.
bool isCardHostage(AlarmSession session) =>
    session.kakugoSnapshot?.hostage == HostageType.card;
