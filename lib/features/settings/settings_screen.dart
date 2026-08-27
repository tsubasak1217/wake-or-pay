import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import 'theme_shop.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final wallet = ref.watch(walletProvider).valueOrNull ?? const Wallet();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // あなた lives in the profile overlay now — the name, the ID and the
          // cosmetics are one screen, and this one is only the theme.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('テーマ', style: textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'ご褒美トークン 🎁 ${wallet.tokens}。コインでは買えません。',
              style: textTheme.bodySmall,
            ),
          ),
          for (final appTheme in AppThemes.all)
            _ThemeTile(
              appTheme: appTheme,
              selected: appTheme.id == settings.themeId,
              unlocked: settings.unlockedThemeIds.contains(appTheme.id),
              tokens: wallet.tokens,
            ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '広告・スヌーズ・課金による機能解放はありません。'
              '起こすために必要な機能はすべて無料です。',
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({
    required this.appTheme,
    required this.selected,
    required this.unlocked,
    required this.tokens,
  });

  final AppTheme appTheme;
  final bool selected;
  final bool unlocked;
  final int tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final affordable = tokens >= appTheme.price;

    Future<void> unlock() async {
      final ok = await ref.read(themeShopProvider).unlock(appTheme);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('トークンが足りません（${appTheme.price} 必要）')),
        );
      }
    }

    return ListTile(
      onTap: unlocked
          ? () => ref.read(settingsProvider.notifier).selectTheme(appTheme.id)
          : (affordable ? unlock : null),
      leading: CircleAvatar(backgroundColor: appTheme.seed),
      title: Text(appTheme.name),
      subtitle: Text(
        unlocked
            ? appTheme.description
            : '${appTheme.description}（🎁 ${appTheme.price}）',
      ),
      trailing: switch ((unlocked, selected)) {
        (true, true) => const Icon(Icons.check),
        (true, false) => null,
        (false, _) => TextButton(
          onPressed: affordable ? unlock : null,
          child: const Text('交換'),
        ),
      },
    );
  }
}
