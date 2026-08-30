import 'dart:math' as math;

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

/// One day of ペナルティ履歴: what it cost, in both units.
@immutable
class PenaltyBar {
  const PenaltyBar({required this.day, this.coins = 0, this.yen = 0});

  final DateTime day;
  final int coins;
  final int yen;

  int get total => coins + yen;

  @override
  bool operator ==(Object other) =>
      other is PenaltyBar &&
      other.day == day &&
      other.coins == coins &&
      other.yen == yen;

  @override
  int get hashCode => Object.hash(day, coins, yen);
}

/// The whole-history penalty chart: one stacked column per day, coins under
/// card, oldest on the left.
///
/// Stacked rather than side by side because the number the user is looking for
/// is 「その日いくら持っていかれたか」 — the split is the second question, and the
/// legend answers it.
class PenaltyBarsPainter extends CustomPainter {
  const PenaltyBarsPainter({
    required this.bars,
    required this.coinColor,
    required this.cardColor,
    required this.emptyColor,
    required this.selectedColor,
    this.selected,
  });

  final List<PenaltyBar> bars;

  final Color coinColor;
  final Color cardColor;

  /// A day that cost nothing: still a day, drawn as a floor tick.
  final Color emptyColor;

  /// The highlight behind the day whose log is showing below the chart.
  final Color selectedColor;
  final int? selected;

  static const _minHeight = 3.0;

  /// Which column [dx] falls in, or null when it falls outside. Pure — the
  /// gesture handler and the paint agree because they run the same arithmetic.
  static int? indexAt(double dx, double width, int count) {
    if (count <= 0 || width <= 0) return null;
    final index = (dx / (width / count)).floor();
    return index < 0 || index >= count ? null : index;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return;

    final pitch = size.width / bars.length;
    final width = math.max(pitch * 0.7, 1.0);
    final worst = bars.fold(0, (max, b) => b.total > max ? b.total : max);
    final radius = Radius.circular(width < 4 ? width / 2 : 2);

    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final left = i * pitch + (pitch - width) / 2;

      if (i == selected) {
        canvas.drawRect(
          Rect.fromLTWH(i * pitch, 0, pitch, size.height),
          Paint()..color = selectedColor,
        );
      }

      if (worst == 0 || bar.total == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, size.height - _minHeight, width, _minHeight),
            radius,
          ),
          Paint()..color = emptyColor,
        );
        continue;
      }

      final total = size.height * bar.total / worst;
      // The card half sits on top of the coin half, so the coin block always
      // starts from the floor and the column reads bottom-up.
      final coinHeight = total * bar.coins / bar.total;
      var y = size.height;
      for (final part in [(coinHeight, coinColor), (total - coinHeight, cardColor)]) {
        if (part.$1 <= 0) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, y - part.$1, width, part.$1),
            radius,
          ),
          Paint()..color = part.$2,
        );
        y -= part.$1;
      }
    }
  }

  @override
  bool shouldRepaint(PenaltyBarsPainter oldDelegate) =>
      !listEquals(oldDelegate.bars, bars) ||
      oldDelegate.selected != selected ||
      oldDelegate.coinColor != coinColor ||
      oldDelegate.cardColor != cardColor ||
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.selectedColor != selectedColor;
}
