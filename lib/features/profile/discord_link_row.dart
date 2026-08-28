import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_controller.dart';
import '../../services/discord_oauth.dart';

/// 「Discord で連携」, right under the Discord ユーザーID row.
///
/// The row above takes an 18-digit snowflake by hand, and getting one requires
/// turning on Discord's developer mode first — which is where most people stop.
/// This is the same field filled in by logging in, and it is the only way the
/// name beside it can be shown at all: an ID typed by hand is just digits, and
/// nothing can say whose they are.
///
/// The access token that makes this work is spent once, on `/users/@me`, and
/// is never written down. See [DiscordOAuthService].
class DiscordLinkRow extends ConsumerStatefulWidget {
  const DiscordLinkRow({super.key});

  @override
  ConsumerState<DiscordLinkRow> createState() => _DiscordLinkRowState();
}

class _DiscordLinkRowState extends ConsumerState<DiscordLinkRow> {
  /// True while the browser is open. Guards a second tap: two flows in the air
  /// share one callback scheme, and the second would be answered by the first
  /// one's redirect.
  bool _busy = false;

  Future<void> _link() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Taken before the await: the overlay can be dismissed while the browser
    // is up, and this context goes with it.
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(discordOAuthServiceProvider).link();
    final identity = result.identity;
    if (result.ok && identity != null) {
      await ref
          .read(profileProvider.notifier)
          .linkDiscordAccount(
            id: identity.id,
            username: identity.displayName,
            avatar: identity.avatar,
          );
    }
    if (mounted) setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(result.label)));
  }

  Future<void> _unlink() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(profileProvider.notifier).unlinkDiscordAccount();
    messenger.showSnackBar(const SnackBar(content: Text('連携を解除しました')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);

    if (profile.discordLinked) {
      return ListTile(
        key: const ValueKey('profileDiscordLinkedRow'),
        leading: const Icon(Icons.check_circle_outline),
        title: Text('連携済み：@${profile.discordUsername}'),
        subtitle: Text(
          '寝坊の共有であなたをメンションします。',
          style: theme.textTheme.bodySmall,
        ),
        trailing: TextButton(
          key: const ValueKey('profileDiscordUnlink'),
          onPressed: _unlink,
          child: const Text('連携を解除'),
        ),
      );
    }

    return ListTile(
      key: const ValueKey('profileDiscordLinkRow'),
      leading: const Icon(Icons.link),
      title: const Text('Discord で連携'),
      subtitle: Text(
        'ブラウザで Discord にログインすると、ユーザーIDが自動で入ります。'
        '開発者モードを出す必要はありません。',
        style: theme.textTheme.bodySmall,
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.open_in_new),
      onTap: _busy ? null : _link,
    );
  }
}
