import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../services/app_update.dart';
import '../../services/options.dart';
import '../../services/sample_data.dart';
import '../alarms/widgets/settings_island.dart';
import '../update/update_banner.dart';
import '../widgets/top_sheet.dart';

/// Drops オプション over whatever is on screen, from the top.
///
/// The same sheet as プロフィール — same route, same grab bar, same 閉じる — because
/// the two buttons sit at opposite ends of the same header and must not feel
/// like two different mechanisms.
Future<void> showOptionsOverlay(BuildContext context) => showTopSheet(
  context,
  barrierLabel: 'オプションを閉じる',
  builder: (_) => const OptionsOverlay(),
);

class OptionsOverlay extends ConsumerWidget {
  const OptionsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return TopSheetOverlay(
      scaffoldKey: const ValueKey('optionsOverlay'),
      handleKey: const ValueKey('optionsOverlayHandle'),
      closeKey: const ValueKey('optionsOverlayClose'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 20),
          child: Text('オプション', style: theme.textTheme.titleLarge),
        ),
        const SettingsIsland(
          title: 'アプリ',
          children: [_SettingsRow(), _UpdateRow()],
        ),
        const _DangerIsland(),
        const _DevIsland(),
      ],
    );
  }
}

/// 「設定・テーマ」 — the only way into 設定 now that ショップ sells nothing but
/// coins and carries no links of its own.
///
/// The sheet is closed before the push: 設定 is a full screen, and leaving the
/// overlay stacked over it would put a barrier between the user and the screen
/// they asked for.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow();

  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('optionsSettingsRow'),
    leading: const Icon(Icons.tune),
    title: const Text('設定・テーマ'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      // Resolved before the pop: after it this context is defunct.
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(AppRoute.settings);
    },
  );
}

/// 「アプリの更新」 — the manual half of the sideloaded build's update check.
///
/// The value is the build that is *running*, because that is the only number
/// a user can compare against a release page. The subtitle is the answer to
/// 「押したらどうなる？」: 最新です, 「build N が利用できます」, or 未確認 before
/// anything has ever come back.
class _UpdateRow extends ConsumerWidget {
  const _UpdateRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(appUpdateProvider);

    final String subtitle;
    if (update.checking) {
      subtitle = '確認しています…';
    } else if (update.available != null) {
      subtitle = 'build ${update.available!.build} が利用できます';
    } else if (update.lastCheckedAt == null) {
      subtitle = '未確認';
    } else {
      subtitle = '最新です';
    }

    return SettingRow(
      key: const ValueKey('optionsUpdateRow'),
      leading: const Icon(Icons.system_update),
      label: 'アプリの更新',
      value: update.currentLabel,
      subtitle: subtitle,
      // A tap is a request for a fresh answer, so the throttle is skipped.
      // The dialog opens either way — 「最新です」 is an answer worth showing,
      // and a tap that appears to do nothing reads as a broken row.
      onTap: update.checking
          ? null
          : () async {
              await ref.read(appUpdateProvider.notifier).check(force: true);
              if (context.mounted) await showUpdateDialog(context);
            },
    );
  }
}

