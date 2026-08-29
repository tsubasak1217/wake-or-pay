import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../alarms/widgets/settings_island.dart';
import '../profile/app_header.dart';

/// Stand-in for the prepaid coins that do not exist yet.
const devChargeAmount = 1000;

/// ショップ — the one screen where coins are handed out, and nothing else.
///
/// `PROFILE_TABS_SPEC` §2 calls this 「純粋な購入画面」: it may offer coins, and it
/// may never offer a **feature**. So there is no history here, no settings link
/// and no upsell — the history moved to アクティビティ, the settings to オプション,
/// and every feature in this app is free.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wallet = ref.watch(walletProvider).valueOrNull ?? const Wallet();

    return Scaffold(
      appBar: const AppHeaderBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
            child: Text('ショップ', style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              key: const ValueKey('shopBalance'),
              children: [
                Text('🪙 ${wallet.coins}', style: theme.textTheme.displaySmall),
                const Text('アラームコイン（人質）'),
                const SizedBox(height: 16),
                Text('🎁 ${wallet.tokens}', style: theme.textTheme.displaySmall),
                const Text('ご褒美トークン（起床成功の報酬）'),
                const SizedBox(height: 8),
                Text('コインとトークンは交換できません。', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          SettingsIsland(
            key: const ValueKey('shopCoins'),
            title: 'コインを手に入れる',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: OutlinedButton.icon(
                  key: const ValueKey('shopDevCharge'),
                  onPressed: () => ref
                      .read(walletRepositoryProvider)
                      .update(
                        (w) => w.copyWith(coins: w.coins + devChargeAmount),
                      ),
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('開発用チャージ（+1,000コイン）'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'このボタンは開発用で、製品版には入りません。\n'
                  'コインの入手方法は準備中です。',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
