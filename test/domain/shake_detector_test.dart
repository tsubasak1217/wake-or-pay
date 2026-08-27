import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/shake_detector.dart';

Duration ms(int milliseconds) => Duration(milliseconds: milliseconds);

/// Feeds [count] samples [every] apart, all at [magnitude], starting at [from].
Duration feed(
  ShakeDetector detector, {
  required Duration from,
  required int count,
  required Duration every,
  required double magnitude,
}) {
  var at = from;
  for (var i = 0; i < count; i++) {
    at += every;
    detector.add(at, magnitude);
  }
  return at;
}

void main() {
  group('shakeMagnitude', () {
    test('is the length of the vector', () {
      expect(shakeMagnitude(0, 0, 0), 0);
      expect(shakeMagnitude(3, 4, 0), 5);
      expect(shakeMagnitude(-3, -4, 0), 5);
    });
  });

  group('ShakeDetector', () {
    test('starts empty and completes after five seconds of shaking', () {
      final detector = ShakeDetector();
      expect(detector.progress, 0);
      expect(detector.isComplete, isFalse);
      expect(detector.secondsLeft, 5);

      // 50 samples 100 ms apart, all above the threshold. The first sample
      // only opens the stretch, so five seconds of samples credit 4.9 s.
      feed(
        detector,
        from: Duration.zero,
        count: 50,
        every: ms(100),
        magnitude: 20,
      );
      expect(detector.isComplete, isFalse);
      expect(detector.held, ms(4900));

      detector.add(ms(5100), 20);
      expect(detector.isComplete, isTrue);
      expect(detector.progress, 1);
      expect(detector.secondsLeft, 0);
    });

    test('credits elapsed time, not samples: a faster sensor is no faster', () {
      final slow = ShakeDetector();
      final fast = ShakeDetector();

      feed(slow, from: Duration.zero, count: 20, every: ms(100), magnitude: 20);
      feed(fast, from: Duration.zero, count: 40, every: ms(50), magnitude: 20);

      expect(slow.held, ms(1900));
      expect(fast.held, ms(1950));
      expect((slow.held - fast.held).abs(), lessThan(ms(100)));
    });

    test('samples below the threshold credit nothing', () {
      final detector = ShakeDetector();
      feed(
        detector,
        from: Duration.zero,
        count: 50,
        every: ms(100),
        magnitude: shakeThreshold - 0.1,
      );
      expect(detector.held, Duration.zero);
      expect(detector.progress, 0);
    });

    test(
      'a gap under half a second is the turn of a real shake, and keeps',
      () {
        final detector = ShakeDetector();
        detector.add(ms(0), 20);
        detector.add(ms(400), 20);
        expect(detector.held, ms(400));

        // 400 ms of stillness, then shaking again: still under the tolerance.
        detector.add(ms(800), 20);
        expect(detector.held, ms(800), reason: 'the stretch continued');
      },
    );

    test('a gap over half a second throws the progress away', () {
      final detector = ShakeDetector();
      feed(
        detector,
        from: Duration.zero,
        count: 20,
        every: ms(100),
        magnitude: 20,
      );
      expect(detector.held, ms(1900));

      // A long stretch of stillness, sampled the whole way through.
      feed(detector, from: ms(2000), count: 10, every: ms(100), magnitude: 1);
      expect(detector.held, Duration.zero);

      // And the next shake starts from scratch, not from the length of the
      // pause.
      detector.add(ms(3200), 20);
      detector.add(ms(3300), 20);
      expect(detector.held, ms(100));
    });

    test('a silent gap resets even without samples in between', () {
      final detector = ShakeDetector();
      detector.add(ms(0), 20);
      detector.add(ms(400), 20);
      expect(detector.held, ms(400));

      detector.add(ms(2000), 20);
      expect(
        detector.held,
        Duration.zero,
        reason: 'the sensor going quiet is a gap too',
      );
    });

    test('progress is clamped and reset empties it', () {
      final detector = ShakeDetector();
      feed(
        detector,
        from: Duration.zero,
        count: 200,
        every: ms(100),
        magnitude: 20,
      );
      expect(detector.progress, 1, reason: 'clamped, never above one');

      detector.reset();
      expect(detector.held, Duration.zero);
      expect(detector.progress, 0);
      expect(detector.isComplete, isFalse);
    });
  });
}
