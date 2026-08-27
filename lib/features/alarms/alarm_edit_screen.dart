import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/oversleep_contact_rules.dart';
import '../../domain/sound_library.dart';
import 'alarm_controller.dart';
import 'alarm_draft.dart';
import 'contact_screen.dart';
import 'edit_sub_screens.dart';
import 'sound_screen.dart';
import 'widgets/settings_island.dart';

class AlarmEditScreen extends ConsumerStatefulWidget {
  const AlarmEditScreen({super.key, this.alarmId});

  /// null when creating a new alarm.
  final String? alarmId;

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
      // deliberately puts something there.
      return _AlarmEditForm(
        seed: _seed ??= Alarm(id: AlarmController.newId(), hour: 7, minute: 0),
      );
    }

    final seeded = _seed;
    if (seeded != null) return _AlarmEditForm(seed: seeded, existing: seeded);

    return ref
        .watch(alarmByIdProvider(id))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data: (data) => data == null
              ? const Scaffold(body: Center(child: Text('アラームが見つかりません')))
              : _AlarmEditForm(seed: _seed = data, existing: data),
        );
  }
}

class _AlarmEditForm extends ConsumerStatefulWidget {
  const _AlarmEditForm({required this.seed, this.existing});

  /// The key of this editor's [alarmDraftProvider].
  final Alarm seed;

  final Alarm? existing;

  @override
  ConsumerState<_AlarmEditForm> createState() => _AlarmEditFormState();
}

class _AlarmEditFormState extends ConsumerState<_AlarmEditForm> {
  @override
  void initState() {
    super.initState();
    // Holds the draft open for as long as the editor is on screen, without
    // rebuilding anything when it changes. Without a listener the autoDispose
    // draft would be collected whenever no row happened to be watching.
    ref.listenManual(alarmDraftProvider(widget.seed), (_, _) {});
  }

  Alarm get _draft => ref.read(alarmDraftProvider(widget.seed));

  Future<void> _save() async {
    final alarm = _draft;
    final coins = (await ref.read(walletRepositoryProvider).read()).coins;
    if (!mounted) return;

    // A warning, never a block: pledging more than you hold is allowed, it
    // simply cannot all burn.
    final cap = alarm.kakugo?.cap;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'アラームを追加' : 'アラームを編集'),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          TimeWheel(seed: seed),
          const SizedBox(height: 24),
          _BasicIsland(seed: seed),
          _SnoozeIsland(seed: seed),
          _KakugoIsland(seed: seed),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('保存'),
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
      _GraceRow(seed: seed),
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

class _GraceRow extends ConsumerWidget {
  const _GraceRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grace = ref.watch(
      alarmDraftProvider(seed).select((a) => a.graceMinutes),
    );
    return SettingRow(
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
          description:
              '鳴り始めからこの時間以内に起床確認をクリアできれば起床成功。'
              '過ぎるとその瞬間から燃え始めます。',
          onCommit: (v) => ref
              .read(alarmDraftProvider(seed).notifier)
              .update((a) => a.copyWith(graceMinutes: v)),
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
        header: _MaxLossHeader(seed: seed),
        children: [
          _ContactRow(seed: seed),
          _RateRow(seed: seed),
          // Only means anything when the alarm can be snoozed at all, so it
          // follows the スヌーズ toggle in the island above. 「スヌーズ中の加算」
          // is no longer a row of its own: it lives inside the 寝坊ペナルティ
          // sub-screen, which is the number it modifies.
          if (canSnooze) _SnoozePenaltyRow(seed: seed),
          _CapRow(seed: seed),
        ],
      ),
    );
  }
}

