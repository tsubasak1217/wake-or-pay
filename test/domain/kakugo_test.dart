import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';

void main() {
  group('withCap', () {
    const base = Kakugo(ratePerMinute: 800, cap: 1000, snoozePenalty: 900);

    test('cuts both penalties down to a lowered cap', () {
      final cut = withCap(base, 300);
      expect(cut.cap, 300);
      expect(cut.ratePerMinute, 300);
      expect(cut.snoozePenalty, 300);
    });

    test('leaves values already under the cap alone', () {
      final same = withCap(base, 2500);
      expect(same.cap, 2500);
      expect(same.ratePerMinute, 800);
      expect(same.snoozePenalty, 900);
    });

    test('clamps only what is over: rate under, snooze over', () {
      final cut = withCap(
        const Kakugo(ratePerMinute: 100, cap: 1000, snoozePenalty: 900),
        500,
      );
      expect(cut.ratePerMinute, 100);
      expect(cut.snoozePenalty, 500);
    });

    test(
      'normalises the cap first, and clamps against the normalised value',
      () {
        final low = withCap(base, 0);
        expect(low.cap, minKakugoCap);
        expect(low.ratePerMinute, minKakugoCap);
        expect(low.snoozePenalty, minKakugoCap);

        final high = withCap(base, 999999);
        expect(high.cap, maxKakugoCap);
        expect(high.ratePerMinute, 800, reason: 'nothing to cut');
      },
    );

    test('touches nothing else', () {
      const withFlags = Kakugo(
        ratePerMinute: 100,
        cap: 1000,
        snoozePenalty: 50,
        snoozeResetsClock: true,
      );
      final cut = withCap(withFlags, 800);
      expect(cut.snoozeResetsClock, isTrue);
      expect(cut.hostage, HostageType.coin);
    });
  });

  test('the penalty bounds are the cap ceiling', () {
    expect(maxKakugoRate, maxKakugoCap);
    expect(maxSnoozePenalty, maxKakugoCap);
  });
}
