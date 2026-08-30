import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/activity_stats.dart';
import '../../domain/models.dart';
import 'wake_time_painter.dart';

/// 起床時間の遷移, over everything on record.
///
/// The same chart the tab draws, over a wider window and inside an
/// [InteractiveViewer]: a year of mornings does not fit on a phone, so it is
/// panned and pinched instead of squeezed.
class WakeTimeHistoryScreen extends ConsumerWidget {
  const WakeTimeHistoryScreen({super.key});

  static const _chartHeight = 240.0;

  /// Enough room per morning that a hundred of them are still separate marks.
  static const _minPitch = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions =
        ref.watch(allSessionsProvider).valueOrNull ?? const <AlarmSession>[];
    final points = allWakeTimes(sessions);
    final average = averageTimeOfDay(points);

    return Scaffold(
      appBar: AppBar(title: const Text('起床時間の遷移')),
      body: points.isEmpty
          ? const Center(
              key: ValueKey('wakeHistoryEmpty'),
              child: Text('まだ記録はありません'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    average == null
                        ? '記録 ${points.length}日'
                        : '記録 ${points.length}日 ・ 平均 ${timeOfDayLabel(average)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final span =
                            points.last.day.difference(points.first.day).inDays +
                            1;
                        final width = math.max(
                          constraints.maxWidth,
                          span * _minPitch,
                        );
                        return InteractiveViewer(
                          key: const ValueKey('wakeHistoryChart'),
                          constrained: false,
                          minScale: 1,
                          maxScale: 6,
                          child: SizedBox(
                            width: width,
                            height: _chartHeight,
                            child: WakeTimeChart(
                              points: points,
                              firstDay: points.first.day,
                              lastDay: points.last.day,
                              height: _chartHeight,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

Future<void> pushWakeTimeHistoryScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const WakeTimeHistoryScreen()),
    );
