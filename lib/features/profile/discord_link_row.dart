import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_controller.dart';
import '../../services/discord_link_log.dart';
import '../../services/discord_oauth.dart';
import '../alarms/edit_sub_screens.dart';
import 'discord_flow_status_view.dart';
import 'discord_log_screen.dart';

/// 「Discord で連携」 and everything that hangs off it.
///
/// This is now the **only** way a Discord user ID gets into the app. The
/// hand-typed 「Discord ユーザーID」 row is gone: it asked the user to turn on
/// Discord's developer mode, long-press their own avatar and paste 18 digits
/// that nothing could verify — and an ID typed that way could never carry the
/// name beside it, because nothing knew whose it was.
///
/// Authorisation happens **in the Discord app** when it is installed, which is
/// where the user is already signed in, so approving is one tap and the app
/// comes straight back. A browser is the fallback, not the plan.
///
/// The access token that makes this work is spent once, on `/users/@me`, and
/// is never written down. See [DiscordOAuthService].
class DiscordLinkRow extends ConsumerStatefulWidget {
  const DiscordLinkRow({super.key});

  @override
  ConsumerState<DiscordLinkRow> createState() => _DiscordLinkRowState();
}

class _DiscordLinkRowState extends ConsumerState<DiscordLinkRow> {
  @override
  void initState() {
    super.initState();
    // The status is app-wide, and it has to be: the callback can arrive with
    // this screen closed, and the answer must survive until somebody looks.
    // But it belongs to **one attempt**, so opening this screen fresh clears
    // whatever the last one left — otherwise the 共有先 screen greets a user
    // with 「連携済み：@…」 from a flow that happened in the profile an hour ago.
    // A flow still in the air is left alone; only a finished one is cleared.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(discordFlowStatusProvider).busy) {
        ref.read(discordFlowStatusProvider.notifier).reset();
      }
    });
  }

  Future<void> _link() async {
    final service = ref.read(discordOAuthServiceProvider);
    final result = await service.link();
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
    // No SnackBar. The whole failure this rework fixes was a SnackBar shown
    // while the app was behind a browser: it fired, timed out and was gone
    // before the user ever looked at this screen again. The outcome lives in
    // the status area instead, which is still there when they come back.
  }

  Future<void> _unlink() async {
    await ref.read(profileProvider.notifier).unlinkDiscordAccount();
    ref.read(discordFlowStatusProvider.notifier).reset();
    ref.read(discordLinkLogProvider.notifier).add('連携を解除しました');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);
    final status = ref.watch(discordFlowStatusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profile.discordLinked)
          ListTile(
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
          )
        else
          ListTile(
            key: const ValueKey('profileDiscordLinkRow'),
            leading: const Icon(Icons.link),
            title: const Text('Discord で連携'),
            subtitle: Text(
              'Discord アプリが入っていればそちらが開き、「認証」を押すだけで戻ってきます。'
              '入っていなければブラウザで開きます。ユーザーIDと表示名は自動で入ります。',
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: status.busy ? null : _link,
          ),
        DiscordFlowStatusView(
          onCancel: () => ref.read(discordOAuthServiceProvider).cancel(),
        ),
        ListTile(
          key: const ValueKey('profileDiscordLogRow'),
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('連携ログ'),
          subtitle: Text(
            'うまくいかなかったときに、何が起きたかを時刻つきで見られます。',
            style: theme.textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              pushEditorSubScreen(context, const DiscordLogSubScreen()),
        ),
      ],
    );
  }
}
