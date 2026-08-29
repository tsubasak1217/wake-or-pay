import 'package:flutter/material.dart';

import 'discord_link_row.dart';

/// Where Discord is actually linked and unlinked.
///
/// 連携情報 is three rows that each say one word — 未連携 or 連携済み — and nothing
/// else. Everything that used to hang off the Discord row in that island (the
/// explanation of what the browser is about to do, the 「連携を解除」 button, and
/// the flow status that has to survive the app going behind a browser) lives
/// here, one tap away, where it has room to be read.
class DiscordLinkScreen extends StatelessWidget {
  const DiscordLinkScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Discord')),
    body: ListView(
      key: const ValueKey('discordLinkScreen'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: const [DiscordLinkRow()],
    ),
  );
}

/// Opens the screen over whatever asked for it — the 連携情報 row today.
Future<void> pushDiscordLinkScreen(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const DiscordLinkScreen()));
