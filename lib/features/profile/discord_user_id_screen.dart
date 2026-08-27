import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_controller.dart';

/// The Discord user ID used to mention the user in a shared oversleep post.
///
/// Digits only at the keyboard *and* on commit: people paste the mention
/// (`<@123…>`) far more often than the bare ID, so the field refuses anything
/// else rather than storing something the webhook cannot use.
class DiscordUserIdSubScreen extends ConsumerStatefulWidget {
  const DiscordUserIdSubScreen({super.key});

  @override
  ConsumerState<DiscordUserIdSubScreen> createState() =>
      _DiscordUserIdSubScreenState();
}

class _DiscordUserIdSubScreenState
    extends ConsumerState<DiscordUserIdSubScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(profileProvider).discordUserId,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final id = _controller.text.trim();
    if (id == ref.read(profileProvider).discordUserId) return;
    ref.read(profileProvider.notifier).setDiscordUserId(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _commit();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Discord ユーザーID')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextField(
              key: const ValueKey('discordUserIdField'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.of(context).maybePop(),
              decoration: const InputDecoration(
                labelText: 'ユーザーID（数字のみ）',
                hintText: '例：123456789012345678',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '寝坊を共有するときに、あなたをメンションするために使います。'
              '未設定なら、代わりにあなたの名前が本文に入ります。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Discord の設定で開発者モードを有効にすると、'
              '自分のアイコンを右クリック（長押し）して「ユーザーIDをコピー」できます。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
