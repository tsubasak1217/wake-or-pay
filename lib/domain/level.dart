import 'dart:math' as math;

/// How much cumulative XP one level costs. Level 2 is 50, level 3 is 150,
/// level 4 is 300 — the gap grows by 50 each time.
const xpLevelStep = 25;

/// Cumulative XP needed to *be* [level]. Pure.
///
/// `25·n·(n−1)`, so level 1 is free. Anything below level 1 is not a level, and
/// answering 0 keeps [levelProgress] and [xpToNext] arithmetic instead of
/// making every caller guard.
int xpForLevel(int level) =>
    level < 1 ? 0 : xpLevelStep * level * (level - 1);

/// The level [xp] buys: the largest `n >= 1` with `xpForLevel(n) <= xp`. Pure.
///
/// Closed form from the quadratic — `25n² − 25n − xp <= 0` gives
/// `n <= (1 + √(1 + 4·xp/25)) / 2` — because a loop over the levels would run
/// once per level and there is no ceiling on stored XP. `sqrt` on a large
/// double is off by at most one level, so the two guards below correct it; they
/// are bounded, not a search.
int levelForXp(int xp) {
  if (xp <= 0) return 1;
  var level = ((1 + math.sqrt(1 + 4 * xp / xpLevelStep)) / 2).floor();
  if (level < 1) level = 1;
  while (xpForLevel(level + 1) <= xp) {
    level++;
  }
  while (level > 1 && xpForLevel(level) > xp) {
    level--;
  }
  return level;
}

/// XP still owed before the next level. Pure. Always positive.
int xpToNext(int xp) {
  final current = math.max(0, xp);
  return xpForLevel(levelForXp(current) + 1) - current;
}

/// How far through the current level [xp] is, 0..1, for the bar. Pure.
double levelProgress(int xp) {
  final current = math.max(0, xp);
  final level = levelForXp(current);
  final floor = xpForLevel(level);
  final span = xpForLevel(level + 1) - floor;
  // Cannot happen for the curve above, but a future curve with a flat step
  // would divide by zero here rather than fail a test.
  if (span <= 0) return 0;
  return ((current - floor) / span).clamp(0.0, 1.0);
}
