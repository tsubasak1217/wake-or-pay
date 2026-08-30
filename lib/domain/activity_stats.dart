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

// ---------------------------------------------------------------------------
// 今月の寝坊ペナルティ
// ---------------------------------------------------------------------------

/// Which pocket a settled loss actually came out of.
///
/// Decided by the **ledger**, not by the pledge: a カード人質 ring whose card had
/// already been taken back in プロフィール burns coins instead (see
/// `SessionService.settle`), and the only durable record of which way it went
/// is whether a [PendingCharge] was written for it.
bool _paidByCard(AlarmSession session, Set<String> chargedSessionIds) =>
    chargedSessionIds.contains(session.id);

/// What this calendar month has cost so far, in both units.
@immutable
class MonthlyPenalty {
  const MonthlyPenalty({
    this.oversleepCount = 0,
    this.oversleep = Duration.zero,
    this.coins = 0,
    this.yen = 0,
  });

  /// 寝坊回数 — failed rings that fired this month.
  final int oversleepCount;

  /// 総寝坊時間 — Σ(dismissedAt − firedAt) over those rings.
  final Duration oversleep;

  /// Coins burnt, and 円 owed to the card. One ring only ever feeds one.
  final int coins;
  final int yen;

  @override
  bool operator ==(Object other) =>
      other is MonthlyPenalty &&
      other.oversleepCount == oversleepCount &&
      other.oversleep == oversleep &&
      other.coins == coins &&
      other.yen == yen;

  @override
  int get hashCode => Object.hash(oversleepCount, oversleep, coins, yen);

  @override
  String toString() =>
      'MonthlyPenalty($oversleepCount, $oversleep, $coins コイン, $yen 円)';
}

/// Under this, the month is not billed at all — Stripe refuses a PaymentIntent
/// below ¥50. See `docs/BILLING_API.md`.
const minimumChargeableYen = 50;

/// The 今月 card, over the rings that fired in [now]'s calendar month. Pure.
///
/// Grouped by [AlarmSession.firedAt] rather than by the charge's own
/// `createdAt`, so the headline figure and the morning the user remembers
/// oversleeping can never land in two different months.
MonthlyPenalty monthlyPenalty(
  List<AlarmSession> sessions,
  List<PendingCharge> charges,
  DateTime now,
) {
  final charged = {for (final c in charges) c.sessionId};
  final amounts = {for (final c in charges) c.sessionId: c.amount};

  var oversleepCount = 0;
  var oversleep = Duration.zero;
  var coins = 0;
  var yen = 0;

  for (final session in sessions) {
    if (session.status == SessionStatus.ringing) continue;
    if (session.firedAt.year != now.year ||
        session.firedAt.month != now.month) {
      continue;
    }

    if (session.status == SessionStatus.failed) {
      oversleepCount++;
      final dismissedAt = session.dismissedAt;
      if (dismissedAt != null) {
        final slept = dismissedAt.difference(session.firedAt);
        // A dismissal before its own ring is a clock that went backwards, not
        // negative sleep: it adds nothing rather than subtracting.
        if (!slept.isNegative) oversleep += slept;
      }
    }

    if (session.loss <= 0) continue;
    if (_paidByCard(session, charged)) {
      yen += amounts[session.id] ?? session.loss;
    } else {
      coins += session.loss;
    }
  }

  return MonthlyPenalty(
    oversleepCount: oversleepCount,
    oversleep: oversleep,
    coins: coins,
    yen: yen,
  );
}

// ---------------------------------------------------------------------------
// 起床時間の遷移
// ---------------------------------------------------------------------------

/// One dot on the wake-time chart: which day, and how far into it the user
/// actually got up.
@immutable
class WakePoint {
  const WakePoint({required this.day, required this.at});

  /// Local midnight of the day the user woke on.
  final DateTime day;

  /// Time of day, as a distance from that midnight: 07:12 is 7h12m.
  final Duration at;

  @override
  bool operator ==(Object other) =>
      other is WakePoint && other.day == day && other.at == at;

  @override
  int get hashCode => Object.hash(day, at);

  @override
  String toString() => 'WakePoint($day, $at)';
}

/// When the user got up on each of the last [days] days, oldest first. Pure.
///
/// One dot per day: the **earliest** session dismissed on that day, of any
/// outcome — a morning that was slept through is still a morning somebody
/// eventually got out of bed on, and leaving it out would flatter the line.
///
/// A day with nothing dismissed produces no dot at all, and the chart joins the
/// dots it has: a holiday reads as a longer segment, never as a 00:00 wake-up.
List<WakePoint> wakeTimes(
  List<AlarmSession> sessions,
  DateTime today, {
  int days = 30,
}) {
  if (days <= 0) return const [];
  final end = dayOf(today);
  final start = end.subtract(Duration(days: days - 1));
  return _wakePointsIn(
    sessions,
    keep: (day) => !day.isBefore(start) && !day.isAfter(end),
  );
}

/// Every wake-up on record, oldest first. Pure.
List<WakePoint> allWakeTimes(List<AlarmSession> sessions) =>
    _wakePointsIn(sessions, keep: (_) => true);

