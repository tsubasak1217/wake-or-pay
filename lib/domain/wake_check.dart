import 'dart:math';

import 'models/alarm.dart';

/// What [WakeCheckType.random] draws from. Itself excluded, obviously; a draw
/// always lands on a check that can actually be performed.
const randomWakeCheckPool = <WakeCheckType>[
  WakeCheckType.longPress,
  WakeCheckType.math,
  WakeCheckType.typing,
  WakeCheckType.shake,
];

/// The check this ring will actually ask for. Pure given [random].
///
/// Anything but [WakeCheckType.random] passes straight through, so this is
/// safe to call for every ring.
WakeCheckType resolveWakeCheck(WakeCheckType chosen, Random random) =>
    chosen == WakeCheckType.random
    ? randomWakeCheckPool[random.nextInt(randomWakeCheckPool.length)]
    : chosen;

/// How long the button has to be held down.
const longPressDuration = Duration(seconds: 5);

/// How many additions in a row must be right.
const mathProblemCount = 3;

/// A two digit + two digit addition. Pure data.
class MathProblem {
  const MathProblem(this.left, this.right);

  final int left;
  final int right;

  int get answer => left + right;

  @override
  String toString() => '$left + $right';
}

/// Both operands are always two digits, so the sum is never trivial. Pure
/// given [random].
MathProblem generateMathProblem(Random random) =>
    MathProblem(10 + random.nextInt(90), 10 + random.nextInt(90));

/// Sentences for the typing check: around 12 Japanese characters each, and all
/// of them a promise the user is making to themselves.
const typingSentences = <String>[
  '今日も絶対に起きる',
  '二度寝はもうしない',
  'おじさんに払わない',
  '布団から出る覚悟',
  '朝の自分を裏切らない',
];

String pickTypingSentence(Random random) =>
    typingSentences[random.nextInt(typingSentences.length)];

/// How far through the hold we are, 0.0-1.0. Pure.
double longPressProgress(Duration held) {
  if (held.isNegative) return 0;
  return (held.inMilliseconds / longPressDuration.inMilliseconds).clamp(
    0.0,
    1.0,
  );
}

/// Whole seconds still to hold, for the countdown label. Pure.
int longPressSecondsLeft(Duration held) {
  final left = longPressDuration - held;
  return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
}
