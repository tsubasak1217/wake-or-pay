import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/format.dart';

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

  @override
  String toString() => 'PenaltyBar($day, $coins コイン, $yen 円)';
}

/// The whole-history penalty chart: one stacked column per day, coins under
/// card, oldest on the left, panned and pinched rather than squeezed.
///
/// Stacked rather than side by side because the number the user is looking for
/// is 「その日いくら持っていかれたか」 — the split is the second question, and the
/// legend answers it.
///
/// Tapping a column reports its day through [onDaySelected]; the screen above
/// decides what to do with it, which is also what makes the selection testable
/// without going through a hit test.
class PenaltyBarChart extends StatelessWidget {
  const PenaltyBarChart({
    super.key,
    required this.bars,
    required this.onDaySelected,
    this.selected,
    this.height = 180,
  });

  final List<PenaltyBar> bars;

  /// The day whose log is showing, drawn with a highlight behind its column.
  final DateTime? selected;

  final ValueChanged<DateTime> onDaySelected;

  final double height;

  /// The shortest a column is ever drawn. A day that cost nothing is still a
  /// day, and a zero-height column would read as a missing one.
  static const _floorFraction = 0.015;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coinColor = theme.colorScheme.primary;
    final cardColor = theme.colorScheme.error;
    final labelStyle =
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        const TextStyle(fontSize: 11);

    final worst = bars.fold(0, (max, b) => b.total > max ? b.total : max);
    final maxY = worst == 0 ? 1.0 : worst * 1.12;
    final floor = maxY * _floorFraction;
    final dayStep = math.max(1, (bars.length / 5).ceil());

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // `spaceAround` puts column i's centre at exactly (i + ½)·width/n,
          // which is the pitch the hand-painted strip used — so the columns
          // land where the eye expects them however many days there are.
          final pitch = constraints.maxWidth / math.max(bars.length, 1);
          final rodWidth = math.max(pitch * 0.7, 2.0);

          return BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= bars.length) {
                        return const SizedBox.shrink();
                      }
                      if (index % dayStep != 0) return const SizedBox.shrink();
                      final day = bars[index].day;
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '${day.month}/${day.day}',
                          style: labelStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < bars.length; i++)
                  _group(
                    i,
                    bars[i],
                    maxY: maxY,
                    floor: floor,
                    width: rodWidth,
                    coinColor: coinColor,
                    cardColor: cardColor,
                    emptyColor: theme.colorScheme.outlineVariant,
                    selectedColor: coinColor.withValues(alpha: 0.12),
                  ),
              ],
              barTouchData: BarTouchData(
                // The whole column answers a tap, not just the ink of the rod:
                // a day that cost ¥50 is a two-pixel stub, and asking the user
                // to hit it would make the selection a game of darts. The gap
                // either side comes from the threshold, the empty height above
                // from the (transparent) back-draw rod.
                allowTouchBarBackDraw: true,
                touchExtraThreshold: EdgeInsets.symmetric(
                  horizontal: pitch * 0.15,
                ),
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex < 0 || groupIndex >= bars.length) return null;
                    final bar = bars[groupIndex];
                    return BarTooltipItem(
                      '${bar.day.month}/${bar.day.day}\n'
                      '${thousands(bar.coins)} コイン ・ '
                      '${thousands(bar.yen)} 円',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  // Only a finished tap moves the selection. A pan is the user
                  // scrolling the chart, and a hover is not a decision.
                  if (event is! FlTapUpEvent) return;
                  final index = response?.spot?.touchedBarGroupIndex;
                  if (index == null || index < 0 || index >= bars.length) return;
                  onDaySelected(bars[index].day);
                },
              ),
            ),
            transformationConfig: const FlTransformationConfig(
              scaleAxis: FlScaleAxis.horizontal,
              minScale: 1,
              maxScale: 6,
            ),
          );
        },
      ),
    );
  }

  BarChartGroupData _group(
    int index,
    PenaltyBar bar, {
    required double maxY,
    required double floor,
    required double width,
    required Color coinColor,
    required Color cardColor,
    required Color emptyColor,
    required Color selectedColor,
  }) {
    final highlighted = selected != null && bar.day == selected;
    // Always drawn, so the whole column is hit-testable; only the selected one
    // is drawn in a colour anybody can see.
    final background = BackgroundBarChartRodData(
      show: true,
      toY: maxY,
      color: highlighted ? selectedColor : const Color(0x00000000),
    );

    if (bar.total == 0) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: floor,
            width: width,
            color: emptyColor,
            backDrawRodData: background,
          ),
        ],
      );
    }

    // The card half sits on top of the coin half, so the coin block always
    // starts from the floor and the column reads bottom-up.
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: bar.total.toDouble(),
          width: width,
          color: cardColor,
          backDrawRodData: background,
          rodStackItems: [
            if (bar.coins > 0)
              BarChartRodStackItem(0, bar.coins.toDouble(), coinColor),
            if (bar.yen > 0)
              BarChartRodStackItem(
                bar.coins.toDouble(),
                bar.total.toDouble(),
                cardColor,
              ),
          ],
        ),
      ],
    );
  }
}
