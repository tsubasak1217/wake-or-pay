import 'dart:async';

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
import '../profile/app_header.dart';
import 'alarm_controller.dart';
import 'widgets/swipe_to_delete.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarms = ref.watch(alarmsProvider);

    return Scaffold(
      // The shared header replaces both the title bar and the old balance bar:
      // the balance is in it, and 設定 keeps its row on the wallet tab.
      appBar: const AppHeaderBar(),
      body: alarms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => _AlarmList(initial: list),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoute.alarmNew),
        tooltip: 'アラームを追加',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// The list body, mirroring [alarmsProvider] into a local list so a deletion
/// can be *animated* away instead of vanishing between two frames.
///
/// [AnimatedList] cannot be driven straight off a provider: it needs to be told
/// about a removal while the removed row still has something to draw. So the
/// state holds its own copy of the alarms and diffs each emission by id —
/// removals first (so the indices it hands `removeItem` are still valid), then
/// insertions, then in-place content changes.
class _AlarmList extends ConsumerStatefulWidget {
  const _AlarmList({required this.initial});

  /// The alarms as of the frame this widget was created on. Read once, in
  /// `initState`; every later emission arrives through the listener.
  final List<Alarm> initial;

  @override
  ConsumerState<_AlarmList> createState() => _AlarmListState();
}

class _AlarmListState extends ConsumerState<_AlarmList> {
  static const _removeDuration = Duration(milliseconds: 250);

  final _listKey = GlobalKey<AnimatedListState>();
  late final List<Alarm> _items = [...widget.initial];

  /// Rows that are gone from [_items] but still collapsing on screen. The empty
  /// state must wait for them: swapping 「アラームはまだありません」 in the moment the
  /// last alarm is deleted would tear the animation out of the tree.
  final _collapsing = <Timer>{};

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<List<Alarm>>>(alarmsProvider, (_, next) {
      final list = next.valueOrNull;
      if (list != null) _sync(list);
    });
  }

  @override
  void dispose() {
    for (final timer in _collapsing) {
      timer.cancel();
    }
    super.dispose();
  }

  void _sync(List<Alarm> next) {
    final list = _listKey.currentState;
    final nextIds = {for (final alarm in next) alarm.id};

    // Back to front: every index handed to removeItem is an index into the list
    // as it stands at that moment, and removing from the tail never shifts one.
    for (var i = _items.length - 1; i >= 0; i--) {
      if (nextIds.contains(_items[i].id)) continue;
      final gone = _items.removeAt(i);
      if (list == null) continue;
      list.removeItem(
        i,
        (context, animation) => SizeTransition(
          sizeFactor: animation,
          // Anchored at the top, so the row collapses upwards into the gap it
          // is leaving rather than sliding through the rows below.
          alignment: Alignment.topCenter,
          child: FadeTransition(
            opacity: animation,
            // A row on its way out is scenery: it must not be swipeable, or
            // deletable a second time.
            child: IgnorePointer(child: _AlarmTile(alarm: gone)),
          ),
        ),
        duration: _removeDuration,
      );
      late final Timer timer;
      timer = Timer(_removeDuration, () {
        _collapsing.remove(timer);
        if (mounted) setState(() {});
      });
      _collapsing.add(timer);
    }

    for (var i = 0; i < next.length; i++) {
      if (_items.any((alarm) => alarm.id == next[i].id)) continue;
      final at = i > _items.length ? _items.length : i;
      _items.insert(at, next[i]);
      list?.insertItem(at);
    }

    // Same alarm, new content — no animation, just the new values.
    for (var i = 0; i < _items.length && i < next.length; i++) {
      if (_items[i].id == next[i].id) _items[i] = next[i];
    }

    setState(() {});
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    Animation<double> animation,
  ) {
    final alarm = _items[index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Keyed by identity. Without it the swipe state — which row is open —
        // is reused by position, so the row that moves up into a deleted row's
        // slot arrives already swiped open.
        _AlarmTile(key: ValueKey(alarm.id), alarm: alarm),
        // The same hairline between every pair of rows, and none after the
        // last. A 覚悟 row is not a card any more — it is the same row in
        // different colours — so it gets the same separator as the calm ones.
        if (index != _items.length - 1) const Divider(height: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _collapsing.isEmpty) {
      return const Center(child: Text('アラームはまだありません'));
    }
    return AnimatedList(
      key: _listKey,
      initialItemCount: _items.length,
      itemBuilder: _buildItem,
    );
  }
}

