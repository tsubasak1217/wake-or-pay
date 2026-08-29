import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/sound_library.dart';
import '../../services/card_hostage.dart';
import '../../services/options.dart';
import 'alarm_controller.dart';
import 'alarm_draft.dart';
import 'contact_share_screen.dart';
import 'edit_sub_screens.dart';
import 'sound_screen.dart';
import 'widgets/settings_island.dart';

class AlarmEditScreen extends ConsumerStatefulWidget {
  const AlarmEditScreen({super.key, this.alarmId, this.duplicate = false});

  /// null when creating a new alarm.
  final String? alarmId;

  /// Opened on a copy of [alarmId] rather than on the alarm itself: every
  /// setting is carried over, only the id is new, and saving inserts a second
  /// alarm instead of overwriting the first.
  final bool duplicate;

  @override
  ConsumerState<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends ConsumerState<AlarmEditScreen> {
  /// The alarm the draft was seeded from. Held here so a later emission of
  /// [alarmByIdProvider] — the alarm being saved, most of all — cannot swap the
  /// draft out from under the editor. The old editor read `existing` only in
  /// `initState`, so this is the behaviour it already had.
  Alarm? _seed;

  @override
  Widget build(BuildContext context) {
    final id = widget.alarmId;
    if (id == null) {
      // New alarms start without kakugo: nothing is at stake until the user
      // deliberately puts something there. Snooze is the opposite — it starts
      // on, at the default interval and count, because that is what was asked
      // for: an alarm you can hit snooze on is the ordinary case, and having
      // to switch it on before the first use was the surprise.
      // Seeded at the current time rather than a fixed 07:00: the wheel opens
      // where the user already is, which is the shortest distance to the time
      // they actually mean.
      final now = ref.read(clockProvider)();
      return _AlarmEditForm(
        seed: _seed ??= Alarm(
          id: AlarmController.newId(),
          hour: now.hour,
          minute: now.minute,
          snooze: const Snooze(),
        ),
      );
    }

    final duplicate = widget.duplicate;
    final seeded = _seed;
    if (seeded != null) {
      return _AlarmEditForm(
        seed: seeded,
        // A copy has nothing to overwrite and nothing to delete: it is a new
        // alarm that merely started from an old one.
        existing: duplicate ? null : seeded,
        duplicate: duplicate,
      );
    }

    return ref
        .watch(alarmByIdProvider(id))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data: (data) => data == null
              ? const Scaffold(body: Center(child: Text('アラームが見つかりません')))
              : duplicate
              ? _AlarmEditForm(
                  // Everything copied — time, days, wake check, sound, grace,
                  // snooze, 覚悟, contact, share — and only the id renewed, so
                  // the save inserts rather than replaces.
                  seed: _seed = data.copyWith(id: AlarmController.newId()),
                  duplicate: true,
                )
              : _AlarmEditForm(seed: _seed = data, existing: data),
        );
  }
}

class _AlarmEditForm extends ConsumerStatefulWidget {
  const _AlarmEditForm({
    required this.seed,
    this.existing,
    this.duplicate = false,
  });

  /// The key of this editor's [alarmDraftProvider].
  final Alarm seed;

  final Alarm? existing;

  /// Copying an existing alarm. Wording only: the rule that no two alarms may
  /// share a clock time holds in all three modes.
  final bool duplicate;

  @override
  ConsumerState<_AlarmEditForm> createState() => _AlarmEditFormState();
}

class _AlarmEditFormState extends ConsumerState<_AlarmEditForm> {
  /// The form's own scroll position, so a refused save can carry the user back
  /// to the wheel — the only control that can clear the clash.
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Holds the draft open for as long as the editor is on screen, without
    // rebuilding anything when it changes. Without a listener the autoDispose
    // draft would be collected whenever no row happened to be watching.
    ref.listenManual(alarmDraftProvider(widget.seed), (_, _) {});
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Alarm get _draft => ref.read(alarmDraftProvider(widget.seed));

