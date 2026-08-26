import 'dart:math' as math;

import 'models.dart';

const baseRewardTokens = 10;
const maxKakugoRewardBonus = 50;

/// Tokens granted for a successful wake-up.
///
/// Pure. Base grant, plus a bonus for how much was at stake. Tokens can never
/// be turned back into coins, so this cannot soften the penalty.
int rewardTokens(Kakugo? kakugo) {
  if (kakugo == null) return baseRewardTokens;
  final bonus = math.min(
    maxKakugoRewardBonus,
    math.max(0, kakugo.ratePerMinute ~/ 10),
  );
  return baseRewardTokens + bonus;
}
