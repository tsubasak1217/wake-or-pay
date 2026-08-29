import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One column of a day strip: how tall it is drawn, and in what colour.
@immutable
class DayBar {
  const DayBar({required this.color, this.fill = 1});

  final Color color;

  /// 0..1 of the available height. Values outside that are clamped rather than
  /// allowed to paint outside the box.
  final double fill;

  @override
  bool operator ==(Object other) =>
      other is DayBar && other.color == color && other.fill == fill;

  @override
  int get hashCode => Object.hash(color, fill);
}

/// A bare day strip: one column per day, left (oldest) to right (today).
///
/// Hand-painted rather than pulled from a chart package — this is a row of
/// rectangles, and a dependency that draws axes, legends and tooltips would be
/// several hundred kilobytes of things this never shows.
class DayBarsPainter extends CustomPainter {
  const DayBarsPainter({required this.bars, this.gap = 2, this.minHeight = 3});

  final List<DayBar> bars;

  /// Space between two columns, in logical pixels. Swallowed when the strip is
  /// too narrow to afford it, so a 30-day strip on a small phone still draws 30
  /// columns rather than 30 slivers of nothing.
  final double gap;

  /// The shortest a column is ever drawn. A day with no penalty is still a day,
  /// and a zero-height column would read as a missing one.
  final double minHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return;

    final spacing = size.width / bars.length > gap * 2 ? gap : 0.0;
    final width = (size.width - spacing * (bars.length - 1)) / bars.length;
    if (width <= 0) return;
    final radius = Radius.circular(width < 4 ? width / 2 : 2);

    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final height = (size.height * bar.fill.clamp(0.0, 1.0)).clamp(
        minHeight.clamp(0.0, size.height),
        size.height,
      );
      final left = i * (width + spacing);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, width, height),
          radius,
        ),
        Paint()..color = bar.color,
      );
    }
  }

  @override
  bool shouldRepaint(DayBarsPainter oldDelegate) =>
      !listEquals(oldDelegate.bars, bars) ||
      oldDelegate.gap != gap ||
      oldDelegate.minHeight != minHeight;
}
