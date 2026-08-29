import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
