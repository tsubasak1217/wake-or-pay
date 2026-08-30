import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/activity_stats.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import 'penalty_bar_chart.dart';

/// ペナルティ履歴 — every day the mornings ever cost anything, and the log of
/// the one the user is pointing at.
///
/// The chart is the whole history rather than a window: the point of coming in
/// here from the 今月 card is to see further back than the card does.
class PenaltyHistoryScreen extends ConsumerStatefulWidget {
  const PenaltyHistoryScreen({super.key});

  @override
  ConsumerState<PenaltyHistoryScreen> createState() =>
      _PenaltyHistoryScreenState();
}

Future<void> pushPenaltyHistoryScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const PenaltyHistoryScreen()),
    );

class _PenaltyHistoryScreenState extends ConsumerState<PenaltyHistoryScreen> {
  /// The day whose log is showing. Null means 「the latest day that cost
  /// something」, resolved every build so it follows a new penalty in rather
  /// than pinning itself to whatever was latest when the screen opened.
  DateTime? _selected;

  static const _chartHeight = 180.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions =
        ref.watch(allSessionsProvider).valueOrNull ?? const <AlarmSession>[];
    final charges =
        ref.watch(pendingChargesProvider).valueOrNull ?? const <PendingCharge>[];

    final byDay = penaltyByDay(sessions, charges);
    final bars = _bars(byDay);
    final selected = _selected ?? (bars.isEmpty ? null : _latestCosting(bars));

    return Scaffold(
      appBar: AppBar(title: const Text('ペナルティ履歴')),
      body: bars.isEmpty
          ? const Center(
              key: ValueKey('penaltyHistoryEmpty'),
              child: Text('まだペナルティはありません'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _Legend(),
                const SizedBox(height: 8),
                PenaltyBarChart(
                  key: const ValueKey('penaltyHistoryChart'),
                  bars: bars,
                  selected: selected,
                  height: _chartHeight,
                  onDaySelected: (day) => setState(() => _selected = day),
                ),
                const SizedBox(height: 16),
                if (selected != null) ...[
                  Text(
                    '${selected.year}/${selected.month}/${selected.day} の記録',
                    key: const ValueKey('penaltyDayHeading'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  ..._dayRows(context, sessions, charges, selected),
                ],
              ],
            ),
    );
  }

  /// Every day from the first penalty to the last, so a quiet fortnight is a
  /// flat stretch of the chart rather than two columns side by side.
  List<PenaltyBar> _bars(Map<DateTime, DayPenalty> byDay) {
    if (byDay.isEmpty) return const [];
    final days = byDay.keys.toList()..sort();
    final first = days.first;
    final count = days.last.difference(first).inDays + 1;
    return [
      for (var i = 0; i < count; i++)
        () {
          // Built off a local midnight rather than by adding Durations, so a
          // DST change cannot slide a column off its own date.
          final day = DateTime(first.year, first.month, first.day + i);
          final cost = byDay[day] ?? (coins: 0, yen: 0);
          return PenaltyBar(day: day, coins: cost.coins, yen: cost.yen);
        }(),
    ];
  }

  DateTime? _latestCosting(List<PenaltyBar> bars) =>
      bars.lastWhere((b) => b.total > 0, orElse: () => bars.last).day;

  List<Widget> _dayRows(
    BuildContext context,
    List<AlarmSession> sessions,
    List<PendingCharge> charges,
    DateTime day,
  ) {
    final theme = Theme.of(context);
    final rows = sessionsOn(sessions, day);
    if (rows.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('この日の記録はありません'),
        ),
      ];
    }
    return [
      for (final session in rows)
        ListTile(
          key: ValueKey('penaltyDayRow-${session.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(hhmm(session.firedAt.hour, session.firedAt.minute)),
          subtitle: Text(
            [
              session.status == SessionStatus.failed ? '寝坊' : '成功',
              'スヌーズ ${session.snoozes.length}回',
            ].join(' ・ '),
          ),
          trailing: Text(
            session.loss <= 0
                ? '—'
                : wasBilledToCard(session, charges)
                ? '${thousands(session.loss)} 円をカードに請求予定'
                : '${session.loss} コイン',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: session.loss <= 0
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
        ),
    ];
  }
}

/// Which colour is which unit. Without it the stack is two anonymous blocks.
class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final entry in [
          ('コイン', theme.colorScheme.primary),
          ('カード', theme.colorScheme.error),
        ]) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: entry.$2,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(entry.$1, style: theme.textTheme.bodySmall),
          const SizedBox(width: 16),
        ],
      ],
    );
  }
}
