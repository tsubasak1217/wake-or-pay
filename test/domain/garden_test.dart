import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/garden.dart';
import 'package:wake_or_pay/domain/garden_catalog.dart';
import 'package:wake_or_pay/domain/ojisan.dart';
import 'package:wake_or_pay/domain/models.dart';

AlarmSession _session(DateTime firedAt, SessionStatus status) => AlarmSession(
  id: '${firedAt.toIso8601String()}-${status.name}',
  alarmId: 'a1',
  firedAt: firedAt,
  status: status,
);

AlarmSession _ok(int day, [int hour = 7]) =>
    _session(DateTime(2026, 8, day, hour), SessionStatus.success);

AlarmSession _bad(int day, [int hour = 7]) =>
    _session(DateTime(2026, 8, day, hour), SessionStatus.failed);

GardenPlacement _plant(String itemId, {int x = 0, int y = 0, int? placedDay}) =>
    GardenPlacement(
      id: 'p-$itemId-$x-$y',
      itemId: itemId,
      x: x,
      y: y,
      placedAt: DateTime(2026, 8, placedDay ?? 1),
    );

void main() {
  group('computeStreak', () {
    test('no history is a zero streak', () {
      expect(computeStreak(const [], DateTime(2026, 8, 27)), const Streak());
    });

    test('consecutive success days accumulate', () {
      final streak = computeStreak([
        _ok(25),
        _ok(26),
        _ok(27),
      ], DateTime(2026, 8, 27));
      expect(streak.currentStreakDays, 3);
      expect(streak.bestStreakDays, 3);
      expect(streak.totalSuccessDays, 3);
    });

    test('a day with no session does not break the streak', () {
      // Nothing rang on the 26th — a day off is not a failure.
      final streak = computeStreak([_ok(25), _ok(27)], DateTime(2026, 8, 27));
      expect(streak.currentStreakDays, 2);
      expect(streak.bestStreakDays, 2);
    });

    test('one failure breaks it, and the best is remembered', () {
      final streak = computeStreak([
        _ok(20),
        _ok(21),
        _ok(22),
        _ok(23),
        _bad(24),
        _ok(25),
        _ok(26),
      ], DateTime(2026, 8, 27));
      expect(streak.currentStreakDays, 2);
      expect(streak.bestStreakDays, 4);
      expect(streak.totalSuccessDays, 6);
    });

    test('a day is a success only if every session on it succeeded', () {
      final streak = computeStreak([
        _ok(26),
        _ok(27, 6),
        _bad(27, 8),
      ], DateTime(2026, 8, 27));
      expect(streak.currentStreakDays, 0, reason: 'the 27th failed');
      expect(streak.totalSuccessDays, 1);
    });

    test('several successes on one day still count as one day', () {
      final streak = computeStreak([
        _ok(27, 6),
        _ok(27, 7),
        _ok(27, 8),
      ], DateTime(2026, 8, 27));
      expect(streak.currentStreakDays, 1);
      expect(streak.totalSuccessDays, 1);
    });

    test('a session still ringing neither earns nor breaks a day', () {
      final streak = computeStreak([
        _ok(26),
        _session(DateTime(2026, 8, 27, 7), SessionStatus.ringing),
      ], DateTime(2026, 8, 27));
      expect(streak.currentStreakDays, 1);
      expect(streak.totalSuccessDays, 1);
    });

    test('a failure since the last success zeroes the current streak', () {
      final streak = computeStreak([
        _ok(24),
        _ok(25),
        _bad(26),
      ], DateTime(2026, 8, 27));
      expect(streak.currentStreakDays, 0);
      expect(streak.bestStreakDays, 2);
    });

    test('sessions dated after today are ignored for the current streak', () {
      final streak = computeStreak([
        _ok(26),
        _ok(27),
        _bad(30),
      ], DateTime(2026, 8, 27));
      expect(streak.currentStreakDays, 2);
    });
  });

  group('stageForStreakDays', () {
    test('boundaries are 3, 7 and 14', () {
      expect(stageForStreakDays(0), 0);
      expect(stageForStreakDays(2), 0);
      expect(stageForStreakDays(3), 1);
      expect(stageForStreakDays(6), 1);
      expect(stageForStreakDays(7), 2);
      expect(stageForStreakDays(13), 2);
      expect(stageForStreakDays(14), 3);
      expect(stageForStreakDays(400), 3, reason: 'never past 開花');
    });
  });

  group('growthStageFor', () {
    Map<DateTime, DayResult> daysOf(List<AlarmSession> sessions) =>
        classifyDays(sessions);

    test('a fresh plant is a sprout', () {
      expect(
        growthStageFor(
          _plant('plant_moss'),
          daysOf(const []),
          DateTime(2026, 8, 1),
        ),
        0,
      );
    });

    test('three consecutive days make a leaf, seven a bud', () {
      final sessions = [for (var d = 1; d <= 7; d += 1) _ok(d)];
      expect(
        growthStageFor(
          _plant('plant_moss'),
          daysOf(sessions.take(3).toList()),
          DateTime(2026, 8, 3),
        ),
        1,
      );
      expect(
        growthStageFor(
          _plant('plant_moss'),
          daysOf(sessions),
          DateTime(2026, 8, 7),
        ),
        2,
      );
    });

    test('fourteen days flower it', () {
      final sessions = [for (var d = 1; d <= 14; d += 1) _ok(d)];
      expect(
        growthStageFor(
          _plant('plant_moss'),
          daysOf(sessions),
          DateTime(2026, 8, 14),
        ),
        3,
      );
    });

    test('a break steps back exactly one stage, not to zero', () {
      final sessions = [for (var d = 1; d <= 14; d += 1) _ok(d), _bad(15)];
      expect(
        growthStageFor(
          _plant('plant_moss'),
          daysOf(sessions),
          DateTime(2026, 8, 15),
        ),
        2,
      );
    });

    test('two breaks step back twice', () {
      final sessions = [
        for (var d = 1; d <= 14; d += 1) _ok(d),
        _bad(15),
        _bad(16),
      ];
      expect(
        growthStageFor(
          _plant('plant_moss'),
          daysOf(sessions),
          DateTime(2026, 8, 16),
        ),
        1,
      );
    });

    test('it never dies', () {
      final sessions = [for (var d = 1; d <= 10; d += 1) _bad(d)];
      expect(
        growthStageFor(
          _plant('plant_moss'),
          daysOf(sessions),
          DateTime(2026, 8, 10),
        ),
        0,
      );
    });

    test('a plant does not inherit a streak from before it was placed', () {
      final sessions = [for (var d = 1; d <= 20; d += 1) _ok(d)];
      // Placed on the 19th: only the 19th and 20th count.
      expect(
        growthStageFor(
          _plant('plant_moss', placedDay: 19),
          daysOf(sessions),
          DateTime(2026, 8, 20),
        ),
        0,
      );
    });

    test('idle days between successes do not reset the run', () {
      final sessions = [_ok(1), _ok(5), _ok(9)];
      expect(
        growthStageFor(
          _plant('plant_moss'),
          daysOf(sessions),
          DateTime(2026, 8, 9),
        ),
        1,
        reason: 'three success days, no failure between them',
      );
    });
  });

  group('hutStageFor', () {
    test('uses the same boundaries as the ojisan line', () {
      expect(hutStageFor(0), 0);
      expect(hutStageFor(2), 0);
      expect(hutStageFor(3), 1);
      expect(hutStageFor(9), 1);
      expect(hutStageFor(10), 2);
      expect(hutStageFor(19), 2);
      expect(hutStageFor(20), 3);
      expect(hutStageFor(100), 3);
    });

    test('every stage change lines up with a change of line', () {
      for (var n = 0; n <= 30; n += 1) {
        final stageChanged = n > 0 && hutStageFor(n) != hutStageFor(n - 1);
        final lineChanged = n > 0 && ojisanLine(n) != ojisanLine(n - 1);
        expect(stageChanged, lineChanged, reason: 'at $n oversleeps');
      }
    });

    test('there is a name and an emoji for every stage', () {
      expect(hutStageEmoji, hasLength(4));
      expect(hutStageNames, hasLength(4));
    });
  });

  group('canPlace', () {
    const empty = GardenState();

    test('an unknown item can never be placed', () {
      expect(canPlace(empty, 'nope', 0, 0), isFalse);
    });

    test('a 1x1 fits anywhere on an empty grid', () {
      expect(canPlace(empty, 'plant_moss', 0, 0), isTrue);
      expect(canPlace(empty, 'plant_moss', 7, 5), isTrue);
    });

    test('out of bounds is rejected in every direction', () {
      expect(canPlace(empty, 'plant_moss', -1, 0), isFalse);
      expect(canPlace(empty, 'plant_moss', 0, -1), isFalse);
      expect(canPlace(empty, 'plant_moss', 8, 0), isFalse);
      expect(canPlace(empty, 'plant_moss', 0, 6), isFalse);
    });

    test('a 2x2 needs its whole footprint inside the grid', () {
      expect(canPlace(empty, 'plant_sapling', 6, 4), isTrue);
      expect(canPlace(empty, 'plant_sapling', 7, 4), isFalse);
      expect(canPlace(empty, 'plant_sapling', 6, 5), isFalse);
    });

    test('overlapping an existing placement is rejected', () {
      final state = GardenState(
        placements: [_plant('plant_sapling', x: 2, y: 2)],
      );
      expect(canPlace(state, 'plant_moss', 2, 2), isFalse);
      expect(canPlace(state, 'plant_moss', 3, 3), isFalse);
      expect(canPlace(state, 'plant_moss', 4, 4), isTrue);
      expect(canPlace(state, 'plant_moss', 1, 1), isTrue);
    });

    test('a placement being moved does not collide with itself', () {
      final sapling = _plant('plant_sapling', x: 2, y: 2);
      final state = GardenState(placements: [sapling]);
      expect(canPlace(state, 'plant_sapling', 3, 2), isFalse);
      expect(
        canPlace(state, 'plant_sapling', 3, 2, ignorePlacementId: sapling.id),
        isTrue,
      );
    });

    test('a smaller grid shrinks what fits', () {
      expect(
        canPlace(
          empty,
          'plant_moss',
          3,
          0,
          gridSize: const GridSize(width: 3, height: 3),
        ),
        isFalse,
      );
    });
  });

  group('exchange', () {
    test('enough tokens buys the item and leaves coins alone', () {
      final result = exchange(
        const GardenInventory(),
        const Wallet(coins: 5000, tokens: 100),
        GardenCatalog.moss,
      );
      expect(result, isNotNull);
      expect(result!.inventory.countOf('plant_moss'), 1);
      expect(result.wallet.tokens, 70);
      expect(result.wallet.coins, 5000, reason: 'coins are never spent here');
    });

    test('too few tokens buys nothing', () {
      expect(
        exchange(
          const GardenInventory(),
          const Wallet(coins: 999999, tokens: 29),
          GardenCatalog.moss,
        ),
        isNull,
        reason: 'a mountain of coins cannot stand in for tokens',
      );
    });

    test('exactly the price is enough', () {
      final result = exchange(
        const GardenInventory(),
        const Wallet(tokens: 30),
        GardenCatalog.moss,
      );
      expect(result!.wallet.tokens, 0);
    });

    test('buying twice stacks in the inventory', () {
      var inventory = const GardenInventory();
      var wallet = const Wallet(tokens: 100);
      for (var i = 0; i < 2; i += 1) {
        final result = exchange(inventory, wallet, GardenCatalog.moss)!;
        inventory = result.inventory;
        wallet = result.wallet;
      }
      expect(inventory.countOf('plant_moss'), 2);
      expect(wallet.tokens, 40);
    });

    test('an item with no price cannot be bought', () {
      const giveaway = GardenItemDef(
        id: 'gift',
        name: '記念品',
        category: GardenCategory.deco,
        emoji: '🎁',
      );
      expect(
        exchange(
          const GardenInventory(),
          const Wallet(tokens: 99999),
          giveaway,
        ),
        isNull,
      );
    });
  });

  group('catalogue', () {
    test('ids are unique', () {
      final ids = GardenCatalog.all.map((i) => i.id).toSet();
      expect(ids, hasLength(GardenCatalog.all.length));
    });

    test('every growable item is a plant', () {
      for (final item in GardenCatalog.all.where((i) => i.growable)) {
        expect(item.category, GardenCategory.plant, reason: item.id);
      }
    });

    test('everything in the first grant exists in the catalogue', () {
      for (final id in initialGardenGrant.keys) {
        expect(GardenCatalog.byId(id), isNotNull, reason: id);
      }
      expect(initialGardenGrant[initialPlacedItemId], greaterThan(0));
    });

    test('the shop sells things and is ordered by price', () {
      final prices = GardenCatalog.purchasable
          .map((i) => i.costTokens!)
          .toList();
      expect(prices, isNotEmpty);
      expect(prices, orderedEquals(prices.toList()..sort()));
    });
  });

  group('GardenInventory', () {
    test('removing the last copy drops the key', () {
      final inventory = const GardenInventory().add('plant_moss');
      expect(inventory.remove('plant_moss').owned, isEmpty);
      expect(inventory.remove('plant_moss').isEmpty, isTrue);
    });

    test('available ids skip anything at zero', () {
      final inventory = const GardenInventory(
        owned: {'plant_moss': 0, 'deco_pebble': 2},
      );
      expect(inventory.availableItemIds, ['deco_pebble']);
    });
  });
}