/// 寝坊時連絡先: the one person told when the oversleeping runs long.
class _ContactRow extends ConsumerWidget {
  const _ContactRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The name as the 連絡帳 has it now, not the copy carried on the draft:
    // renaming somebody in the book has to show up here without re-picking.
    final book = ref.watch(contactBookListProvider);
    // The name, not the contact: `select` compares with `==`, and watching the
    // object would rebuild this row for a change to any of its six fields.
    final label = ref.watch(
      alarmDraftProvider(seed).select(
        (a) => resolveOversleepContactOrNull(a.contact, book)?.name ?? 'なし',
      ),
    );
    return SettingRow(
      label: '寝坊時連絡先',
      value: label,
      onTap: () => pushEditorSubScreen(
        context,
        ContactSubScreen(
          alarmId: seed.id,
          initial: ref.read(alarmDraftProvider(seed)).contact,
          onCommit: (v) => ref
              .read(alarmDraftProvider(seed).notifier)
              .update(
                (a) => v == null
                    ? a.copyWith(clearContact: true)
                    : a.copyWith(contact: v),
              ),
        ),
      ),
    );
  }
}

/// スヌーズペナルティ: the coin cost of one press, 0-1000.
class _SnoozePenaltyRow extends ConsumerWidget {
  const _SnoozePenaltyRow({required this.seed});

  final Alarm seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = alarmDraftProvider(seed);
    final penalty = ref.watch(
      draft.select((a) => a.kakugo?.snoozePenalty ?? 0),
    );
    return SettingRow(
      label: 'スヌーズペナルティ',
      value: '$penalty コイン',
      onTap: () => pushEditorSubScreen(
        context,
        NumberSubScreen(
          title: 'スヌーズペナルティ',
          initial: penalty,
          min: minSnoozePenalty,
          max: maxSnoozePenalty,
          suffix: 'コイン',
          description:
              'スヌーズを1回押すごとに燃えるコインです。0 ならスヌーズは無料のままです。'
              'スヌーズ自体はいつでも無料で使えます。これはあなたが自分に課した罰であって、'
              '買うものではありません。',
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

  static const _options = <({bool value, String label, String description})>[
    (
      value: false,
      label: continuousLabel,
      description: 'スヌーズで鳴っていない間もコインは燃え続けます。厳しいほう。',
    ),
    (
      value: true,
      label: resetLabel,
      description: '鳴っていない間は燃えません。再び鳴った時点から、猶予もあらためて数え直します。',
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
        Text('スヌーズ中の加算', style: theme.textTheme.titleMedium),
        for (final option in _options)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => ref
                .read(draft.notifier)
                .update(
                  (a) => a.copyWith(
                    kakugo: (a.kakugo ?? defaultKakugo).copyWith(
                      snoozeResetsClock: option.value,
                    ),
                  ),
                ),
            title: Text(option.label),
            subtitle: Text(option.description),
            trailing: resets == option.value ? const Icon(Icons.check) : null,
          ),
        Text(
          'どちらを選んでも、スヌーズを1回でも押した朝は起床失敗です。',
          style: theme.textTheme.bodyMedium,
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
    final cap = ref.watch(
      alarmDraftProvider(seed).select((a) => a.kakugo?.cap ?? 0),
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
            '$cap コイン',
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
    return SettingRow(
      label: '寝坊ペナルティ',
      value: '$rate コイン/分',
      onTap: () => pushEditorSubScreen(
        context,
        NumberSubScreen(
          title: '寝坊ペナルティ',
          initial: rate,
          min: minKakugoRate,
          max: maxKakugoRate,
          suffix: 'コイン/分',
          description: '猶予を過ぎたあと、1分ごとに燃えるコインです。',
          footer: (context, value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  kakugoMood(value),
                  key: const ValueKey('kakugoGauge'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
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
    final coins = ref.watch(walletProvider).valueOrNull?.coins;
    return SettingRow(
      label: '上限金額',
      value: '$cap コイン',
      onTap: () => pushEditorSubScreen(
        context,
        NumberSubScreen(
          title: '上限金額',
          initial: cap,
          min: minKakugoCap,
          max: maxKakugoCap,
          suffix: 'コイン',
          description: 'このアラーム1回で燃える上限です。実際に燃えるのは鳴動時の残高までです。',
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
                (a) => a.copyWith(
                  kakugo: (a.kakugo ?? defaultKakugo).copyWith(cap: v),
                ),
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
