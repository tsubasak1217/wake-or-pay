import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../services/app_update.dart';
import '../../services/options.dart';
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
        const SettingsIsland(title: 'アプリ', children: [_UpdateRow()]),
        const _DangerIsland(),
      ],
    );
  }
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

/// The four ceilings, as a radio list.
///
/// Not a [ChoiceSubScreen]: that one commits on pop, and raising this needs an
/// answer *before* anything is stored. Lowering is committed on the spot —
/// nothing gets more dangerous by going down.
class CapCeilingScreen extends ConsumerWidget {
  const CapCeilingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ceiling = ref.watch(capCeilingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('上限金額の最大値')),
      body: ListView(
        children: [
          for (final choice in capCeilingChoices)
            ListTile(
              key: ValueKey('capCeilingOption-$choice'),
              title: Text(capCeilingLabel(choice)),
              trailing: choice == ceiling ? const Icon(Icons.check) : null,
              onTap: () => _choose(context, ref, choice, ceiling),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '覚悟の設定の「上限金額」は、ここで選んだ金額までしか設定できません。'
              'すでに保存したアラームは、この値を下げても勝手には下がりません。',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    int choice,
    int current,
  ) async {
    if (choice > current && !await _confirm(context, choice)) return;
    await ref.read(optionsProvider.notifier).setCapCeiling(choice);
    if (context.mounted) Navigator.of(context).maybePop();
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
