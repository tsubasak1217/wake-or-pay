import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/garden.dart';
import '../../domain/garden_catalog.dart';
import '../../domain/models.dart';
import 'terrarium_painter.dart';

/// Where the 8x6 floor ended up inside the jar, in local coordinates.
@immutable
class GardenGeometry {
  const GardenGeometry({
    required this.cell,
    required this.left,
    required this.bottom,
  });

  final double cell;
  final double left;
  final double bottom;

  double xOf(int x) => left + x * cell;
  double yOf(int y) => bottom + y * cell;

  /// Grid cell under a point given in the board's coordinates, without any
  /// bounds check — [canPlace] is what decides whether it is usable.
  (int, int) cellAt(Offset position, Size size) => (
    ((position.dx - left) / cell).floor(),
    ((size.height - position.dy - bottom) / cell).floor(),
  );
}

/// The terrarium: glass, soil, the floor grid, the hut and the resident.
///
/// View mode and edit mode share it; the two builders are the difference.
class GardenBoard extends StatelessWidget {
  const GardenBoard({
    required this.placements,
    required this.stages,
    required this.hutStage,
    this.placementBuilder,
    this.cellOverlayBuilder,
    this.residentEnabled = true,
    this.residentInteractive = true,
    this.ojisanSpeech,
    super.key,
  });

  final List<GardenPlacement> placements;
  final Map<String, int> stages;
  final int hutStage;

  /// Wraps one placed item. Edit mode makes it draggable.
  final Widget Function(GardenPlacement placement, Widget tile)?
  placementBuilder;

  /// Drawn over every grid cell. Edit mode puts a drop target here.
  final Widget Function(int x, int y)? cellOverlayBuilder;

  final bool residentEnabled;

  /// False in edit mode: he keeps strolling, but he is not part of any hit
  /// test, so he can never swallow a drop or block a cell.
  final bool residentInteractive;

  final String? ojisanSpeech;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const wall = 12.0;
        // A band above the floor for the hut and the glass shoulder, sized in
        // cells so the jar never squashes the two together.
        const hutBandCells = 1.9;
        final size = constraints.biggest;

        final cell = math.min(
          (size.width - wall * 2) / gardenGridWidth,
          (size.height - wall * 2) / (gardenGridHeight + hutBandCells),
        );
        final gridWidth = cell * gardenGridWidth;
        final gridHeight = cell * gardenGridHeight;
        final geometry = GardenGeometry(
          cell: cell,
          left: wall + (size.width - wall * 2 - gridWidth) / 2,
          // Lifted off the floor of the jar so its rounded corners bite into
          // the soil rather than into the corner cells.
          bottom: wall + cell * 0.5,
        );

        final jar = CustomPaint(
          painter: TerrariumPainter(
            glass: scheme.primaryContainer,
            rim: scheme.outlineVariant,
            soil: Color.alphaBlend(
              scheme.tertiary.withValues(alpha: 0.35),
              const Color(0xFF6B4B2E),
            ),
            soilTop: size.height - geometry.bottom - gridHeight - cell * 0.35,
          ),
          child: Stack(
            children: [
              // Faint cell lines, so the floor reads as a grid to place on.
              Positioned(
                left: geometry.left,
                bottom: geometry.bottom,
                width: gridWidth,
                height: gridHeight,
                child: CustomPaint(
                  painter: _GridPainter(
                    cell: cell,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
              ),

              Positioned(
                left: geometry.left,
                bottom: geometry.bottom + gridHeight + 2,
                child: _Hut(stage: hutStage, size: cell * 1.5),
              ),

              if (cellOverlayBuilder != null)
                for (var x = 0; x < gardenGridWidth; x += 1)
                  for (var y = 0; y < gardenGridHeight; y += 1)
                    Positioned(
                      left: geometry.xOf(x),
                      bottom: geometry.yOf(y),
                      width: cell,
                      height: cell,
                      child: cellOverlayBuilder!(x, y),
                    ),

              for (final placement in placements)
                _positioned(context, placement, geometry),

              if (residentEnabled)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !residentInteractive,
                    child: _Resident(
                      geometry: geometry,
                      occupied: _occupiedCells(placements),
                      speech: ojisanSpeech,
                    ),
                  ),
                ),
            ],
          ),
        );

        // Clipped to the jar, or the floor grid runs out past its rounded
        // corners.
        return ClipRRect(
          borderRadius: BorderRadius.circular(size.width * jarCornerFactor),
          child: jar,
        );
      },
    );
  }

  Widget _positioned(
    BuildContext context,
    GardenPlacement placement,
    GardenGeometry geometry,
  ) {
    final def = GardenCatalog.byId(placement.itemId);
    if (def == null) return const SizedBox.shrink();
    final tile = GardenItemTile(
      def: def,
      growthStage: stages[placement.id] ?? 0,
    );
    return Positioned(
      key: ValueKey('placement-${placement.id}'),
      left: geometry.xOf(placement.x),
      bottom: geometry.yOf(placement.y),
      width: def.width * geometry.cell,
      height: def.height * geometry.cell,
      child: placementBuilder == null
          ? tile
          : placementBuilder!(placement, tile),
    );
  }
}

