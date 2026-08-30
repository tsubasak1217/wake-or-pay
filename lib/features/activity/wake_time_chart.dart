import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/activity_stats.dart';
import '../../domain/format.dart';

/// 起床時間の遷移 — one dot per morning, joined into a line, with the average
/// drawn across it.
///
/// Drawn by `fl_chart` rather than by hand: the axes, the touch tooltip and the
/// pan/pinch of the whole-history screen are all things a chart package already
/// does correctly, and the hand-painted version had none of them.
///
/// **Gaps are joined, not broken.** A day with no wake-up gets no spot, and the
/// line runs straight from the morning before it to the morning after. A break
/// would read as 「起きなかった」 when what actually happened is 「記録がない」.
class WakeTimeChart extends StatelessWidget {
  const WakeTimeChart({
    super.key,
    required this.points,
    required this.firstDay,
    required this.lastDay,
    this.height = 160,
    this.interactive = false,
  });

  /// Oldest first.
  final List<WakePoint> points;

  /// The window the x axis spans, inclusive. Both are local midnights.
  final DateTime firstDay;
  final DateTime lastDay;

  final double height;

  /// Horizontal pan and pinch-zoom, for the whole-history screen. The 30-day
  /// card leaves it off: a month already fits.
  final bool interactive;

  /// The half-hour of headroom kept above and below the extremes, so the
  /// earliest morning is a point on a line rather than a dot welded to the
  /// frame.
  static const _padMinutes = 30.0;

  /// The narrowest the y axis is ever squeezed to. Without it, thirty mornings
  /// within a minute of each other would be drawn as a mountain range.
  static const _minSpanMinutes = 120.0;

  /// The visible band of the clock, in minutes from midnight. Pure.
  static ({double lo, double hi}) minuteRange(
    List<WakePoint> points,
    Duration? average,
  ) {
    final minutes = <double>[
      for (final p in points) p.at.inMinutes.toDouble(),
      if (average != null) average.inMinutes.toDouble(),
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

  /// A clock-shaped step: never 37 minutes, always something a reader can add
  /// up in their head.
  static double _clockInterval(double span) {
    for (final step in const [15.0, 30.0, 60.0, 120.0, 180.0, 360.0]) {
      if (span / step <= 4) return step;
    }
    return 720;
  }

  static String _hhmm(double minutes) {
    final m = minutes.round().clamp(0, 24 * 60 - 1);
    return hhmm(m ~/ 60, m % 60);
  }

  int get _dayCount => lastDay.difference(firstDay).inDays;

  DateTime _dayAt(double index) => DateTime(
    firstDay.year,
    firstDay.month,
    firstDay.day + index.round(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = averageTimeOfDay(points);
    final range = minuteRange(points, average);
    final labelStyle =
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        const TextStyle(fontSize: 11);

    // A single morning has no span to be, so it is given half a day on each
    // side rather than a zero-wide axis to sit in the middle of.
    final singleDay = _dayCount <= 0;
    final minX = singleDay ? -0.5 : 0.0;
    final maxX = singleDay ? 0.5 : _dayCount.toDouble();

    final dayStep = math.max(1, (_dayCount / 5).ceil()).toDouble();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: range.lo,
          maxY: range.hi,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: _clockInterval(range.hi - range.lo),
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outlineVariant,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: _clockInterval(range.hi - range.lo),
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(_hhmm(value), style: labelStyle),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: dayStep,
                getTitlesWidget: (value, meta) {
                  final day = _dayAt(value);
                  return SideTitleWidget(
                    meta: meta,
                    child: Text('${day.month}/${day.day}', style: labelStyle),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (average != null)
                HorizontalLine(
                  y: average.inMinutes.toDouble(),
                  color: theme.colorScheme.outline,
                  strokeWidth: 1.5,
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topLeft,
                    style: labelStyle,
                    labelResolver: (_) => '平均 ${timeOfDayLabel(average)}',
                  ),
                ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final p in points)
                  FlSpot(
                    p.day.difference(firstDay).inDays.toDouble(),
                    p.at.inMinutes.toDouble(),
                  ),
              ],
              color: theme.colorScheme.primary,
              barWidth: 2,
              isStrokeCapRound: true,
              isStrokeJoinRound: true,
              dotData: FlDotData(
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 2.5,
                  color: theme.colorScheme.primary,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${_dayAt(spot.x).month}/${_dayAt(spot.x).day} '
                    '${_hhmm(spot.y)}',
                    TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
        transformationConfig: interactive
            ? const FlTransformationConfig(
                scaleAxis: FlScaleAxis.horizontal,
                minScale: 1,
                maxScale: 6,
              )
            : const FlTransformationConfig(),
      ),
    );
  }
}
