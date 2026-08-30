import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/activity_stats.dart';
import '../../domain/models.dart';
import 'wake_time_chart.dart';

/// 起床時間の遷移, over everything on record.
///
/// The same chart the tab draws, over a wider window and with `fl_chart`'s own
/// pan and pinch turned on: a year of mornings does not fit on a phone, so it
/// is scrolled and zoomed instead of squeezed.
class WakeTimeHistoryScreen extends ConsumerWidget {
  const WakeTimeHistoryScreen({super.key});

  static const _chartHeight = 240.0;

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
                    child: WakeTimeChart(
                      key: const ValueKey('wakeHistoryChart'),
                      points: points,
                      firstDay: points.first.day,
                      lastDay: points.last.day,
                      height: _chartHeight,
                      interactive: true,
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
