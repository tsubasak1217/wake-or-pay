import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/discord_link_log.dart';

/// 連携ログ — the last [kDiscordLogLength] things a Discord flow did.
///
/// This screen is a **debugging affordance for the user**, and it is here
/// because the last failure had none: the whole flow happened in another app,
/// and when it did not work there was no sentence anywhere to report. Now
/// every phase change leaves a timestamped line, so 「連携できません」 can become
/// 「03:28:41 承認を待っています… のまま 5 分」, which says what to fix.
///
/// Nothing here is written to storage and **no line contains a token**: the
/// log records that a token arrived, never its value. It is emptied by
/// restarting the app, which is the right lifetime for a diagnostic about the
/// attempt you just made.
class DiscordLogSubScreen extends ConsumerWidget {
  const DiscordLogSubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(discordLinkLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('連携ログ'),
        actions: [
          TextButton(
            key: const ValueKey('discordLogClear'),
            onPressed: entries.isEmpty
                ? null
                : () => ref.read(discordLinkLogProvider.notifier).clear(),
            child: const Text('消す'),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'まだ記録がありません。\n'
                  '「Discord で連携」や「チャンネルを連携」を押すと、'
                  'ここに何が起きたかが時刻つきで残ります。',
                  key: const ValueKey('discordLogEmpty'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final entry = entries[i];
                return ListTile(
                  key: ValueKey('discordLogEntry-$i'),
                  dense: true,
                  // The clock leads: the only thing anybody compares a line
                  // against is when they pressed the button.
                  leading: Text(
                    entry.clock,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    entry.message,
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              },
            ),
    );
  }
}
