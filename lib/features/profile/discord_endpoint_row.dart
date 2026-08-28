import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/discord_exchange.dart';
import '../alarms/edit_sub_screens.dart';
import '../alarms/widgets/settings_island.dart';
import 'discord_endpoint_screen.dart';

/// 連携サーバーURL, the last row of the Discord group.
///
/// Deliberately the quietest row on the screen — it is a deployment detail,
/// not something anybody has to touch to use the app. But it is **visible**,
/// because the 共有先 screen tells the user by name to come here when
/// 「チャンネルを連携」 has nowhere to go, and a screen that names a row the user
/// cannot find is worse than no row at all.
///
/// See [DiscordEndpointSubScreen] for why this is a setting and not a
/// constant.
class DiscordEndpointRow extends ConsumerWidget {
  const DiscordEndpointRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endpoint = ref.watch(discordExchangeEndpointProvider);
    return SettingRow(
      key: const ValueKey('profileDiscordEndpointRow'),
      label: '連携サーバーURL',
      // The host, not the whole URL: a workers.dev URL does not fit on a phone
      // row, and the host is the part that says *which* Worker this is.
      value: endpoint.isEmpty
          ? '未設定'
          : (Uri.tryParse(endpoint)?.host.isNotEmpty ?? false)
          ? Uri.parse(endpoint).host
          : '設定済み',
      subtitle: '「チャンネルを連携」で使う中継サーバー。空でも他の機能は動きます。',
      onTap: () =>
          pushEditorSubScreen(context, const DiscordEndpointSubScreen()),
    );
  }
}