Set<(int, int)> _occupiedCells(List<GardenPlacement> placements) {
  final cells = <(int, int)>{};
  for (final placement in placements) {
    final def = GardenCatalog.byId(placement.itemId);
    if (def == null) continue;
    cells.addAll(cellsFor(def, placement.x, placement.y));
  }
  return cells;
}

Color gardenCategoryColor(ColorScheme scheme, GardenCategory category) =>
    switch (category) {
      GardenCategory.plant => const Color(0xFF7BB661),
      GardenCategory.furniture => const Color(0xFFC08A5A),
      GardenCategory.deco => const Color(0xFF8FA7BF),
    };

/// Placeholder art for one item: a coloured rounded rect, its emoji and its
/// name. Plants also show which of the four growth stages they are at.
class GardenItemTile extends StatelessWidget {
  const GardenItemTile({
    required this.def,
    this.growthStage = 0,
    this.compact = false,
    super.key,
  });

  final GardenItemDef def;
  final int growthStage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = gardenCategoryColor(scheme, def.category);
    // Plants get visibly bigger as they grow; everything else is fixed.
    final fill = def.growable ? 0.62 + 0.12 * growthStage : 0.9;
    final label = def.growable
        ? '${def.name}・${growthStageLabels[growthStage]}'
        : def.name;

    return Padding(
      padding: const EdgeInsets.all(1),
      child: FractionallySizedBox(
        widthFactor: compact ? 1 : fill.clamp(0.3, 1.0),
        heightFactor: compact ? 1 : fill.clamp(0.3, 1.0),
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  child: Text(def.emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              FittedBox(
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hut extends StatelessWidget {
  const _Hut({required this.stage, required this.size});

  final int stage;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: hutStageNames[stage],
    child: SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        child: Text(
          hutStageEmoji[stage],
          key: const ValueKey('hut'),
          style: const TextStyle(fontSize: 32),
        ),
      ),
    ),
  );
}

/// The ojisan. Strolls between free cells every few seconds and says his
/// current line when tapped. He is decoration: nothing collides with him.
class _Resident extends StatefulWidget {
  const _Resident({
    required this.geometry,
    required this.occupied,
    this.speech,
  });

  final GardenGeometry geometry;
  final Set<(int, int)> occupied;
  final String? speech;

  @override
  State<_Resident> createState() => _ResidentState();
}

class _ResidentState extends State<_Resident> {
  static const _step = Duration(seconds: 4);

  final _random = math.Random();
  Timer? _timer;
  Timer? _bubbleTimer;
  (int, int) _at = (0, 0);
  bool _talking = false;

  @override
  void initState() {
    super.initState();
    _at = _pick() ?? (0, 0);
    _timer = Timer.periodic(_step, (_) => _wander());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bubbleTimer?.cancel();
    super.dispose();
  }

  (int, int)? _pick() {
    final free = <(int, int)>[
      for (var x = 0; x < gardenGridWidth; x += 1)
        for (var y = 0; y < gardenGridHeight; y += 1)
          if (!widget.occupied.contains((x, y))) (x, y),
    ];
    if (free.isEmpty) return null;
    return free[_random.nextInt(free.length)];
  }

  void _wander() {
    final next = _pick();
    if (next == null || !mounted) return;
    setState(() => _at = next);
  }

  void _talk() {
    _bubbleTimer?.cancel();
    setState(() => _talking = true);
    _bubbleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _talking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cell = widget.geometry.cell;
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOut,
          left: widget.geometry.xOf(_at.$1),
          bottom: widget.geometry.yOf(_at.$2),
          width: cell,
          height: cell,
          child: GestureDetector(
            onTap: _talk,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                FittedBox(
                  child: Text(
                    '👨',
                    key: const ValueKey('ojisan'),
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                if (_talking && widget.speech != null)
                  Positioned(
                    bottom: cell,
                    child: _SpeechBubble(
                      text: widget.speech!,
                      theme: theme,
                      maxWidth: cell * 5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.text,
    required this.theme,
    required this.maxWidth,
  });

  final String text;
  final ThemeData theme;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      constraints: BoxConstraints(maxWidth: math.max(maxWidth, 120)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        key: const ValueKey('ojisanSpeech'),
        style: theme.textTheme.bodySmall,
      ),
    ),
  );
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.cell, required this.color});

  final double cell;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0; x <= gardenGridWidth; x += 1) {
      canvas.drawLine(
        Offset(x * cell, 0),
        Offset(x * cell, size.height),
        paint,
      );
    }
    for (var y = 0; y <= gardenGridHeight; y += 1) {
      canvas.drawLine(Offset(0, y * cell), Offset(size.width, y * cell), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.cell != cell || old.color != color;
}
