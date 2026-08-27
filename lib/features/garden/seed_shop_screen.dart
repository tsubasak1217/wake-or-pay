import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import 'garden_board.dart';
import 'item_source.dart';

/// 種屋. A placeholder for acquisition: the whole catalogue, priced in reward
/// tokens earned by waking up.
///
/// Everything here goes through [GardenItemSource]. When acquisition becomes a
/// game — growing seeds, trading, seasonal finds — that class is what changes;
/// this screen either follows it or is replaced outright. Coins are not shown
/// and cannot be spent, and nothing is unlocked by watching or paying.
class SeedShopScreen extends ConsumerWidget {
  const SeedShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wallet = ref.watch(walletProvider).valueOrNull ?? const Wallet();
    final source = ref.watch(gardenItemSourceProvider);
    final offers = source.offers();

    return Scaffold(
      appBar: AppBar(title: const Text('種屋')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '🎁 ${wallet.tokens}',
              key: const ValueKey('tokenBalance'),
              style: theme.textTheme.headlineMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'ご褒美トークン（起床成功の報酬）で交換できます。'
              'アラームコインは使えません。',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Divider(height: 1),
          for (final def in offers)
            _OfferTile(
              def: def,
              affordable: source.canAcquire(def, wallet),
              onExchange: () async {
                final ok = await source.acquire(def);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? '${def.name}を手に入れました。模様替えから置けます。'
                          : 'トークンが足りません（🎁 ${def.costTokens} 必要）',
                    ),
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '入手方法は仮です。今後、起床の積み重ねで手に入る仕組みに置き換えます。',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.def,
    required this.affordable,
    required this.onExchange,
  });

  final GardenItemDef def;
  final bool affordable;
  final VoidCallback onExchange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('offer-${def.id}'),
      leading: SizedBox(
        width: 44,
        height: 44,
        child: GardenItemTile(def: def, compact: true),
      ),
      title: Text(def.name),
      subtitle: Text(
        '${def.category.label}'
        '${def.growable ? '・連続起床で育つ' : ''}'
        '・${def.width}×${def.height}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🎁 ${def.costTokens}', style: theme.textTheme.labelLarge),
          const SizedBox(width: 8),
          TextButton(
            onPressed: affordable ? onExchange : null,
            child: const Text('交換'),
          ),
        ],
      ),
    );
  }
}
