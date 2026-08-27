import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/level.dart';

void main() {
  group('xpForLevel', () {
    test('the published curve', () {
      const expected = {
        1: 0,
        2: 50,
        3: 150,
        4: 300,
        5: 500,
        10: 2250,
        20: 9500,
      };
      expected.forEach((level, xp) {
        expect(xpForLevel(level), xp, reason: 'Lv$level');
      });
    });

    test('below level 1 is not a level', () {
      expect(xpForLevel(0), 0);
      expect(xpForLevel(-5), 0);
    });
  });

  group('levelForXp', () {
    test('a boundary belongs to the level it buys', () {
      expect(levelForXp(49), 1);
      expect(levelForXp(50), 2);
      expect(levelForXp(149), 2);
      expect(levelForXp(150), 3);
    });

    test('nothing earned is level 1, and so is a corrupt negative', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(-1), 1);
      expect(levelForXp(-100000), 1);
    });

    test('agrees with a plain loop over the curve', () {
      // The closed form is what ships; the loop is the definition. They are
      // checked against each other rather than against a table of guesses.
      var level = 1;
      for (var xp = 0; xp < 3000; xp++) {
        while (xpForLevel(level + 1) <= xp) {
          level++;
        }
        expect(levelForXp(xp), level, reason: 'xp $xp');
      }
    });

    test('a huge xp answers without searching', () {
      // 25·n·(n−1) at n = 1,000,001 — the level above it must not be reached.
      const xp = 25 * 1000001 * 1000000;
      expect(levelForXp(xp), 1000001);
      expect(levelForXp(xp - 1), 1000000);
    });
  });

  group('xpToNext', () {
    test('counts down to the next boundary', () {
      expect(xpToNext(0), 50);
      expect(xpToNext(49), 1);
      expect(xpToNext(50), 100);
      expect(xpToNext(149), 1);
    });

    test('never returns zero or less', () {
      for (final xp in [-10, 0, 50, 150, 300, 12345]) {
        expect(xpToNext(xp), greaterThan(0), reason: 'xp $xp');
      }
    });
  });

  group('levelProgress', () {
    test('0 at the floor of a level, just under 1 at its ceiling', () {
      expect(levelProgress(0), 0);
      expect(levelProgress(50), 0);
      expect(levelProgress(150), 0);
      expect(levelProgress(49), closeTo(49 / 50, 1e-9));
      expect(levelProgress(149), closeTo(99 / 100, 1e-9));
    });

    test('half way through level 2', () {
      expect(levelProgress(100), closeTo(0.5, 1e-9));
    });

    test('a negative xp reads as the very start', () {
      expect(levelProgress(-1), 0);
    });
  });
}
