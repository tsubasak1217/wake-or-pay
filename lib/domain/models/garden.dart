import 'package:flutter/foundation.dart';

/// Ground size of the terrarium, in cells. Origin is the bottom-left corner.
const gardenGridWidth = 8;
const gardenGridHeight = 6;

@immutable
class GridSize {
  const GridSize({
    this.width = gardenGridWidth,
    this.height = gardenGridHeight,
  });

  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is GridSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

const defaultGardenGrid = GridSize();

enum GardenCategory {
  plant('植物'),
  furniture('家具'),
  deco('小物');

  const GardenCategory(this.label);

  final String label;
}

/// One entry of the static catalogue. Never persisted — rows only store the
/// [id], so renaming or repricing an item never has to touch the database.
@immutable
class GardenItemDef {
  const GardenItemDef({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    this.width = 1,
    this.height = 1,
    this.growable = false,
    this.costTokens,
  });

  final String id;
  final String name;
  final GardenCategory category;

  /// Placeholder art. Replaced by a real sprite later; nothing else reads it.
  final String emoji;
  final int width;
  final int height;

  /// Plants grow with the wake-up streak. Everything else is static.
  final bool growable;

  /// Price at the seed shop. Null means it cannot be bought — granted only.
  final int? costTokens;

  bool get purchasable => costTokens != null;
}

@immutable
class GardenPlacement {
  const GardenPlacement({
    required this.id,
    required this.itemId,
    required this.x,
    required this.y,
    required this.placedAt,
    this.growthStage = 0,
  });

  final String id;
  final String itemId;
  final int x;
  final int y;
  final DateTime placedAt;

  /// Snapshot of the derived stage, 0..3. The truth is recomputed from session
  /// history by `growthStageFor`; this is what the garden last wrote back.
  final int growthStage;

  GardenPlacement copyWith({
    String? id,
    String? itemId,
    int? x,
    int? y,
    DateTime? placedAt,
    int? growthStage,
  }) => GardenPlacement(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    x: x ?? this.x,
    y: y ?? this.y,
    placedAt: placedAt ?? this.placedAt,
    growthStage: growthStage ?? this.growthStage,
  );

  @override
  bool operator ==(Object other) =>
      other is GardenPlacement &&
      other.id == id &&
      other.itemId == itemId &&
      other.x == x &&
      other.y == y &&
      other.placedAt == placedAt &&
      other.growthStage == growthStage;

  @override
  int get hashCode => Object.hash(id, itemId, x, y, placedAt, growthStage);

  @override
  String toString() => 'GardenPlacement($id, $itemId at ($x,$y), $growthStage)';
}

/// Items owned but not placed.
@immutable
class GardenInventory {
  const GardenInventory({this.owned = const {}});

  final Map<String, int> owned;

  int countOf(String itemId) => owned[itemId] ?? 0;

  bool get isEmpty => owned.values.every((c) => c <= 0);

  /// Item ids with at least one copy in hand, in catalogue-stable order.
  List<String> get availableItemIds =>
      (owned.entries.where((e) => e.value > 0).map((e) => e.key).toList()
        ..sort());

  GardenInventory add(String itemId, [int count = 1]) =>
      GardenInventory(owned: {...owned, itemId: countOf(itemId) + count});

  /// Removing below zero is a bug, not a state, so it clamps and the caller
  /// checks [countOf] first.
  GardenInventory remove(String itemId, [int count = 1]) {
    final next = countOf(itemId) - count;
    final owned = {...this.owned};
    if (next <= 0) {
      owned.remove(itemId);
    } else {
      owned[itemId] = next;
    }
    return GardenInventory(owned: owned);
  }

  @override
  bool operator ==(Object other) =>
      other is GardenInventory && mapEquals(other.owned, owned);

  @override
  int get hashCode => Object.hashAllUnordered(
    owned.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() => 'GardenInventory($owned)';
}

@immutable
class GardenState {
  const GardenState({
    this.placements = const [],
    this.inventory = const GardenInventory(),
  });

  final List<GardenPlacement> placements;
  final GardenInventory inventory;

  GardenState copyWith({
    List<GardenPlacement>? placements,
    GardenInventory? inventory,
  }) => GardenState(
    placements: placements ?? this.placements,
    inventory: inventory ?? this.inventory,
  );

  @override
  bool operator ==(Object other) =>
      other is GardenState &&
      listEquals(other.placements, placements) &&
      other.inventory == inventory;

  @override
  int get hashCode => Object.hash(Object.hashAll(placements), inventory);
}

/// Derived from session history, never stored.
@immutable
class Streak {
  const Streak({
    this.currentStreakDays = 0,
    this.bestStreakDays = 0,
    this.totalSuccessDays = 0,
  });

  final int currentStreakDays;
  final int bestStreakDays;
  final int totalSuccessDays;

  @override
  bool operator ==(Object other) =>
      other is Streak &&
      other.currentStreakDays == currentStreakDays &&
      other.bestStreakDays == bestStreakDays &&
      other.totalSuccessDays == totalSuccessDays;

  @override
  int get hashCode =>
      Object.hash(currentStreakDays, bestStreakDays, totalSuccessDays);

  @override
  String toString() =>
      'Streak(current $currentStreakDays, best $bestStreakDays, '
      'total $totalSuccessDays)';
}
