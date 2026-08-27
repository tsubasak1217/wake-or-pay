import 'dart:math' as math;

import 'garden_catalog.dart';
import 'models.dart';

/// How one calendar day went.
///
/// [none] covers both "no alarm rang" and "something is still ringing": neither
/// earns a day nor breaks the streak.
enum DayResult { success, failure, none }

/// Streak boundaries, in consecutive success days.
const growthStageDays = [3, 7, 14];

/// Placeholder art for the four growth stages of a plant.
const growthStageLabels = ['芽', '若葉', 'つぼみ', '開花'];

/// Oversleep counts at which the ojisan's hut is upgraded. Same boundaries as
/// [ojisanLine], so his line and his address never disagree.
const hutStageOversleeps = [3, 10, 20];

const hutStageEmoji = ['🛖', '👞', '🏠', '🏰'];
const hutStageNames = ['ボロ小屋', '靴が置かれたボロ小屋', 'おじさんの家', 'おじさんの豪邸'];

/// Midnight of the day [t] falls on, in local time.
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

int _daysBetween(DateTime from, DateTime to) =>
    dayOf(to).difference(dayOf(from)).inDays;

/// One entry per day that had at least one session.
///
/// Pure. A day counts as a success only if every session on it succeeded; one
/// failure anywhere in the day makes it a failure.
Map<DateTime, DayResult> classifyDays(List<AlarmSession> sessions) {
  final byDay = <DateTime, DayResult>{};
  for (final session in sessions) {
    final day = dayOf(session.firedAt);
    final current = byDay[day];
    if (current == DayResult.failure) continue;
    switch (session.status) {
      case SessionStatus.failed:
        byDay[day] = DayResult.failure;
      case SessionStatus.ringing:
        byDay[day] = DayResult.none;
      case SessionStatus.success:
        byDay[day] = current == DayResult.none
            ? DayResult.none
            : DayResult.success;
    }
  }
  return byDay;
}

/// The wake-up streak, derived from history and never stored.
///
/// Pure. Days with no session at all do not break the streak — not setting an
/// alarm on a day off is not a failure — but a single failed session does.
Streak computeStreak(List<AlarmSession> sessions, DateTime today) {
  final days = classifyDays(sessions);
  if (days.isEmpty) return const Streak();

  final sorted = days.keys.toList()..sort();

  var best = 0;
  var run = 0;
  var total = 0;
  for (final day in sorted) {
    switch (days[day]!) {
      case DayResult.success:
        run += 1;
        total += 1;
        best = math.max(best, run);
      case DayResult.failure:
        run = 0;
      case DayResult.none:
        break;
    }
  }

  // The current streak is the trailing run, but only if nothing has failed
  // between the last counted day and today.
  final todayMidnight = dayOf(today);
  var current = 0;
  for (final day in sorted.reversed) {
    if (day.isAfter(todayMidnight)) continue;
    final result = days[day]!;
    if (result == DayResult.failure) break;
    if (result == DayResult.success) current += 1;
  }

  return Streak(
    currentStreakDays: current,
    bestStreakDays: best,
    totalSuccessDays: total,
  );
}

/// Stage a plant reaches after [streakDays] consecutive successes.
///
/// Pure. 0 (芽) → 1 (若葉, 3日) → 2 (つぼみ, 7日) → 3 (開花, 14日).
int stageForStreakDays(int streakDays) {
  var stage = 0;
  for (final boundary in growthStageDays) {
    if (streakDays >= boundary) stage += 1;
  }
  return stage;
}

/// The growth stage of one plant, folded over every day since it was placed.
///
/// Pure. Consecutive success days push it up through [growthStageDays]; a day
/// with a failure steps it back exactly one stage and restarts the run. It
/// never drops below 0 — plants in this garden do not die. Days before the
/// plant was placed are ignored, so a new plant does not inherit a long streak.
int growthStageFor(
  GardenPlacement placement,
  Map<DateTime, DayResult> days,
  DateTime today,
) {
  if (_daysBetween(placement.placedAt, today) < 0) return 0;

  final from = dayOf(placement.placedAt);
  final relevant = days.keys.where((d) => !d.isBefore(from)).toList()..sort();

  var stage = 0;
  var run = 0;
  for (final day in relevant) {
    if (day.isAfter(dayOf(today))) break;
    switch (days[day]!) {
      case DayResult.success:
        run += 1;
        stage = math.max(stage, stageForStreakDays(run));
      case DayResult.failure:
        run = 0;
        stage = math.max(0, stage - 1);
      case DayResult.none:
        break;
    }
  }
  return stage;
}

/// The ojisan's hut, by lifetime oversleeps.
///
/// Pure. 0-2 ボロ小屋 / 3-9 靴 / 10-19 家 / 20- 豪邸.
int hutStageFor(int totalOversleeps) {
  var stage = 0;
  for (final boundary in hutStageOversleeps) {
    if (totalOversleeps >= boundary) stage += 1;
  }
  return stage;
}

/// Cells an item at ([x], [y]) would occupy.
Iterable<(int, int)> cellsFor(GardenItemDef def, int x, int y) sync* {
  for (var dx = 0; dx < def.width; dx += 1) {
    for (var dy = 0; dy < def.height; dy += 1) {
      yield (x + dx, y + dy);
    }
  }
}

/// Whether [itemId] fits at ([x], [y]).
///
/// Pure. In bounds and not overlapping anything already placed. Pass
/// [ignorePlacementId] when moving a placement so it does not collide with
/// where it currently sits.
bool canPlace(
  GardenState state,
  String itemId,
  int x,
  int y, {
  GridSize gridSize = defaultGardenGrid,
  String? ignorePlacementId,
}) {
  final def = GardenCatalog.byId(itemId);
  if (def == null) return false;
  if (x < 0 || y < 0) return false;
  if (x + def.width > gridSize.width) return false;
  if (y + def.height > gridSize.height) return false;

  final taken = <(int, int)>{};
  for (final placement in state.placements) {
    if (placement.id == ignorePlacementId) continue;
    final other = GardenCatalog.byId(placement.itemId);
    if (other == null) continue;
    taken.addAll(cellsFor(other, placement.x, placement.y));
  }
  return cellsFor(def, x, y).every((cell) => !taken.contains(cell));
}

/// Result of a seed shop exchange. Null coins are impossible on purpose: the
/// wallet's coin balance is copied through untouched.
class ExchangeResult {
  const ExchangeResult({required this.inventory, required this.wallet});

  final GardenInventory inventory;
  final Wallet wallet;
}

/// Spend reward tokens on one catalogue item.
///
/// Pure. Returns null when the item is not for sale or the tokens are short.
/// Coins are never accepted — the alarm coin is a hostage, not a currency.
ExchangeResult? exchange(
  GardenInventory inventory,
  Wallet wallet,
  GardenItemDef def,
) {
  final cost = def.costTokens;
  if (cost == null || cost < 0) return null;
  if (wallet.tokens < cost) return null;
  return ExchangeResult(
    inventory: inventory.add(def.id),
    wallet: wallet.copyWith(tokens: wallet.tokens - cost),
  );
}
