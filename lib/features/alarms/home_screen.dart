import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/oversleep_contact_rules.dart';
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
                // A hairline between two calm rows, and air around a 覚悟 one:
                // that row is a card with a glow, and a divider drawn against
                // it reads as a mistake.
                separatorBuilder: (context, index) =>
                    list[index].isKakugo || list[index + 1].isKakugo
                    ? const SizedBox(height: 4)
                    : const Divider(height: 1),
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
    for (final session
        in ref.watch(ringingSessionsProvider).valueOrNull ??
            const <AlarmSession>[]) {
      if (session.alarmId == alarm.id && isSnoozePending(session, now)) {
        return session.currentRingAt;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snoozedUntil = _snoozedUntil(ref);
    return SwipeToDelete(
      // Goes through the controller, so the platform alarm is cancelled before
      // the row disappears — a deleted alarm that still rings is the one bug
      // this screen must never have.
      onDelete: () => ref.read(alarmControllerProvider).delete(alarm),
      child: alarm.isKakugo
          ? _KakugoRow(alarm: alarm, snoozedUntil: snoozedUntil)
          : _PlainRow(alarm: alarm, snoozedUntil: snoozedUntil),
    );
  }
}

/// A row with nothing at stake. Unchanged, and deliberately so: the calm ones
/// have to stay calm for the loud one to mean anything.
class _PlainRow extends ConsumerWidget {
  const _PlainRow({required this.alarm, required this.snoozedUntil});

  final Alarm alarm;
  final DateTime? snoozedUntil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
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
          const Text('覚悟なし'),
          if (snoozedUntil != null) _SnoozingLabel(until: snoozedUntil!),
        ],
      ),
      trailing: Switch(
        value: alarm.enabled,
        onChanged: (v) =>
            ref.read(alarmControllerProvider).setEnabled(alarm, v),
      ),
    );
  }
}

/// A row with money on it.
///
/// Red on near-black, bordered and lit, with the badge from the 覚悟 gauge at
/// the front and the worst case spelled out in the same words the editor used.
/// The point of the app is that this alarm does not look like the others, and
/// a list where every row looks the same is a list that hides the stake.
class _KakugoRow extends ConsumerWidget {
  const _KakugoRow({required this.alarm, required this.snoozedUntil});

  final Alarm alarm;
  final DateTime? snoozedUntil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kakugo = alarm.kakugo!;
    // Off means the pledge is not armed tonight; the row still says what it
    // would cost, but it stops shouting about it.
    final on = alarm.enabled;

    // The person this alarm would call, as the 連絡帳 has them now.
    final contact = alarm.willContact
        ? resolveOversleepContact(
            alarm.contact!,
            ref.watch(contactBookListProvider),
          )
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kakugoDanger.withValues(alpha: on ? 0.32 : 0.10),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      // The colour and the border go on a Material rather than on the box
      // above: ListTile paints its background and its ink on the nearest
      // Material ancestor, and a coloured box in between would hide both.
      child: Material(
        color: kakugoBackground,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: kakugoDanger.withValues(alpha: on ? 0.95 : 0.45),
            width: 1.5,
          ),
        ),
        // ListTile paints from the ambient colour scheme, so the row gets a
        // dark scheme of its own — otherwise the light themes would draw black
        // text on this black card. The editor's 覚悟 island does the same.
        child: Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              brightness: Brightness.dark,
              surface: kakugoBackground,
              onSurface: kakugoOnDanger,
              onSurfaceVariant: kakugoDanger,
              error: kakugoDanger,
            ),
          ),
          child: ListTile(
            onTap: () => context.push(AppRoute.alarmEdit(alarm.id)),
            leading: Text(
              kakugoBadge(kakugo.ratePerMinute, kakugo.cap),
              key: const ValueKey('kakugoBadge'),
              style: const TextStyle(fontSize: 30),
            ),
            title: Text(
              hhmm(alarm.hour, alarm.minute),
              style: theme.textTheme.displaySmall?.copyWith(
                color: on
                    ? kakugoOnDanger
                    : kakugoOnDanger.withValues(alpha: 0.4),
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${repeatDaysLabel(alarm.repeatDays)} ・ ${alarm.wakeCheck.label}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kakugoOnDanger.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kakugoRateLabel(kakugo.ratePerMinute),
                  key: const ValueKey('kakugoRate'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kakugoDanger,
                  ),
                ),
                Text(
                  maxLossLabel(kakugo.cap),
                  key: const ValueKey('kakugoMaxLoss'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: kakugoDanger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (contact != null) _ContactLine(contact: contact),
                if (snoozedUntil != null) _SnoozingLabel(until: snoozedUntil!),
              ],
            ),
            trailing: Switch(
              value: alarm.enabled,
              onChanged: (v) =>
                  ref.read(alarmControllerProvider).setEnabled(alarm, v),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「📞 ✉ 田中太郎」 — who hears about it, and how.
class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.contact});

  final OversleepContact contact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      [
        if (contact.willPhone) '📞',
        if (contact.willEmail) '✉',
        contact.name,
      ].join(' '),
      key: const ValueKey('kakugoContact'),
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: kakugoOnDanger),
    ),
  );
}

/// 「スヌーズ中 7:05」. The same on both kinds of row: a pending re-ring is a
/// fact about the alarm, not about the pledge.
class _SnoozingLabel extends StatelessWidget {
  const _SnoozingLabel({required this.until});

  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      snoozeUntilLabel(until),
      key: const ValueKey('snoozedUntil'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