  Future<void> _save() async {
    final alarm = _draft;

    // The one rule the save can refuse on, in every mode. The button stays
    // pressable — a dead FAB explains nothing — and the press answers by
    // taking the user to the wheel, with the warning already under it.
    final all = ref.read(alarmsProvider).valueOrNull ?? const <Alarm>[];
    if (hasTimeClash(all, alarm)) {
      if (_scroll.hasClients) {
        await _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    final coins = (await ref.read(walletRepositoryProvider).read()).coins;
    if (!mounted) return;

    // A warning, never a block: pledging more than you hold is allowed, it
    // simply cannot all burn. Coins only — a card pledge is not measured
    // against the wallet, so a balance it cannot exceed says nothing.
    final cap = alarm.kakugo?.hostage == HostageType.card
        ? null
        : alarm.kakugo?.cap;
    if (cap != null && cap > coins) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('残高より上限が大きい'),
          content: Text(
            '上限 $cap コインに対して残高は $coins コインです。'
            '燃えるのは残高までですが、このまま保存できます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('戻る'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('このまま保存'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    await ref.read(alarmControllerProvider).save(alarm);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    await ref.read(alarmControllerProvider).delete(existing);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    debugAlarmEditBuildCount++;
    final seed = widget.seed;

    // The draft's time is deliberately *not* watched here: the wheel must be
    // able to write it on every frame of a drag without rebuilding the form
    // around it. The one widget that does depend on it — the warning under the
    // wheel — watches it itself.
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.duplicate
              ? 'アラームを複製'
              : widget.existing == null
              ? 'アラームを追加'
              : 'アラームを編集',
        ),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: '削除',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          TimeWheel(seed: seed),
          _TimeClashWarning(seed: seed),
          const SizedBox(height: 24),
          _BasicIsland(seed: seed),
          _SnoozeIsland(seed: seed),
          _KakugoIsland(seed: seed),
        ],
      ),
      floatingActionButton: _SaveFab(
        label: widget.duplicate ? '複製' : '保存',
        onPressed: _save,
      ),
    );
  }
}

