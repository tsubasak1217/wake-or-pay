import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/garden.dart';
import '../../domain/garden_catalog.dart';
import '../../domain/models.dart';
import 'garden_board.dart';
import 'garden_controller.dart';

/// What is being dragged. [placementId] is null when it came from the shelf.
@immutable
class GardenDrag {
  const GardenDrag({required this.itemId, this.placementId});

  final String itemId;
  final String? placementId;

  bool get fromShelf => placementId == null;
}

/// 模様替え. Everything is edited in a local draft and written in one go by
/// 完了, so backing out leaves the stored garden exactly as it was.
class GardenEditScreen extends ConsumerStatefulWidget {
  const GardenEditScreen({super.key});

  @override
  ConsumerState<GardenEditScreen> createState() => _GardenEditScreenState();
}

class _GardenEditScreenState extends ConsumerState<GardenEditScreen> {
  GardenState _draft = const GardenState();
  GardenDrag? _dragging;
  var _loaded = false;
  var _nextId = 0;

  @override
  Widget build(BuildContext context) {
    // The first garden to arrive seeds the draft; later changes to the store
    // are ignored so an edit in progress is never yanked out from under.
    final stored = ref.watch(gardenProvider).valueOrNull;
    if (!_loaded && stored != null) {
      _draft = stored;
      _loaded = true;
    }
    final hutStage = ref.watch(hutStageProvider);
    final stages = ref.watch(gardenViewProvider).stages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('模様替え'),
        actions: [TextButton(onPressed: _finish, child: const Text('完了'))],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('棚から地面へドラッグして置く。棚へ戻すとしまえる。'),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: GardenBoard(
                placements: _draft.placements,
                stages: stages,
                hutStage: hutStage,
                placementBuilder: _draggablePlacement,
                cellOverlayBuilder: _cellTarget,
                residentInteractive: false,
              ),
            ),
          ),
          _Shelf(
            inventory: _draft.inventory,
            dragging: _dragging,
            onDragStart: (drag) => setState(() => _dragging = drag),
            onDragEnd: () => setState(() => _dragging = null),
            onStore: _store,
          ),
        ],
      ),
    );
  }

  Widget _draggablePlacement(GardenPlacement placement, Widget tile) {
    final drag = GardenDrag(
      itemId: placement.itemId,
      placementId: placement.id,
    );
    return Draggable<GardenDrag>(
      data: drag,
      onDragStarted: () => setState(() => _dragging = drag),
      onDragEnd: (_) => setState(() => _dragging = null),
      feedback: _feedback(placement.itemId),
      // Empty rather than faded, so the cell underneath can accept a drop back
      // onto the spot the item just left.
      childWhenDragging: const SizedBox.shrink(),
      child: tile,
    );
  }

  Widget _feedback(String itemId) {
    final def = GardenCatalog.byId(itemId);
    if (def == null) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 56.0 * def.width,
        height: 56.0 * def.height,
        child: GardenItemTile(def: def, compact: true),
      ),
    );
  }

  Widget _cellTarget(int x, int y) {
    final drag = _dragging;
    final allowed =
        drag != null &&
        canPlace(
          _draft,
          drag.itemId,
          x,
          y,
          ignorePlacementId: drag.placementId,
        );

    return DragTarget<GardenDrag>(
      onWillAcceptWithDetails: (details) => canPlace(
        _draft,
        details.data.itemId,
        x,
        y,
        ignorePlacementId: details.data.placementId,
      ),
      onAcceptWithDetails: (details) => _drop(details.data, x, y),
      builder: (context, candidate, rejected) => Container(
        key: ValueKey('cell-$x-$y'),
        margin: const EdgeInsets.all(1),
        decoration: drag == null
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: allowed
                    ? Colors.green.withValues(
                        alpha: candidate.isEmpty ? 0.2 : 0.45,
                      )
                    : Colors.red.withValues(alpha: 0.28),
              ),
      ),
    );
  }

  void _drop(GardenDrag drag, int x, int y) {
    if (!canPlace(
      _draft,
      drag.itemId,
      x,
      y,
      ignorePlacementId: drag.placementId,
    )) {
      return;
    }

    setState(() {
      if (drag.fromShelf) {
        if (_draft.inventory.countOf(drag.itemId) <= 0) return;
        _draft = _draft.copyWith(
          inventory: _draft.inventory.remove(drag.itemId),
          placements: [
            ..._draft.placements,
            GardenPlacement(
              id: 'p${DateTime.now().microsecondsSinceEpoch}-${_nextId++}',
              itemId: drag.itemId,
              x: x,
              y: y,
              placedAt: DateTime.now(),
            ),
          ],
        );
      } else {
        _draft = _draft.copyWith(
          placements: [
            for (final placement in _draft.placements)
              if (placement.id == drag.placementId)
                placement.copyWith(x: x, y: y)
              else
                placement,
          ],
        );
      }
      _dragging = null;
    });
  }

  /// Drag back onto the shelf: the item leaves the ground and rejoins the
  /// unplaced pile. Its growth is lost with it, which is the whole cost.
  void _store(GardenDrag drag) {
    if (drag.fromShelf) return;
    setState(() {
      _draft = _draft.copyWith(
        placements: _draft.placements
            .where((p) => p.id != drag.placementId)
            .toList(),
        inventory: _draft.inventory.add(drag.itemId),
      );
      _dragging = null;
    });
  }

  Future<void> _finish() async {
    await ref.read(gardenRepositoryProvider).write(_draft);
    if (mounted) context.pop();
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.inventory,
    required this.dragging,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onStore,
  });

  final GardenInventory inventory;
  final GardenDrag? dragging;
  final void Function(GardenDrag) onDragStart;
  final VoidCallback onDragEnd;
  final void Function(GardenDrag) onStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ids = inventory.availableItemIds;

    return DragTarget<GardenDrag>(
      onWillAcceptWithDetails: (details) => !details.data.fromShelf,
      onAcceptWithDetails: (details) => onStore(details.data),
      builder: (context, candidate, rejected) => Container(
        key: const ValueKey('shelf'),
        height: 104,
        width: double.infinity,
        decoration: BoxDecoration(
          color: candidate.isEmpty
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.secondaryContainer,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: ids.isEmpty
            ? const Center(child: Text('手持ちのアイテムはありません'))
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: ids.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final id = ids[index];
                  final def = GardenCatalog.byId(id);
                  if (def == null) return const SizedBox.shrink();
                  final drag = GardenDrag(itemId: id);
                  return Draggable<GardenDrag>(
                    data: drag,
                    // Vertical affinity: a horizontal swipe still scrolls the
                    // shelf, an upward one picks the item up.
                    affinity: Axis.vertical,
                    onDragStarted: () => onDragStart(drag),
                    onDragEnd: (_) => onDragEnd(),
                    onDraggableCanceled: (_, _) => onDragEnd(),
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: 56.0 * def.width,
                        height: 56.0 * def.height,
                        child: GardenItemTile(def: def, compact: true),
                      ),
                    ),
                    child: SizedBox(
                      key: ValueKey('shelf-$id'),
                      width: 72,
                      child: Column(
                        children: [
                          Expanded(
                            child: GardenItemTile(def: def, compact: true),
                          ),
                          Text(
                            '×${inventory.countOf(id)}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
