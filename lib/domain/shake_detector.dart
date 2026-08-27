import 'dart:math';

/// Acceleration, gravity removed, above which the phone counts as being
/// shaken. 12 m/s² is well past what carrying a phone produces and well under
/// a deliberate shake.
const shakeThreshold = 12.0;

/// How long the shaking has to go on for.
const shakeDuration = Duration(seconds: 5);

/// A break longer than this throws the progress away. Shorter gaps are the
/// turning points of an ordinary shake — the hand is momentarily still at each
/// end of the stroke — and must not punish the user.
const shakeGapTolerance = Duration(milliseconds: 500);

/// The magnitude of one accelerometer sample. Pure.
double shakeMagnitude(double x, double y, double z) =>
    sqrt(x * x + y * y + z * z);

/// One accelerometer reading, stamped when it arrived.
///
/// The stamp is taken where the samples are produced rather than where they are
/// consumed, so the detector never has to read a clock — and a test can hand it
/// five seconds of shaking without waiting five seconds.
///
/// Deliberately without value equality: two identical readings in a row are two
/// events, and anything that de-duplicates them would stall the count.
class ShakeSample {
  const ShakeSample(this.at, this.magnitude);

  final Duration at;
  final double magnitude;
}

/// Turns a stream of accelerometer samples into progress towards "shaken for
/// five seconds".
///
/// Pure logic with no dependency on sensors or on wall clock time: every
/// sample carries its own timestamp, so the whole thing is unit-testable —
/// which matters here, because an emulator cannot be shaken.
class ShakeDetector {
  ShakeDetector({
    this.threshold = shakeThreshold,
    this.duration = shakeDuration,
    this.gapTolerance = shakeGapTolerance,
  });

  final double threshold;
  final Duration duration;
  final Duration gapTolerance;

  Duration _held = Duration.zero;
  Duration? _lastAbove;

  /// How much continuous shaking has been accumulated.
  Duration get held => _held;

  double get progress =>
      (_held.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);

  bool get isComplete => _held >= duration;

  /// Whole seconds still to shake, for the countdown label.
  int get secondsLeft {
    final left = duration - _held;
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  /// Feeds one sample taken [at] (measured from any fixed origin) and returns
  /// the new [progress].
  ///
  /// Time is only credited *between* two samples that are both above the
  /// threshold, so the accumulated total is the time actually spent shaking
  /// rather than a count of samples: a faster sensor cannot clear the check
  /// sooner.
  double addSample(ShakeSample sample) => add(sample.at, sample.magnitude);

  double add(Duration at, double magnitude) {
    final last = _lastAbove;
    if (magnitude >= threshold) {
      if (last != null) {
        final gap = at - last;
        _held = gap > gapTolerance ? Duration.zero : _held + gap;
      }
      _lastAbove = at;
    } else if (last != null && at - last > gapTolerance) {
      // Stopped for too long: back to nothing, and the next shake starts a
      // fresh stretch rather than counting the whole pause.
      _held = Duration.zero;
      _lastAbove = null;
    }
    return progress;
  }

  void reset() {
    _held = Duration.zero;
    _lastAbove = null;
  }
}