/// 開発用 — the island that fills the charts with a made-up year so they can be
/// looked at before anybody has lived through one.
///
/// Under 危険な設定 on purpose: nothing in it raises what a morning costs, and
/// nothing in it belongs above a setting the user actually makes.
class _DevIsland extends ConsumerWidget {
  const _DevIsland();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SettingsIsland(
      key: const ValueKey('optionsDevIsland'),
      title: '開発用',
      footer: Text(
        '開発中の確認用です。実際の記録には影響しません。',
        style: theme.textTheme.bodySmall,
      ),
      children: [
        ListTile(
          key: const ValueKey('optionsSampleCreate'),
          leading: const Icon(Icons.science_outlined),
          title: const Text('サンプルデータを作成（過去12か月）'),
          onTap: () => _create(context, ref),
        ),
        ListTile(
          key: const ValueKey('optionsSampleDelete'),
          leading: const Icon(Icons.delete_outline),
          title: const Text('サンプルデータを削除'),
          onTap: () => _remove(context, ref),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      key: 'optionsSampleCreateConfirm',
      title: 'サンプルデータを作成しますか？',
      body: '過去12か月ぶんの記録を作って、アクティビティのグラフを確認できるようにします。'
          'あなたの実際の記録・コイン・ログイン日数は変わりません。',
      action: '作成する',
    );
    if (!ok || !context.mounted) return;

    // The messenger is resolved before the await: the sheet can be dismissed
    // while the write is running, and a defunct context has no messenger.
    final messenger = ScaffoldMessenger.of(context);
    final progress = _showProgress(context, 'サンプルデータを作成しています…');
    int written;
    try {
      written = await ref.read(sampleDataServiceProvider).generate();
    } finally {
      progress();
    }
    messenger.showSnackBar(
      SnackBar(content: Text('サンプルデータを作成しました（$written 件）')),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      key: 'optionsSampleDeleteConfirm',
      title: 'サンプルデータを削除しますか？',
      body: '作成したサンプルの記録だけを消します。あなたの実際の記録は残ります。',
      action: '削除する',
    );
    if (!ok || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final progress = _showProgress(context, 'サンプルデータを削除しています…');
    try {
      await ref.read(sampleDataServiceProvider).delete();
    } finally {
      progress();
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('サンプルデータを削除しました')),
    );
  }

  /// A blocking spinner, and the callback that takes it away again. Twelve
  /// months is a few hundred inserts — long enough that a dead-looking sheet
  /// would read as a broken button.
  VoidCallback _showProgress(BuildContext context, String label) {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        key: const ValueKey('optionsSampleProgress'),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
    var closed = false;
    return () {
      if (closed) return;
      closed = true;
      navigator.pop();
    };
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String key,
    required String title,
    required String body,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: ValueKey(key),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('やめる'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

/// 危険な設定 — the island whose title is painted in the error colour, because
/// everything in it raises what a morning can cost.
class _DangerIsland extends ConsumerWidget {
  const _DangerIsland();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ceiling = ref.watch(capCeilingProvider);

    return SettingsIsland(
      title: '危険な設定',
      titleColor: theme.colorScheme.error,
      children: [
        SettingRow(
          key: const ValueKey('optionsCapCeilingRow'),
          label: '上限金額の最大値',
          value: capCeilingLabel(ceiling),
          subtitle:
              '覚悟の設定で選べる上限金額の天井です。'
              'クレジットカードを人質にしたアラームでは、この金額までが実際に請求されます。',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const CapCeilingScreen()),
          ),
        ),
      ],
    );
  }
}

/// 「10,000 コイン」. Pure.
String capCeilingLabel(int ceiling) => '${thousands(ceiling)} コイン';

/// The ceiling, as one free numeric field.
///
/// Not a list of amounts: a menu of prices reads as a shop, and this is not a
/// shop — it is the user stating, in their own number, how far they are willing
/// to let a morning cost them. So no presets, and **no range on screen**: the
/// clamp exists (`normalizeCapCeiling`) but announcing a maximum would be the
/// same suggestion in smaller print.
///
/// Not a [ChoiceSubScreen] either: that one commits on pop, and raising this
/// needs an answer *before* anything is stored. Lowering is committed on the
/// spot — nothing gets more dangerous by going down.
class CapCeilingScreen extends ConsumerStatefulWidget {
  const CapCeilingScreen({super.key});

  @override
  ConsumerState<CapCeilingScreen> createState() => _CapCeilingScreenState();
}

class _CapCeilingScreenState extends ConsumerState<CapCeilingScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: '${ref.read(capCeilingProvider)}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// What the field currently says, or null when it says nothing usable — which
  /// is the whole of the 決定 button's enabled/disabled rule.
  int? get _typed => int.tryParse(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ceiling = ref.watch(capCeilingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('上限金額の最大値')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  key: const ValueKey('capCeilingInput'),
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // Only to re-run the 決定 button's enabled test; the value
                  // itself is read when 決定 is pressed.
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Text('コイン', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '覚悟の設定で選べる上限金額の天井です。'
            'クレジットカードを人質にしたアラームでは、この金額までが実際に請求されます。'
            'いくらにするかはあなた次第です。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('capCeilingSave'),
            onPressed: _typed == null ? null : () => _save(ceiling),
            child: const Text('決定'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(int current) async {
    final typed = _typed;
    if (typed == null) return;
    // Silent: an out-of-range number is not an error the user has to argue
    // with, it is a number the app quietly brings inside its own bounds and
    // then shows back, which is the only place the bound is ever stated.
    final value = normalizeCapCeiling(typed);
    if (value > current && !await _confirm(context, value)) return;
    await ref.read(optionsProvider.notifier).setCapCeiling(value);
    if (mounted) _controller.text = '$value';
  }

  Future<bool> _confirm(BuildContext context, int choice) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('capCeilingConfirm'),
          title: const Text('本当に上げますか？'),
          content: Text(
            '上限金額の最大値を${capCeilingLabel(choice)}にします。'
            'カードを人質にしたアラームは、寝坊 1 回でこの金額まで請求されることがあります。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('やめる'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('上げる'),
            ),
          ],
        ),
      ) ??
      false;
}