/// The save button. Always pressable: a clash is answered by [_save], which
/// refuses and scrolls back to the wheel, rather than by a dead button that
/// says nothing about why.
///
/// Its own widget so it never has to watch the draft — nothing in the form
/// above the wheel may rebuild while the wheel is being spun.
class _SaveFab extends StatelessWidget {
  const _SaveFab({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
    key: const ValueKey('alarmSaveFab'),
    onPressed: onPressed,
    icon: const Icon(Icons.check),
    label: Text(label),
  );
}

/// 「同じ時刻のアラームがすでにあります」 — shown right under the wheel, because the
/// wheel is the only thing that can clear it.
///
/// In every mode, not only when copying: two alarms on the same minute are the
/// same confusing pair of rows however they got there. Editing an alarm without
/// moving it never trips this — [hasTimeClash] excludes the draft's own id.
///
/// Its own widget so that the time changing repaints this line and nothing
/// else.
class _TimeClashWarning extends ConsumerWidget {
  const _TimeClashWarning({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (hour, minute) = ref.watch(
      alarmDraftProvider(seed).select((a) => (a.hour, a.minute)),
    );
    final clash = hasTimeClash(
      ref.watch(alarmsProvider).valueOrNull ?? const <Alarm>[],
      seed.copyWith(hour: hour, minute: minute),
    );
    if (!clash) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '同じ時刻のアラームがすでにあります。別の時刻にしてください。',
        key: const ValueKey('duplicateTimeWarning'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Islands
//
// Every row below is its own widget subscribing to one field of the draft with
// `select`. That is what keeps the time wheel — which writes the draft on every
// frame of a drag — from rebuilding any of them.
// ---------------------------------------------------------------------------

class _BasicIsland extends StatelessWidget {
  const _BasicIsland({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context) => SettingsIsland(
    title: '基本設定',
    children: [
      _DaysRow(seed: seed),
      _WakeCheckRow(seed: seed),
      _SoundRow(seed: seed),
      _SnoozeToggleRow(seed: seed),
      _KakugoToggleRow(seed: seed),
    ],
  );
}

class _DaysRow extends ConsumerWidget {
  const _DaysRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The label, not the set: `select` compares with `==`, and two equal sets
    // are not `==` each other, so watching the set itself would rebuild this
    // row on every write to the draft — including every tick of the wheel.
    final label = ref.watch(
      alarmDraftProvider(seed).select((a) => repeatDaysLabel(a.repeatDays)),
    );
    return SettingRow(
      label: '曜日',
      value: label,
      onTap: () => pushEditorSubScreen(
        context,
        RepeatDaysSubScreen(
          initial: ref.read(alarmDraftProvider(seed)).repeatDays,
          onCommit: (days) => ref
              .read(alarmDraftProvider(seed).notifier)
              .update((a) => a.copyWith(repeatDays: days)),
        ),
      ),
    );
  }
}

class _WakeCheckRow extends ConsumerWidget {
  const _WakeCheckRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wakeCheck = ref.watch(
      alarmDraftProvider(seed).select((a) => a.wakeCheck),
    );
    return SettingRow(
      label: '起床確認方法',
      value: wakeCheck.label,
      onTap: () => pushEditorSubScreen(
        context,
        WakeCheckSubScreen(
          initial: wakeCheck,
          onCommit: (type) => ref
              .read(alarmDraftProvider(seed).notifier)
              .update((a) => a.copyWith(wakeCheck: type)),
        ),
      ),
    );
  }
}

class _SoundRow extends ConsumerWidget {
  const _SoundRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundId = ref.watch(
      alarmDraftProvider(seed).select((a) => a.soundId),
    );
    return SettingRow(
      label: 'サウンド',
      value: soundLabel(soundId),
      onTap: () => pushEditorSubScreen(
        context,
        SoundSubScreen(
          initial: soundId,
          onCommit: (id) => ref
              .read(alarmDraftProvider(seed).notifier)
              .update((a) => a.copyWith(soundId: id)),
        ),
      ),
    );
  }
}

class _SnoozeToggleRow extends ConsumerWidget {
  const _SnoozeToggleRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(alarmDraftProvider(seed).select((a) => a.canSnooze));
    return SettingSwitchRow(
      label: 'スヌーズ',
      value: on,
      onChanged: (v) => ref
          .read(alarmDraftProvider(seed).notifier)
          .update(
            (a) => v
                ? a.copyWith(snooze: const Snooze())
                : a.copyWith(clearSnooze: true),
          ),
    );
  }
}

class _KakugoToggleRow extends ConsumerWidget {
  const _KakugoToggleRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(alarmDraftProvider(seed).select((a) => a.isKakugo));
    return SettingSwitchRow(
      label: '覚悟',
      value: on,
      labelColor: Theme.of(context).colorScheme.error,
      subtitle: '起床に対するあなたの"覚悟"を設定できます',
      onChanged: (v) => ref
          .read(alarmDraftProvider(seed).notifier)
          .update(
            (a) => v
                ? a.copyWith(kakugo: a.kakugo ?? defaultKakugo)
                : a.copyWith(clearKakugo: true),
          ),
    );
  }
}

class _SnoozeIsland extends ConsumerWidget {
  const _SnoozeIsland({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(alarmDraftProvider(seed).select((a) => a.canSnooze));
    if (!on) return const SizedBox.shrink();
    return SettingsIsland(
      title: 'スヌーズ設定',
      children: [
        _SnoozeIntervalRow(seed: seed),
        _SnoozeCountRow(seed: seed),
      ],
    );
  }
}

class _SnoozeIntervalRow extends ConsumerWidget {
  const _SnoozeIntervalRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = ref.watch(
      alarmDraftProvider(seed).select(
        (a) => a.snooze?.intervalMinutes ?? Snooze.defaultIntervalMinutes,
      ),
    );
    return SettingRow(
      label: '間隔',
      value: '$minutes分',
      onTap: () => pushEditorSubScreen(
        context,
        NumberSubScreen(
          title: 'スヌーズの間隔',
          initial: minutes,
          min: minSnoozeIntervalMinutes,
          max: maxSnoozeIntervalMinutes,
          suffix: '分',
          description: 'スヌーズを押してから次に鳴るまでの時間です。',
          onCommit: (v) => ref
              .read(alarmDraftProvider(seed).notifier)
              .update(
                (a) => a.copyWith(
                  snooze: (a.snooze ?? const Snooze()).copyWith(
                    intervalMinutes: v,
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

class _SnoozeCountRow extends ConsumerWidget {
  const _SnoozeCountRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      alarmDraftProvider(seed)
          .select((a) => a.snooze?.maxCount ?? Snooze.defaultMaxCount),
    );
    return SettingRow(
      label: '上限回数',
      value: '$count回',
      onTap: () => pushEditorSubScreen(
        context,
        NumberSubScreen(
          title: 'スヌーズの上限回数',
          initial: count,
          min: minSnoozeMaxCount,
          max: maxSnoozeMaxCount,
          suffix: '回',
          description:
              'この回数までスヌーズできます。0 は無制限ではなく「スヌーズできない」という意味です。'
              '無制限は用意していません。',
          onCommit: (v) => ref
              .read(alarmDraftProvider(seed).notifier)
              .update(
                (a) => a.copyWith(
                  snooze: (a.snooze ?? const Snooze()).copyWith(maxCount: v),
                ),
              ),
        ),
      ),
    );
  }
}

/// The danger area. Red on near-black, with the worst case spelled out at the
/// top: the point of the editor is that nobody switches this on by accident.
class _KakugoIsland extends ConsumerWidget {
  const _KakugoIsland({required this.seed});

  final Alarm seed;

  // The one 覚悟 palette, shared with the alarm list's row for the same alarm
  // so the two never disagree about what danger looks like.
  static const background = kakugoBackground;
  static const danger = kakugoDanger;
  static const onDanger = kakugoOnDanger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(alarmDraftProvider(seed).select((a) => a.isKakugo));
    if (!on) return const SizedBox.shrink();

    // Read here rather than inside the two rows: [SettingsIsland] draws a
    // hairline between every child, so a row that returns an empty box would
    // still leave its divider behind.
    final canSnooze = ref.watch(
      alarmDraftProvider(seed).select((a) => a.canSnooze),
    );
    // 人質なし is 連絡だけの覚悟: there is no amount to set, so the three money
    // rows and the running total above them are not merely disabled, they are
    // absent. Dropped from the list rather than returned empty — the island
    // draws a hairline between children, and an empty child leaves its divider
    // behind.
    final burns = ref.watch(
      alarmDraftProvider(seed)
          .select((a) => a.kakugo?.hostage.burns ?? false),
    );
    // The same bool [_ContactShareRow] draws 「設定済み」 from, read here for the
    // same reason the two above are: a row that returned an empty box would
    // leave its divider behind.
    final notifies = ref.watch(
      alarmDraftProvider(seed).select(
        (a) => (a.contact?.isUsable ?? false) || (a.share?.isUsable ?? false),
      ),
    );

    final theme = Theme.of(context);
    // ListTile paints from the ambient colour scheme, so the whole island gets
    // a dark scheme of its own — otherwise the light themes would draw black
    // text on this black card.
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          brightness: Brightness.dark,
          surface: background,
          onSurface: onDanger,
          onSurfaceVariant: danger,
          error: danger,
        ),
        dividerColor: danger.withValues(alpha: 0.3),
      ),
      child: SettingsIsland(
        title: '覚悟の設定',
        titleColor: theme.colorScheme.error,
        background: background,
        borderColor: danger,
        header: burns ? _MaxLossHeader(seed: seed) : null,
        children: [
          // First, because it decides what every number below is measured in —
          // and whether there are any numbers below at all.
          _HostageRow(seed: seed),
          _ContactShareRow(seed: seed),
          // 起床猶予 is the moment two things happen: the burn begins, and the
          // 連絡・共有 goes out. Shown whenever either of those exists — and
          // only then, because a pledge with 人質なし and nobody to tell has
          // neither, so the number would decide nothing, and a row that
          // decides nothing is a question the user should not be asked.
          if (burns || notifies) _GraceRow(seed: seed),
          if (burns) _RateRow(seed: seed),
          // Only means anything when the alarm can be snoozed at all, so it
          // follows the スヌーズ toggle in the island above. Neither 「スヌーズ中
          // の加算」 nor 「起床猶予」 is a row of its own: both live inside the
          // 寝坊ペナルティ sub-screen, which holds the number they qualify.
          if (burns && canSnooze) _SnoozePenaltyRow(seed: seed),
          if (burns) _CapRow(seed: seed),
        ],
      ),
    );
  }
}

/// 人質: what oversleeping actually costs — the coins, or the card.
///
/// A card pledge whose card has since been taken back in プロフィール keeps the
/// label 「クレジットカード」 but in the error colour, with a subtitle saying the
/// card is missing and where to register one. The stored alarm is left
/// exactly as it is: the user chose the card, and the editor's job is to say
/// that the choice currently has nothing behind it, not to quietly rewrite it.
/// [SessionService.settle] falls back to coins for such a ring.
class _HostageRow extends ConsumerWidget {
  const _HostageRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostage = ref.watch(
      alarmDraftProvider(seed)
          .select((a) => a.kakugo?.hostage ?? HostageType.none),
    );
    final card = ref.watch(cardHostageProvider.select((s) => s.card));

