import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../data/providers.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';

/// Stand-in for the in-app purchase that does not exist yet.
const devChargeAmount = 1000;

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wallet = ref.watch(walletProvider).valueOrNull ?? const Wallet();
    final history = ref.watch(sessionHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ウォレット')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('🪙 ${wallet.coins}', style: theme.textTheme.displaySmall),
                const Text('アラームコイン（人質）'),
                const SizedBox(height: 16),
                Text(
                  '🎁 ${wallet.tokens}',
                  style: theme.textTheme.displaySmall,
                ),
                const Text('ご褒美トークン（起床成功の報酬）'),
                const SizedBox(height: 8),
                Text('コインとトークンは交換できません。', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => ref
                  .read(walletRepositoryProvider)
                  .update((w) => w.copyWith(coins: w.coins + devChargeAmount)),
              icon: const Icon(Icons.science_outlined),
              label: const Text('開発用チャージ（+1,000コイン）'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '課金は未実装です。このボタンは開発用で、製品版には入りません。',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Divider(height: 32),
          // Settings live on this tab; Home keeps its own shortcut too.
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('設定・テーマ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoute.settings),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('履歴', style: theme.textTheme.titleMedium),
          ),
          history.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
            data: (sessions) => sessions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('まだ記録はありません')),
                  )
                : Column(
                    children: [
                      for (final s in sessions)
                        ListTile(
                          title: Text(formatDateTime(s.firedAt)),
                          subtitle: Text(sessionResultLabel(s.status)),
                          trailing: Text(
                            '−${s.loss}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: s.loss > 0
                                  ? theme.colorScheme.error
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const _ContactEventSection(),
        ],
      ),
    );
  }
}

/// The oversleep contact log. Absent entirely until something has fired, so
/// nobody is shown an empty section about a feature they never set up.
class _ContactEventSection extends ConsumerWidget {
  const _ContactEventSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final events = ref.watch(contactEventsProvider).valueOrNull;
    if (events == null || events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('寝坊時連絡の記録', style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            '実際の送信はまだ実装されていません。ここに残るのは「送るはずだった」記録です。',
            style: theme.textTheme.bodySmall,
          ),
        ),
        for (final event in events)
          ListTile(
            key: ValueKey('contactEvent-${event.id}'),
            leading: Icon(
              contactChannelIcon(event.channel),
              color: theme.colorScheme.error,
            ),
            title: Text('${event.contactName} さんへ'),
            subtitle: Text(
              [
                formatDateTime(event.firedAt),
                contactChannelLabel(event.channel),
                ?event.detail,
              ].join(' ・ '),
            ),
          ),
      ],
    );
  }
}

IconData contactChannelIcon(ContactChannel channel) => switch (channel) {
  ContactChannel.phone => Icons.phone_outlined,
  ContactChannel.email => Icons.mail_outline,
  ContactChannel.log => Icons.receipt_long_outlined,
};
