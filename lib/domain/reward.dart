import 'dart:math' as math;

import 'models.dart';

const baseRewardTokens = 10;
const baseRewardXp = 10;
const maxKakugoRewardBonus = 50;

/// The extra granted for how much was at stake. Pure.
///
/// Written once because tokens and XP are paid on the same rule: raising the
/// stakes has to move both, and two copies of `rate ~/ 10` would eventually
/// stop agreeing.
int kakugoRewardBonus(Kakugo? kakugo) {
  if (kakugo == null) return 0;
  return math.min(
    maxKakugoRewardBonus,
    math.max(0, kakugo.ratePerMinute ~/ 10),
  );
}

/// Tokens granted for a successful wake-up.
///
/// Pure. Base grant, plus a bonus for how much was at stake. Tokens can never
/// be turned back into coins, so this cannot soften the penalty.
int rewardTokens(Kakugo? kakugo) => baseRewardTokens + kakugoRewardBonus(kakugo);

/// XP granted for a successful wake-up. Pure.
///
/// Same shape as [rewardTokens]: waking up is the only source, and a night with
/// more on the line is worth more. XP is never spent, so this only ever adds.
int rewardXp(Kakugo? kakugo) => baseRewardXp + kakugoRewardBonus(kakugo);
