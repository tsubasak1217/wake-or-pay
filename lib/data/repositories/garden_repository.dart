import 'dart:async';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/garden_catalog.dart';
import '../../domain/models.dart';
import '../database.dart';

/// Everything the garden persists: placements, unplaced items, and the one bit
/// recording that the free starter set has already been handed out.
class GardenRepository {
  GardenRepository(this._db, this._prefs);

  /// Set once, the first time the garden is opened. Kept out of the database
  /// so an install that wipes its garden on purpose still is not re-granted.
  static const _grantedKey = 'garden.initialGrantDone';

  final AppDatabase _db;
  final SharedPreferences _prefs;

  GardenPlacement _toModel(GardenPlacementRow row) => GardenPlacement(
    id: row.id,
    itemId: row.itemId,
    x: row.x,
    y: row.y,
    placedAt: DateTime.fromMillisecondsSinceEpoch(row.placedAtMs),
    growthStage: row.growthStage,
  );

  GardenPlacementRowsCompanion _toCompanion(GardenPlacement p) =>
      GardenPlacementRowsCompanion(
        id: Value(p.id),
        itemId: Value(p.itemId),
        x: Value(p.x),
        y: Value(p.y),
        placedAtMs: Value(p.placedAt.millisecondsSinceEpoch),
        growthStage: Value(p.growthStage),
      );

  GardenInventory _inventoryOf(List<GardenInventoryRow> rows) =>
      GardenInventory(
        owned: {
          for (final row in rows)
            if (row.count > 0) row.itemId: row.count,
        },
      );

  Future<GardenState> read() async => GardenState(
    placements: (await _db.select(_db.gardenPlacementRows).get())
        .map(_toModel)
        .toList(),
    inventory: _inventoryOf(await _db.select(_db.gardenInventoryRows).get()),
  );

  /// Placements and inventory always change together — a move takes an item
  /// out of one and puts it in the other — so this re-reads both on any change
  /// rather than combining two independent query streams, which would emit an
  /// intermediate state where the item exists in neither.
  ///
  /// Written with an explicit controller rather than `async*` over
  /// `await for`: a generator parked on an update stream that may never emit
  /// again does not finish cancelling, which hangs whoever disposes it.
  Stream<GardenState> watch() {
    final controller = StreamController<GardenState>();
    StreamSubscription<Set<TableUpdate>>? updates;

    Future<void> emit() async {
      final state = await read();
      if (!controller.isClosed) controller.add(state);
    }

    controller.onListen = () {
      updates = _db
          .tableUpdates(
            TableUpdateQuery.onAllTables([
              _db.gardenPlacementRows,
              _db.gardenInventoryRows,
            ]),
          )
          .listen((_) => emit());
      emit();
    };
    controller.onCancel = () async {
      await updates?.cancel();
      updates = null;
    };
    return controller.stream;
  }

  /// Replaces the whole garden in one transaction. Edit mode builds its result
  /// in memory and commits it here, so a half-applied rearrangement is not a
  /// state the database can be left in.
  Future<void> write(GardenState state) => _db.transaction(() async {
    await _db.delete(_db.gardenPlacementRows).go();
    await _db.batch(
      (b) => b.insertAll(
        _db.gardenPlacementRows,
        state.placements.map(_toCompanion).toList(),
      ),
    );
    await _db.delete(_db.gardenInventoryRows).go();
    await _db.batch(
      (b) => b.insertAll(_db.gardenInventoryRows, [
        for (final entry in state.inventory.owned.entries)
          if (entry.value > 0)
            GardenInventoryRowsCompanion(
              itemId: Value(entry.key),
              count: Value(entry.value),
            ),
      ]),
    );
  });

  Future<GardenState> update(GardenState Function(GardenState) change) async {
    final next = change(await read());
    await write(next);
    return next;
  }

  Future<void> savePlacement(GardenPlacement placement) => _db
      .into(_db.gardenPlacementRows)
      .insertOnConflictUpdate(_toCompanion(placement));

  bool get initialGrantDone => _prefs.getBool(_grantedKey) ?? false;

  /// Hands out the free starter set exactly once, with the plant already on
  /// the ground so the garden is never empty on the first visit.
  Future<GardenState> grantInitialIfNeeded({DateTime? now}) async {
    final current = await read();
    if (initialGrantDone) return current;
    await _prefs.setBool(_grantedKey, true);

    var inventory = current.inventory;
    for (final entry in initialGardenGrant.entries) {
      inventory = inventory.add(entry.key, entry.value);
    }

    final placements = [...current.placements];
    final def = GardenCatalog.byId(initialPlacedItemId);
    if (def != null && inventory.countOf(initialPlacedItemId) > 0) {
      inventory = inventory.remove(initialPlacedItemId);
      placements.add(
        GardenPlacement(
          id: 'initial-$initialPlacedItemId',
          itemId: initialPlacedItemId,
          // Middle of the 8x6 floor.
          x: (gardenGridWidth - def.width) ~/ 2,
          y: (gardenGridHeight - def.height) ~/ 2,
          placedAt: now ?? DateTime.now(),
        ),
      );
    }

    final next = GardenState(placements: placements, inventory: inventory);
    await write(next);
    return next;
  }
}
