import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../data/providers.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/snooze_rules.dart';
import 'alarm_controller.dart';
import 'widgets/swipe_to_delete.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarms = ref.watch(alarmsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('覚悟の目覚まし'),
        actions: [
          IconButton(
            tooltip: '設定',
            onPressed: () => context.push(AppRoute.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(44),
          child: _BalanceBar(),
        ),
      ),
      body: alarms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('アラームはまだありません'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) => _AlarmTile(alarm: list[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoute.alarmNew),
        tooltip: 'アラームを追加',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BalanceBar extends ConsumerWidget {
  const _BalanceBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).valueOrNull ?? const Wallet();
    // The wallet is a tab now, so this bar only shows the balance and hands
    // over to that tab rather than pushing a second copy of the screen.
    return InkWell(
      onTap: () => context.go(AppRoute.wallet),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(
          children: [
            Text('🪙 ${wallet.coins}'),
            const SizedBox(width: 24),
            Text('🎁 ${wallet.tokens}'),
            const Spacer(),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _AlarmTile extends ConsumerWidget {
  const _AlarmTile({required this.alarm});

  final Alarm alarm;

  /// The re-ring time of this alarm's snoozed session, if it has one waiting.
  DateTime? _snoozedUntil(WidgetRef ref) {
    final now = DateTime.now();
    for (final session in ref.watch(ringingSessionsProvider).valueOrNull ??
        const <AlarmSession>[]) {
      if (session.alarmId == alarm.id && isSnoozePending(session, now)) {
        return session.currentRingAt;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snoozedUntil = _snoozedUntil(ref);
    return SwipeToDelete(
      // Goes through the controller, so the platform alarm is cancelled before
      // the row disappears — a deleted alarm that still rings is the one bug
      // this screen must never have.
      onDelete: () => ref.read(alarmControllerProvider).delete(alarm),
      child: ListTile(
        onTap: () => context.push(AppRoute.alarmEdit(alarm.id)),
        title: Text(
          hhmm(alarm.hour, alarm.minute),
          style: theme.textTheme.displaySmall?.copyWith(
            color: alarm.enabled ? null : theme.disabledColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${repeatDaysLabel(alarm.repeatDays)} ・ ${alarm.wakeCheck.label}',
            ),
            Text(
              kakugoLabel(alarm.kakugo),
              style: alarm.isKakugo
                  ? theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    )
                  : null,
            ),
            if (snoozedUntil != null)
              Text(
                snoozeUntilLabel(snoozedUntil),
                key: const ValueKey('snoozedUntil'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Switch(
          value: alarm.enabled,
          onChanged: (v) =>
              ref.read(alarmControllerProvider).setEnabled(alarm, v),
        ),
      ),
    );
  }
}
