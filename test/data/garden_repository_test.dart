import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/garden_catalog.dart';
import 'package:wake_or_pay/domain/models.dart';

import '../helpers.dart';

void main() {
  test(
    'the first grant hands out moss, two pebbles and a placed plant',
    () async {
      final container = await testContainer();
      final repository = container.read(gardenRepositoryProvider);

      expect(repository.initialGrantDone, isFalse);
      final state = await repository.grantInitialIfNeeded(
        now: DateTime(2026, 8, 27),
      );

      expect(state.inventory.countOf('plant_moss'), 1);
      expect(state.inventory.countOf('deco_pebble'), 2);
      expect(
        state.inventory.countOf(initialPlacedItemId),
        0,
        reason: 'the free plant went straight into the ground',
      );

      final placed = state.placements.single;
      expect(placed.itemId, initialPlacedItemId);
      expect(placed.x, 3, reason: 'middle of the 8 wide floor');
      expect(placed.y, 2, reason: 'middle of the 6 tall floor');
      expect(placed.placedAt, DateTime(2026, 8, 27));
    },
  );

  test('the grant is handed out exactly once', () async {
    final container = await testContainer();
    final repository = container.read(gardenRepositoryProvider);

    await repository.grantInitialIfNeeded();
    expect(repository.initialGrantDone, isTrue);

    // Spend everything, then ask again: nothing comes back.
    await repository.write(const GardenState());
    final after = await repository.grantInitialIfNeeded();
    expect(after.placements, isEmpty);
    expect(after.inventory.owned, isEmpty);
  });

  test('placements and inventory survive a reopen of the repository', () async {
    final container = await testContainer();
    final repository = container.read(gardenRepositoryProvider);

    await repository.write(
      GardenState(
        placements: [
          GardenPlacement(
            id: 'p1',
            itemId: 'deco_lamp',
            x: 5,
            y: 1,
            placedAt: DateTime(2026, 8, 20),
            growthStage: 2,
          ),
        ],
        inventory: const GardenInventory(owned: {'deco_pebble': 3}),
      ),
    );

    // A second repository over the same database is what a relaunch sees.
    final reopened = container.read(gardenRepositoryProvider);
    final state = await reopened.read();
    expect(state.placements.single.itemId, 'deco_lamp');
    expect(state.placements.single.x, 5);
    expect(state.placements.single.y, 1);
    expect(state.placements.single.growthStage, 2);
    expect(state.placements.single.placedAt, DateTime(2026, 8, 20));
    expect(state.inventory.countOf('deco_pebble'), 3);
  });

  test('writing replaces the garden rather than appending to it', () async {
    final container = await testContainer();
    final repository = container.read(gardenRepositoryProvider);

    await repository.write(
      GardenState(
        placements: [
          GardenPlacement(
            id: 'p1',
            itemId: 'deco_lamp',
            x: 0,
            y: 0,
            placedAt: DateTime(2026, 8, 20),
          ),
        ],
        inventory: const GardenInventory(owned: {'deco_pebble': 3}),
      ),
    );
    await repository.write(const GardenState());

    final state = await repository.read();
    expect(state.placements, isEmpty);
    expect(state.inventory.owned, isEmpty);
  });

  test('watch emits the current garden and every later change', () async {
    final container = await testContainer();
    final repository = container.read(gardenRepositoryProvider);

    final seen = <GardenState>[];
    final sub = repository.watch().listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    await repository.update(
      (s) => s.copyWith(inventory: s.inventory.add('deco_pebble')),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(seen.first.inventory.owned, isEmpty);
    expect(seen.last.inventory.countOf('deco_pebble'), 1);
  });

  test('the garden provider grants before it emits', () async {
    final container = await testContainer();
    final state = await container.read(gardenProvider.future);
    expect(state.placements, hasLength(1));
    expect(state.inventory.countOf('plant_moss'), 1);
  });
}
