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
        expect(high.cap, absoluteMaxKakugoCap);
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

  test('the penalty bounds are the hard cap ceiling', () {
    expect(maxKakugoRate, absoluteMaxKakugoCap);
    expect(maxSnoozePenalty, absoluteMaxKakugoCap);
  });

  group('the cap ceiling', () {
    test('normalizeKakugoCap clamps to the hard ceiling, not to the default', () {
      expect(absoluteMaxKakugoCap, 300000);
      expect(maxKakugoCap, 10000, reason: 'still the out-of-the-box ceiling');

      // A cap saved while オプション allowed 100,000 survives a read.
      expect(normalizeKakugoCap(50000), 50000);
      expect(normalizeKakugoCap(300000), 300000);
      expect(normalizeKakugoCap(999999), absoluteMaxKakugoCap);
      expect(normalizeKakugoCap(0), minKakugoCap);
    });

    test('the choices start at the default and end at the hard ceiling', () {
      expect(capCeilingChoices, [10000, 30000, 100000, 300000]);
      expect(capCeilingChoices.first, maxKakugoCap);
      expect(capCeilingChoices.last, absoluteMaxKakugoCap);
    });

    test('effectiveCapCeiling never drags a saved cap down', () {
      // The ordinary case: the setting is the bound.
      expect(effectiveCapCeiling(10000, 1000), 10000);
      // An alarm saved under a higher ceiling keeps its own room.
      expect(effectiveCapCeiling(10000, 50000), 50000);
      // Equal is equal.
      expect(effectiveCapCeiling(30000, 30000), 30000);
    });
  });

  group('HostageType', () {
    test('each hostage says what it is and what it is measured in', () {
      expect(HostageType.none.label, 'なし');
      expect(HostageType.coin.label, 'コイン');
      expect(HostageType.card.label, 'クレジットカード');

      // 1 コイン = 1 円: the same stored integer, two words for it.
      expect(HostageType.coin.unit, 'コイン');
      expect(HostageType.card.unit, '円');
      expect(
        HostageType.none.unit,
        'コイン',
        reason: 'none has no amounts on screen; it never reads its unit',
      );

      expect(HostageType.none.burns, isFalse);
      expect(HostageType.coin.burns, isTrue);
      expect(HostageType.card.burns, isTrue);
    });

    test('a new pledge puts nothing up until the user says what', () {
      expect(defaultKakugo.hostage, HostageType.none);
      expect(defaultKakugo.ratePerMinute, 100, reason: 'seeded for later');
    });

    test('every hostage survives a json round trip', () {
      for (final hostage in HostageType.values) {
        final kakugo = Kakugo(hostage: hostage, ratePerMinute: 100, cap: 1000);
        expect(Kakugo.fromJson(kakugo.toJson()), kakugo, reason: hostage.name);
      }
    });

    test('a missing or unknown hostage reads as coins', () {
      // The rule every row written before カード人質 existed was saved under.
      expect(
        Kakugo.fromJson({'ratePerMinute': 100, 'cap': 1000}).hostage,
        HostageType.coin,
      );
      expect(
        Kakugo.fromJson({
          'hostage': 'bitcoin',
          'ratePerMinute': 100,
          'cap': 1000,
        }).hostage,
        HostageType.coin,
      );
    });

    test('a rate under the minimum is the old spelling of 人質なし', () {
      // 「0 コイン/分」 used to mean 連絡だけの覚悟. It must not be rounded up to
      // 10 and start burning coins nobody pledged.
      final old = Kakugo.fromJson({
        'hostage': 'coin',
        'ratePerMinute': 0,
        'cap': 1000,
      });
      expect(old.hostage, HostageType.none);
      expect(old.ratePerMinute, 0, reason: 'kept exactly as written');

      expect(hostageFor('coin', minKakugoRate), HostageType.coin);
      expect(hostageFor('coin', minKakugoRate - 1), HostageType.none);
      expect(hostageFor('card', 0), HostageType.none);
      expect(hostageFor(null, 100), HostageType.coin);
      expect(hostageFor('none', 100), HostageType.none);
    });

    test('寝坊ペナルティ now starts at 10', () {
      expect(minKakugoRate, 10);
      expect(normalizeKakugoRate(5), 10);
      expect(
        minSnoozePenalty,
        0,
        reason: 'snoozing for free is a separate choice, and it stays',
      );
    });
  });
}