    final unregistered = hostage == HostageType.card && card == null;
    return SettingRow(
      key: const ValueKey('hostageRow'),
      label: '人質',
      // Just the label, never the card itself: 「クレジットカード（VISA •••• 4242）」
      // does not fit the row, and which card it is belongs to プロフィール. The
      // one thing worth saying here is when there is no card at all.
      value: hostage.label,
      valueColor: unregistered ? Theme.of(context).colorScheme.error : null,
      subtitle: unregistered ? 'カードが未登録です（プロフィールで登録できます）' : null,
      onTap: () => pushEditorSubScreen(
        context,
        HostageSubScreen(
          initial: hostage,
          onCommit: (type) => ref
              .read(alarmDraftProvider(seed).notifier)
              .update((a) {
                final kakugo = a.kakugo ?? defaultKakugo;
                return a.copyWith(
                  kakugo: kakugo.copyWith(
                    hostage: type,
                    // Leaving 人質なし behind means the rate becomes a real
                    // price for the first time, and a rate carried over from
                    // the 連絡だけ spelling can be below the bound the editor
                    // now offers. Seeding it is the only way the row that
                    // appears reads as something the user could have set.
                    ratePerMinute:
                        type.burns && kakugo.ratePerMinute < minKakugoRate
                        ? defaultKakugo.ratePerMinute
                        : kakugo.ratePerMinute,
                  ),
                );
              }),
        ),
      ),
    );
  }
}

/// 起床猶予: how long the alarm may ring before the morning counts as overslept.
///
/// A row of the island, and the **only** place this number is edited. It used
/// to sit inside the 寝坊ペナルティ sub-screen, next to the rate it qualifies;
/// that put it out of reach of a pledge with no rate at all, and one number
/// with two editors is one number with two places to disagree.
///
/// Hidden only when the window would decide nothing — see the rule in
/// [_KakugoIsland]'s children.
class _GraceRow extends ConsumerWidget {
  const _GraceRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = alarmDraftProvider(seed);
    final grace = ref.watch(draft.select((a) => a.graceMinutes));
    return SettingRow(
      key: const ValueKey('graceRow'),
      label: '起床猶予',
      value: '$grace分',
      onTap: () => pushEditorSubScreen(
        context,
        NumberSubScreen(
          title: '起床猶予',
          initial: grace,
          min: minGraceMinutes,
          max: maxGraceMinutes,
          suffix: '分',
          description: '鳴り始めからこの時間以内に起床確認をクリアできれば起床成功。'
              '過ぎるとその瞬間から寝坊で、ペナルティと連絡・共有が動き始めます。',
          onCommit: (v) => ref
              .read(draft.notifier)
              .update((a) => a.copyWith(graceMinutes: v)),
        ),
      ),
    );
  }
}

/// 寝坊時連絡・共有: everything about telling somebody, behind one row.
///
/// 設定済み / なし rather than a name: the row now stands for a person, a set
/// of Discord 共有先, a delay, and two message bodies. Naming only the person
/// would leave a share-only alarm reading 「なし」 over an alarm that announces
/// itself to a room.
class _ContactShareRow extends ConsumerWidget {
  const _ContactShareRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A bool, not the contact or the share: `select` compares with `==`, and
    // watching either object would rebuild this row for a change to any of
    // their fields — including, through the draft, every tick of the time
    // wheel.
    final configured = ref.watch(
      alarmDraftProvider(seed).select(
        (a) => (a.contact?.isUsable ?? false) || (a.share?.isUsable ?? false),
      ),
    );
    return SettingRow(
      key: const ValueKey('contactShareRow'),
      label: '寝坊時連絡・共有',
      value: configured ? '設定済み' : 'なし',
      onTap: () {
        final draft = ref.read(alarmDraftProvider(seed));
        unawaited(
          pushEditorSubScreen(
            context,
            ContactShareSubScreen(
              alarmId: seed.id,
              contact: draft.contact,
              share: draft.share,
              triggerMinutes: draft.triggerMinutes,
              onCommit: (contact, share, trigger) => ref
                  .read(alarmDraftProvider(seed).notifier)
                  .update(
                    (a) => a.copyWith(
                      contact: contact,
                      clearContact: contact == null,
                      share: share,
                      clearShare: share == null,
                      oversleepTriggerMinutes: trigger,
                    ),
                  ),
            ),
          ),
        );
      },
    );
  }
}

