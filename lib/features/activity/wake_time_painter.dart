import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/activity_stats.dart';

/// 起床時間の遷移 — one dot per morning, joined into a line, with the average
/// drawn across it.
///
/// Hand-painted for the same reason the day strip is: this is a polyline and a
/// rule, and a chart package would be several hundred kilobytes of axes,
/// legends and tooltips this never shows.
///
/// **Gaps are joined, not broken.** A day with no wake-up gets no dot, and the
/// line runs straight from the morning before it to the morning after. A break
/// would read as 「起きなかった」 when what actually happened is 「記録がない」.
class WakeTimePainter extends CustomPainter {
  const WakeTimePainter({
    required this.points,
    required this.firstDay,
    required this.lastDay,
    required this.average,
    required this.lineColor,
    required this.averageColor,
    required this.axisColor,
    required this.labelColor,
    this.labelSize = 11,
  });

  /// Oldest first. Empty draws the axis and nothing else.
  final List<WakePoint> points;

  /// The window the x axis spans, inclusive. Both are local midnights.
  final DateTime firstDay;
  final DateTime lastDay;

  /// The rule across the chart. Null draws no rule and no label.
  final Duration? average;

  final Color lineColor;
  final Color averageColor;
  final Color axisColor;
  final Color labelColor;
  final double labelSize;

  static const _padTop = 14.0;
  static const _padBottom = 12.0;

  /// The half-hour of headroom kept above and below the extremes, so the
  /// earliest morning is a point on a line rather than a dot welded to the
  /// frame.
  static const _padMinutes = 30;

  /// The narrowest the y axis is ever squeezed to. Without it, thirty mornings
  /// within a minute of each other would be drawn as a mountain range.
  static const _minSpanMinutes = 120;

  int get _dayCount => lastDay.difference(firstDay).inDays;

  /// The visible band of the clock, in minutes from midnight.
  ({double lo, double hi}) _range() {
    final minutes = <double>[
      for (final p in points) p.at.inMinutes.toDouble(),
      if (average != null) average!.inMinutes.toDouble(),
    ];
    if (minutes.isEmpty) return (lo: 4 * 60, hi: 12 * 60);

    var lo = minutes.reduce(math.min) - _padMinutes;
    var hi = minutes.reduce(math.max) + _padMinutes;
    if (hi - lo < _minSpanMinutes) {
      final centre = (lo + hi) / 2;
      lo = centre - _minSpanMinutes / 2;
      hi = centre + _minSpanMinutes / 2;
    }
    return (lo: lo.clamp(0, 24 * 60), hi: hi.clamp(0, 24 * 60));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final range = _range();
    final span = math.max(range.hi - range.lo, 1);
    final top = _padTop;
    final bottom = math.max(size.height - _padBottom, top + 1);

    double y(double minutes) =>
        bottom - (minutes - range.lo) / span * (bottom - top);
    double x(DateTime day) => _dayCount <= 0
        ? size.width / 2
        : day.difference(firstDay).inDays / _dayCount * size.width;

    // The floor the sketch draws under the line.
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );

    final mean = average;
    if (mean != null) {
      final at = y(mean.inMinutes.toDouble());
      canvas.drawLine(
        Offset(0, at),
        Offset(size.width, at),
        Paint()
          ..color = averageColor
          ..strokeWidth = 1.5,
      );
      _label('平均 ${timeOfDayLabel(mean)}', canvas, Offset(2, at - labelSize - 4));
    }

    if (points.isEmpty) return;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final at = Offset(x(points[i].day), y(points[i].at.inMinutes.toDouble()));
      if (i == 0) {
        path.moveTo(at.dx, at.dy);
      } else {
        path.lineTo(at.dx, at.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // A single morning has no line to be, so it is drawn as the dot it is.
    if (points.length == 1) {
      canvas.drawCircle(
        Offset(x(points.first.day), y(points.first.at.inMinutes.toDouble())),
        3,
        Paint()..color = lineColor,
      );
    }
  }

  void _label(String text, Canvas canvas, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: labelSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(at.dx, math.max(at.dy, 0)));
  }

  @override
  bool shouldRepaint(WakeTimePainter oldDelegate) =>
      !listEquals(oldDelegate.points, points) ||
      oldDelegate.firstDay != firstDay ||
      oldDelegate.lastDay != lastDay ||
      oldDelegate.average != average ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.averageColor != averageColor ||
      oldDelegate.axisColor != axisColor ||
      oldDelegate.labelColor != labelColor;
}

/// The chart itself, themed. Shared by the tab's 30-day card and the whole
/// history behind 「もっと見る」, so the two can never drift apart.
class WakeTimeChart extends StatelessWidget {
  const WakeTimeChart({
    super.key,
    required this.points,
    required this.firstDay,
    required this.lastDay,
    this.height = 160,
  });

  final List<WakePoint> points;
  final DateTime firstDay;
  final DateTime lastDay;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: WakeTimePainter(
          points: points,
          firstDay: firstDay,
          lastDay: lastDay,
          average: averageTimeOfDay(points),
          lineColor: theme.colorScheme.primary,
          averageColor: theme.colorScheme.outline,
          axisColor: theme.colorScheme.outlineVariant,
          labelColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