class _AlarmTile extends ConsumerWidget {
  const _AlarmTile({super.key, required this.alarm});

  final Alarm alarm;

  /// This alarm's snoozed session — its id and its re-ring time — if it has one
  /// waiting. The id is what the 「起きた（解除）」 button settles.
  ({String id, DateTime until})? _snoozed(WidgetRef ref) {
    final now = DateTime.now();
    for (final session
        in ref.watch(ringingSessionsProvider).valueOrNull ??
            const <AlarmSession>[]) {
      if (session.alarmId == alarm.id && isSnoozePending(session, now)) {
        return (id: session.id, until: session.currentRingAt);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snoozed = _snoozed(ref);
    return SwipeToDelete(
      // Goes through the controller, so the platform alarm is cancelled before
      // the row disappears — a deleted alarm that still rings is the one bug
      // this screen must never have.
      onDelete: () => ref.read(alarmControllerProvider).delete(alarm),
      child: _AlarmRow(alarm: alarm, snoozed: snoozed),
    );
  }
}

enum _RowAction { duplicate, delete }

/// One row, whatever is at stake.
///
/// A 覚悟 alarm and a plain one are the *same* row: same structure, same
/// spacing, the time in the same place and the switch on the same pixel. What
/// changes is only the paint — near-black behind it, a red frame and a glow,
/// red text. An inset card or a badge column of its own would push the content
/// around, and a list whose rows do not line up is harder to read than one
/// loud row is worth.
class _AlarmRow extends ConsumerWidget {
  const _AlarmRow({required this.alarm, required this.snoozed});

  final Alarm alarm;
  final ({String id, DateTime until})? snoozed;

  /// 複製 / 削除, the two things a row can do that a tap cannot say.
  ///
  /// 削除 deletes straight away: choosing it out of a menu that only a long
  /// press opens is already the deliberate second step the swipe gets from its
  /// reveal-then-tap.
  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final choice = await showDialog<_RowAction>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        key: const ValueKey('alarmActionsDialog'),
        title: Text(hhmm(alarm.hour, alarm.minute)),
        children: [
          SimpleDialogOption(
            key: const ValueKey('alarmActionDuplicate'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_RowAction.duplicate),
            child: const Row(
              children: [
                Icon(Icons.copy_outlined),
                SizedBox(width: 16),
                Text('複製'),
              ],
            ),
          ),
          SimpleDialogOption(
            key: const ValueKey('alarmActionDelete'),
            onPressed: () => Navigator.of(dialogContext).pop(_RowAction.delete),
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: theme.colorScheme.error),
                const SizedBox(width: 16),
                Text('削除', style: TextStyle(color: theme.colorScheme.error)),
              ],
            ),
          ),
        ],
      ),
    );

    switch (choice) {
      case null:
        return;
      case _RowAction.duplicate:
        if (context.mounted) context.push(AppRoute.alarmDuplicate(alarm.id));
      case _RowAction.delete:
        await ref.read(alarmControllerProvider).delete(alarm);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kakugo = alarm.kakugo;
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

    // How many 共有先 this alarm still has. Counted against the live list, so a
    // 共有先 deleted from the app stops being counted here the moment it goes.
    // The row drops the honorific: it is a summary, not a sentence, and
    // 「💬 田中太郎」 is what the row reads.
    final shareCount = alarm.willShare
        ? liveShareTargetCount(
            alarm.share,
            ref.watch(discordWebhookListProvider),
          )
        : 0;

    // 人質なし puts nothing at stake, so it wears no danger badge: the gauge
    // reads a price, and there is no price.
    final badge = kakugo == null || !kakugo.hostage.burns
        ? ''
        : kakugoBadge(kakugo.ratePerMinute, kakugo.cap);

    final tile = ListTile(
      onTap: () => context.push(AppRoute.alarmEdit(alarm.id)),
      onLongPress: () => _showActions(context, ref),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hhmm(alarm.hour, alarm.minute),
            key: const ValueKey('alarmTime'),
            style: theme.textTheme.displaySmall?.copyWith(
              color: _timeColor(theme, kakugo != null, on),
            ),
          ),
          // Right beside the time, on the same line, and smaller than it — so
          // it cannot make the line taller than the row without one.
          if (badge.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                badge,
                key: const ValueKey('kakugoBadge'),
                style: const TextStyle(fontSize: 24),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            repeatDaysLabel(alarm.repeatDays),
            key: const ValueKey('alarmRepeat'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: kakugo == null
                  ? theme.colorScheme.onSurfaceVariant
                  : kakugoOnDanger.withValues(alpha: 0.75),
            ),
          ),
          Text(
            _summary(kakugo, contact, shareCount),
            key: const ValueKey('alarmSummary'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: kakugo == null
                  ? theme.colorScheme.onSurfaceVariant
                  : kakugoDanger,
            ),
          ),
          if (snoozed != null)
            _SnoozingRow(
              until: snoozed!.until,
              onWake: () =>
                  ref.read(alarmControllerProvider).dismissSnoozed(snoozed!.id),
            ),
        ],
      ),
      trailing: Switch(
        value: alarm.enabled,
        onChanged: (v) =>
            ref.read(alarmControllerProvider).setEnabled(alarm, v),
      ),
    );

    if (kakugo == null) return tile;

    return Container(
      // No margin and no padding: the frame is painted *over* the row
      // (foregroundDecoration), so the border cannot inset the content and
      // move the time out of line with the row above it.
      decoration: BoxDecoration(
        color: kakugoBackground,
        boxShadow: [
          BoxShadow(
            color: kakugoDanger.withValues(alpha: on ? 0.32 : 0.10),
            blurRadius: 14,
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          color: kakugoDanger.withValues(alpha: on ? 0.95 : 0.45),
          width: 1.5,
        ),
      ),
      // ListTile paints its ink and its text from the ambient colour scheme,
      // so the row gets a dark scheme of its own — otherwise the light themes
      // would draw black text on this black row. The editor's 覚悟 island does
      // the same.
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
        child: Material(color: Colors.transparent, child: tile),
      ),
    );
  }

  static Color? _timeColor(ThemeData theme, bool kakugo, bool on) {
    if (kakugo) {
      return on ? kakugoOnDanger : kakugoOnDanger.withValues(alpha: 0.4);
    }
    return on ? null : theme.disabledColor;
  }

  /// 「覚悟あり ・ 100 コイン/分 ・ 💬 田中太郎」 — the pledge, the price and who
  /// hears about it, in that order and only when there is one.
  ///
  /// A share-only alarm reads 「覚悟あり ・ … ・ Discord 2件」, and an alarm doing
  /// both names both. The route icons stay on the person: they say *how* that
  /// one person is reached, which a count of Discord rooms has no equivalent
  /// of.
  ///
  /// The per-minute price is dropped at 0: a 連絡だけ pledge burns nothing by
  /// the minute, and 「0 コイン/分」 on a row is noise.
  static String _summary(
    Kakugo? kakugo,
    OversleepContact? contact,
    int shareCount,
  ) => [
    kakugo == null ? '覚悟なし' : '覚悟あり',
    if (kakugo != null && kakugo.hostage.burns && kakugo.ratePerMinute > 0)
      kakugoRateLabel(kakugo.ratePerMinute, kakugo.hostage),
    if (contact != null)
      [
        if (contact.willSms) '💬',
        if (contact.willEmail) '✉',
        contact.name,
      ].join(' '),
    if (shareCount > 0) 'Discord $shareCount件',
  ].join(' ・ ');
}

/// 「スヌーズ中 7:05」 and the way out of it — spec 12.1, the 一覧経由 path. The
/// label is the same on both kinds of row: a pending re-ring is a fact about
/// the alarm, not about the pledge. The 「起きた（解除）」 button below it lets a
/// user who ignored the notification clear the snooze early without waiting for
/// the re-ring — no wake check, since a snooze already stopped one alarm.
class _SnoozingRow extends StatelessWidget {
  const _SnoozingRow({required this.until, required this.onWake});

  final DateTime until;
  final VoidCallback onWake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          snoozeUntilLabel(until),
          key: const ValueKey('snoozedUntil'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const ValueKey('wakeNowButton'),
            onPressed: onWake,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('起きた（解除）'),
          ),
        ),
      ],
    );
  }
}
