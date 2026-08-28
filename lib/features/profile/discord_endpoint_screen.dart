import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/discord_exchange.dart';

/// 連携サーバーURL — where the deployed Cloudflare Worker lives.
///
/// This is here rather than baked into the build for one reason: the Worker
/// holds a **client secret**, and a secret is only a secret while it belongs
/// to one person. Shipping one URL in the APK would spend the builder's secret
/// on every stranger's authorization. So whoever deploys their own Worker
/// pastes its URL here, and nobody has to rebuild the app to do it.
///
/// Empty is the normal state, and it is not an error: 「Discord で連携」 and
/// every hand-registered webhook work without a Worker. Only
/// 「チャンネルを連携」 needs one.
class DiscordEndpointSubScreen extends ConsumerStatefulWidget {
  const DiscordEndpointSubScreen({super.key});

  @override
  ConsumerState<DiscordEndpointSubScreen> createState() =>
      _DiscordEndpointSubScreenState();
}

class _DiscordEndpointSubScreenState
    extends ConsumerState<DiscordEndpointSubScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(discordExchangeEndpointProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final typed = _controller.text.trim();
    if (typed == ref.read(discordExchangeEndpointProvider)) return;
    ref.read(discordExchangeEndpointProvider.notifier).set(typed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Live, so the warning below appears while typing rather than after the
    // user has already left and come back.
    final typed = _controller.text.trim();
    final usable = typed.isEmpty || isDiscordExchangeEndpoint(typed);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _commit();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('連携サーバーURL')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextField(
              key: const ValueKey('discordEndpointField'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Worker の URL',
                hintText: 'https://wake-or-pay-discord.….workers.dev',
                errorText: usable
                    ? null
                    : 'https:// で始まる URL を入れてください。'
                          '認可コードを送る先なので、暗号化されていない通信では使えません。',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '「チャンネルを連携（Discord で選ぶ）」だけがこのサーバーを使います。'
              '「Discord で連携」（上のユーザーID）と、手で登録した Webhook は'
              'サーバーなしで動くので、ここが空でも困りません。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Discord は「認可コードをトークンに交換する」ときにクライアント'
              'シークレットを要求します。APK に埋めたシークレットは誰でも取り出せて'
              'しまうので、そこだけを小さなサーバー（Cloudflare Worker）に置いています。'
              '立て方はリポジトリの worker/README.md にあります'
              '（wrangler login → wrangler secret put → wrangler deploy の3手です）。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              '末尾の /discord/exchange は付けても付けなくても構いません。'
              '空にすると既定に戻ります。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