/// スヌーズペナルティ: the coin cost of one press, 0 up to this alarm's 上限金額.
class _SnoozePenaltyRow extends ConsumerWidget {
  const _SnoozePenaltyRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = alarmDraftProvider(seed);
    final penalty = ref.watch(
      draft.select((a) => a.kakugo?.snoozePenalty ?? 0),
    );
    // A penalty above the cap is unreachable, so the cap is the bound offered.
    final cap = ref.watch(
      draft.select((a) => a.kakugo?.cap ?? defaultKakugo.cap),
    );
    final hostage = ref.watch(
      draft.select((a) => a.kakugo?.hostage ?? HostageType.coin),
    );
    return SettingRow(
      label: 'スヌーズペナルティ',
      value: hostageAmount(penalty, hostage),
      onTap: () => pushEditorSubScreen(
        context,
        NumberSubScreen(
          title: 'スヌーズペナルティ',
          initial: penalty,
          min: minSnoozePenalty,
          max: cap,
          suffix: hostage.unit,
          description: switch (hostage) {
            // none never reaches here: the row is not built for it.
            HostageType.none || HostageType.coin =>
              'スヌーズを1回押すごとに燃えるコインです。0 ならスヌーズは無料のままです。'
                  'スヌーズ自体はいつでも無料で使えます。これはあなたが自分に課した罰であって、'
                  '買うものではありません。',
            HostageType.card =>
              'スヌーズを1回押すごとに積み上がる金額です。0 ならスヌーズは無料のままです。'
                  'スヌーズ自体はいつでも無料で使えます。これはあなたが自分に課した罰であって、'
                  '買うものではありません。',
          },
          onCommit: (v) => ref
              .read(draft.notifier)
              .update(
                (a) => a.copyWith(
                  kakugo: (a.kakugo ?? defaultKakugo).copyWith(
                    snoozePenalty: v,
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

/// スヌーズ中の加算: which of the two clocks spec 4 defines this pledge bills on.
///
/// Not a row of its own any more. It sits inside the 寝坊ペナルティ sub-screen,
/// under the slider, because it decides *which minutes* that rate is charged
/// for — reading it next to the number is the whole point.
///
/// Unlike the sub-screens, this one writes the draft as it is tapped rather
/// than on the way out: it is already inside a sub-screen whose own value is
/// committed on pop, and a second deferred commit would race with it.
class _SnoozeClockSelector extends ConsumerWidget {
  const _SnoozeClockSelector({required this.seed});

  final Alarm seed;

  static const continuousLabel = '規定時刻から加算し続ける';
  static const resetLabel = '次に鳴る時刻を起点にし直す';

  // Reset first, and marked 推奨: it is the default for new alarms (改訂5), the
  // mode where snoozed time costs nothing but the per-press penalty. Continuing
  // to burn through a snooze is the deliberate opt-in below it.
  static const _options = <({bool value, String label, String description})>[
    (
      value: true,
      label: '$resetLabel（推奨）',
      description: '鳴っていない間はコインが燃えません（スヌーズ罰だけ）。再び鳴った時点から、猶予もあらためて数え直します。',
    ),
    (
      value: false,
      label: continuousLabel,
      description: 'スヌーズで鳴っていない間もコインは燃え続けます。厳しいほう。',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = alarmDraftProvider(seed);
    // An alarm that cannot be snoozed has no snoozed minutes to bill.
    if (!ref.watch(draft.select((a) => a.canSnooze))) {
      return const SizedBox.shrink();
    }
    final resets = ref.watch(
      draft.select((a) => a.kakugo?.snoozeResetsClock ?? false),
    );
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text(
          'スヌーズ中の加算',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        // RadioGroup, not the deprecated Radio.groupValue/onChanged pair: the
        // group owns the selection now, and each tile only names its value.
        RadioGroup<bool>(
          groupValue: resets,
          onChanged: (value) {
            if (value == null) return;
            ref
                .read(draft.notifier)
                .update(
                  (a) => a.copyWith(
                    kakugo: (a.kakugo ?? defaultKakugo).copyWith(
                      snoozeResetsClock: value,
                    ),
                  ),
                );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in _options)
                RadioListTile<bool>(
                  key: ValueKey(
                    option.value ? 'snoozeClockReset' : 'snoozeClockContinuous',
                  ),
                  value: option.value,
                  selected: resets == option.value,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: resets == option.value
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    option.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'どちらを選んでも、スヌーズを1回でも押した朝は起床失敗です。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MaxLossHeader extends ConsumerWidget {
  const _MaxLossHeader({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The cap is what the pledge can cost — but only if anything can reach it.
    // With no per-minute penalty and no snooze penalty (or no snooze at all)
    // nothing ever adds up, and a header shouting 1000 コイン over an alarm
    // that cannot take a single coin is a lie about the stake.
    final worst = ref.watch(
      alarmDraftProvider(seed).select((a) {
        final kakugo = a.kakugo;
        if (kakugo == null) return 0;
        final snoozePart = a.snooze == null ? 0 : kakugo.snoozePenalty;
        return kakugo.ratePerMinute == 0 && snoozePart == 0 ? 0 : kakugo.cap;
      }),
    );
    // 「1000 コイン」 or 「1,000 円」 — the same stored number, read in the unit
    // the chosen 人質 is measured in.
    final hostage = ref.watch(
      alarmDraftProvider(seed)
          .select((a) => a.kakugo?.hostage ?? HostageType.coin),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          Text(
            '寝坊で失う最大金額',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: _KakugoIsland.onDanger),
          ),
          const SizedBox(height: 4),
          Text(
            hostageAmount(worst, hostage),
            key: const ValueKey('maxLoss'),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: _KakugoIsland.danger,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateRow extends ConsumerWidget {
  const _RateRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(
      alarmDraftProvider(seed).select((a) => a.kakugo?.ratePerMinute ?? 0),
    );
    // The gauge is read from the ratio rate/cap rather than from the rate on
    // its own, so the sub-screen needs the cap this pledge plays against — and
    // the cap is also the upper bound the rate may be set to.
    final cap = ref.watch(
      alarmDraftProvider(seed)
          .select((a) => a.kakugo?.cap ?? defaultKakugo.cap),
    );
    final hostage = ref.watch(
      alarmDraftProvider(seed)
          .select((a) => a.kakugo?.hostage ?? HostageType.coin),
    );
    return SettingRow(
      label: '寝坊ペナルティ',
      value: kakugoRateLabel(rate, hostage),
      onTap: () => pushEditorSubScreen(
        context,
        NumberSubScreen(
          title: '寝坊ペナルティ',
          initial: rate,
          min: minKakugoRate,
          // Bounded by this alarm's own cap: a rate above it can never be paid.
          max: cap,
          suffix: '${hostage.unit}/分',
          description: switch (hostage) {
            // none never reaches here: the row is not built for it, which is
            // also why neither sentence offers 0 any more — 連絡だけの覚悟 is
            // said by choosing 人質「なし」, one row up.
            HostageType.none || HostageType.coin =>
              '猶予を過ぎたあと、1分ごとに燃えるコインです。',
            HostageType.card => '猶予を過ぎたあと、1分ごとに積み上がる金額です。',
          },
          footer: (context, value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  kakugoMood(value, cap),
                  key: const ValueKey('kakugoGauge'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              // 起床猶予 is not here any more: it is a row of the island, the
              // one place it is edited from.
              _SnoozeClockSelector(seed: seed),
            ],
          ),
          onCommit: (v) => ref
              .read(alarmDraftProvider(seed).notifier)
              .update(
                (a) => a.copyWith(
                  kakugo: (a.kakugo ?? defaultKakugo).copyWith(
                    ratePerMinute: v,
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

class _CapRow extends ConsumerWidget {
  const _CapRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cap = ref.watch(
      alarmDraftProvider(seed).select((a) => a.kakugo?.cap ?? 0),
    );
    final hostage = ref.watch(
      alarmDraftProvider(seed)
          .select((a) => a.kakugo?.hostage ?? HostageType.coin),
    );
    // Only a coin pledge can outrun a balance. A card is not a wallet with a
    // number in it, so the warning below is coin-only.
    final coins = hostage == HostageType.coin
        ? ref.watch(walletProvider).valueOrNull?.coins
        : null;
    return SettingRow(
      label: '上限金額',
      value: hostageAmount(cap, hostage),
      onTap: () => pushEditorSubScreen(
        context,
        NumberSubScreen(
          title: '上限金額',
          initial: cap,
          min: minKakugoCap,
          // The オプション ceiling, or the cap this alarm already carries when
          // that is higher: an alarm saved under a higher ceiling must still
          // open at its own number instead of being clamped down on sight.
          max: effectiveCapCeiling(ref.watch(capCeilingProvider), cap),
          suffix: hostage.unit,
          description: switch (hostage) {
            // none never reaches here: the row is not built for it.
            HostageType.none ||
            HostageType.coin => 'このアラーム1回で燃える上限です。実際に燃えるのは鳴動時の残高までです。',
            HostageType.card => 'このアラーム1回でカードに請求される上限です。',
          },
          footer: (context, value) => coins != null && value > coins
              ? Text(
                  '残高 $coins コインを超えています。'
                  'このまま保存できますが、燃えるのは残高までです。',
                  key: const ValueKey('capOverBalance'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              : const SizedBox.shrink(),
          onCommit: (v) => ref
              .read(alarmDraftProvider(seed).notifier)
              .update(
                // Lowering the cap pulls both penalties down with it: nothing
                // may be set above the most this alarm can ever cost.
                (a) =>
                    a.copyWith(kakugo: withCap(a.kakugo ?? defaultKakugo, v)),
              ),
        ),
      ),
    );
  }
}

/// The iOS style hour/minute wheels, 24 hour, inline in the form.
///
/// Cupertino widgets carry their own theme, so the picker is wrapped in a
/// [CupertinoTheme] built from the Material one — otherwise it would ignore the
/// app's colours and read as black text on the dark themes.
///
/// It *writes* the draft's time and never watches it. Watching would rebuild
/// the picker on every tick of its own wheel — and `initialDateTime` is read
/// once, so the rebuild would only ever be wasted work. The seeded time is read
/// with `ref.read` for the same reason: it is an initial value, not a
/// subscription.
class TimeWheel extends ConsumerWidget {
  const TimeWheel({super.key, required this.seed});

  /// The draft's family key.
  final Alarm seed;

  static const height = 190.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final draft = ref.read(alarmDraftProvider(seed));
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: theme.brightness,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle:
                theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ) ??
                // Only reached if the Material theme has no headlineSmall at
                // all; even then the wheel must not fall back to Roboto.
                const TextStyle(fontFamily: appFontFamily),
          ),
        ),
        child: CupertinoDatePicker(
          key: const ValueKey('timeWheel'),
          mode: CupertinoDatePickerMode.time,
          use24hFormat: true,
          // A fixed date: only the hour and minute of this value are read.
          initialDateTime: DateTime(2026, 1, 1, draft.hour, draft.minute),
          onDateTimeChanged: (t) => ref
              .read(alarmDraftProvider(seed).notifier)
              .setTime(t.hour, t.minute),
        ),
      ),
    );
  }
}
