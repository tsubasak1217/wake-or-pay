import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/reward.dart';

void main() {
  group('rewardTokens', () {
    test('a plain alarm still pays the base grant', () {
      expect(rewardTokens(null), 10);
    });

    test('bonus is rate/10, floored', () {
      expect(rewardTokens(const Kakugo(ratePerMinute: 1, cap: 100)), 10);
      expect(rewardTokens(const Kakugo(ratePerMinute: 9, cap: 100)), 10);
      expect(rewardTokens(const Kakugo(ratePerMinute: 10, cap: 100)), 11);
      expect(rewardTokens(const Kakugo(ratePerMinute: 99, cap: 100)), 19);
      expect(rewardTokens(const Kakugo(ratePerMinute: 100, cap: 100)), 20);
    });

    test('bonus is capped at 50', () {
      expect(rewardTokens(const Kakugo(ratePerMinute: 500, cap: 100)), 60);
      expect(rewardTokens(const Kakugo(ratePerMinute: 501, cap: 100)), 60);
      expect(rewardTokens(const Kakugo(ratePerMinute: 100000, cap: 100)), 60);
    });

    test('rate 0 gets no bonus', () {
      expect(rewardTokens(const Kakugo(ratePerMinute: 0, cap: 100)), 10);
    });

    test('the cap does not affect the reward', () {
      expect(
        rewardTokens(const Kakugo(ratePerMinute: 100, cap: 0)),
        rewardTokens(const Kakugo(ratePerMinute: 100, cap: 999999)),
      );
    });
  });

  group('rewardXp', () {
    test('a plain alarm still pays the base grant', () {
      expect(rewardXp(null), 10);
    });

    test('bonus is rate/10, floored', () {
      expect(rewardXp(const Kakugo(ratePerMinute: 1, cap: 100)), 10);
      expect(rewardXp(const Kakugo(ratePerMinute: 9, cap: 100)), 10);
      expect(rewardXp(const Kakugo(ratePerMinute: 10, cap: 100)), 11);
      expect(rewardXp(const Kakugo(ratePerMinute: 99, cap: 100)), 19);
      expect(rewardXp(const Kakugo(ratePerMinute: 100, cap: 100)), 20);
    });

    test('bonus is capped at 50', () {
      expect(rewardXp(const Kakugo(ratePerMinute: 500, cap: 100)), 60);
      expect(rewardXp(const Kakugo(ratePerMinute: 501, cap: 100)), 60);
      expect(rewardXp(const Kakugo(ratePerMinute: 100000, cap: 100)), 60);
    });

    test('rate 0 gets no bonus', () {
      expect(rewardXp(const Kakugo(ratePerMinute: 0, cap: 100)), 10);
    });

    test('the cap does not affect the reward', () {
      expect(
        rewardXp(const Kakugo(ratePerMinute: 100, cap: 0)),
        rewardXp(const Kakugo(ratePerMinute: 100, cap: 999999)),
      );
    });

    test('XP and tokens move together, because the bonus is one rule', () {
      for (final rate in [0, 5, 10, 99, 400, 500, 5000]) {
        final kakugo = Kakugo(ratePerMinute: rate, cap: 1000);
        expect(rewardXp(kakugo), rewardTokens(kakugo), reason: 'rate $rate');
      }
    });
  });
}