List<WakePoint> _wakePointsIn(
  List<AlarmSession> sessions, {
  required bool Function(DateTime day) keep,
}) {
  final earliest = <DateTime, DateTime>{};
  for (final session in sessions) {
    final dismissedAt = session.dismissedAt;
    if (dismissedAt == null) continue;
    final day = dayOf(dismissedAt);
    if (!keep(day)) continue;
    final held = earliest[day];
    if (held == null || dismissedAt.isBefore(held)) earliest[day] = dismissedAt;
  }

  final days = earliest.keys.toList()..sort();
  return [
    for (final day in days)
      WakePoint(day: day, at: earliest[day]!.difference(day)),
  ];
}

/// The mean time of day across [points]. Null when there is nothing to average
/// — an average over no mornings is not midnight, it is nothing. Pure.
Duration? averageTimeOfDay(List<WakePoint> points) {
  if (points.isEmpty) return null;
  final total = points.fold(0, (sum, p) => sum + p.at.inSeconds);
  return Duration(seconds: total ~/ points.length);
}

/// 「7:12」. Pure.
String timeOfDayLabel(Duration at) {
  final minutes = (at.inMinutes < 0 ? 0 : at.inMinutes) % (24 * 60);
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// ペナルティ履歴
// ---------------------------------------------------------------------------

/// What one day cost, split by the pocket it came out of.
typedef DayPenalty = ({int coins, int yen});

/// Every day that cost something, keyed by local midnight. Pure.
///
/// Keyed on [AlarmSession.firedAt] so a bar and the day's log under it are
/// always the same day.
Map<DateTime, DayPenalty> penaltyByDay(
  List<AlarmSession> sessions,
  List<PendingCharge> charges,
) {
  final charged = {for (final c in charges) c.sessionId};
  final amounts = {for (final c in charges) c.sessionId: c.amount};
  final byDay = <DateTime, DayPenalty>{};

  for (final session in sessions) {
    if (session.status == SessionStatus.ringing) continue;
    if (session.loss <= 0) continue;
    final day = dayOf(session.firedAt);
    final held = byDay[day] ?? (coins: 0, yen: 0);
    byDay[day] = _paidByCard(session, charged)
        ? (
            coins: held.coins,
            yen: held.yen + (amounts[session.id] ?? session.loss),
          )
        : (coins: held.coins + session.loss, yen: held.yen);
  }

  return byDay;
}

/// The settled rings that fired on [day], newest first. Pure.
List<AlarmSession> sessionsOn(List<AlarmSession> sessions, DateTime day) {
  final midnight = dayOf(day);
  return sessions
      .where(
        (s) =>
            s.status != SessionStatus.ringing && dayOf(s.firedAt) == midnight,
      )
      .toList()
    ..sort((a, b) => b.firedAt.compareTo(a.firedAt));
}

/// True when this ring's loss went on the card — i.e. the ledger holds a charge
/// for it. Pure.
bool wasBilledToCard(AlarmSession session, List<PendingCharge> charges) =>
    charges.any((c) => c.sessionId == session.id);

// ---------------------------------------------------------------------------
// 寝坊連絡・共有履歴のアーカイブ
// ---------------------------------------------------------------------------

/// One year of the 連絡ログ archive: which month tiles to draw, and which of
/// them have anything behind them.
@immutable
class ArchiveYear {
  const ArchiveYear({
    required this.year,
    required this.months,
    required this.active,
  });

  final int year;

  /// The tiles to draw, 1..12 — cut short in the current year, because a month
  /// that has not happened yet is not an empty month.
  final List<int> months;

  /// Of those, the ones that actually hold events. The rest are drawn grey and
  /// do not answer a tap.
  final Set<int> active;

  @override
  bool operator ==(Object other) =>
      other is ArchiveYear &&
      other.year == year &&
      listEquals(other.months, months) &&
      setEquals(other.active, active);

  @override
  int get hashCode =>
      Object.hash(year, Object.hashAll(months), Object.hashAllUnordered(active));

  @override
  String toString() => 'ArchiveYear($year, ${active.length}/${months.length})';
}

/// The archive grid, newest year first. Pure.
///
/// A year with no events at all is left out entirely — a grid of twelve grey
/// tiles says nothing — and so is any month after [now]'s.
List<ArchiveYear> monthsWithEvents(List<ContactEvent> events, DateTime now) {
  final byYear = <int, Set<int>>{};
  for (final event in events) {
    final at = event.firedAt;
    // A row dated in the future has no tile to sit on, so it gets none rather
    // than one drawn ahead of the calendar.
    if (at.year > now.year || (at.year == now.year && at.month > now.month)) {
      continue;
    }
    byYear.putIfAbsent(at.year, () => <int>{}).add(at.month);
  }

  final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final year in years)
      ArchiveYear(
        year: year,
        months: [
          for (var m = 1; m <= (year == now.year ? now.month : 12); m++) m,
        ],
        active: byYear[year]!,
      ),
  ];
}

/// The events of one month, newest first. Pure.
List<ContactEvent> eventsInMonth(
  List<ContactEvent> events,
  int year,
  int month,
) =>
    events
        .where((e) => e.firedAt.year == year && e.firedAt.month == month)
        .toList()
      ..sort((a, b) => b.firedAt.compareTo(a.firedAt));
