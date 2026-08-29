import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/profile_controller.dart';
import '../../app/router.dart';
import '../../data/providers.dart';
import '../../domain/level.dart';
import '../../domain/models.dart';
import '../../domain/profile_catalog.dart';
import '../options/options_overlay.dart';
import 'profile_overlay.dart';

/// The bar every tab wears: who you are on the left, what you own on the right.
///
/// Only the three tabs get it. A ringing alarm, a result and the editors are
/// full-screen routes on purpose, and a header there would offer a way out of a
/// screen that must not have one.
class AppHeaderBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeaderBar({super.key});

  static const _height = 72.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);
    final wallet = ref.watch(walletProvider).valueOrNull ?? const Wallet();

    return AppBar(
      key: const ValueKey('appHeader'),
      toolbarHeight: _height,
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        children: [
          _Avatar(profile: profile),
          const SizedBox(width: 10),
          // Flexible, so a long name gives way to the balances instead of
          // overflowing a narrow screen.
          Flexible(child: _NamePlate(profile: profile)),
          const SizedBox(width: 8),
          _Balance(
            valueKey: 'appHeaderTokens',
            emoji: '🎁',
            amount: wallet.tokens,
          ),
          const SizedBox(width: 10),
          _Balance(
            valueKey: 'appHeaderCoins',
            emoji: '🪙',
            amount: wallet.coins,
          ),
          // The charge lives on the wallet tab; this is only the way to it.
          IconButton(
            key: const ValueKey('appHeaderCharge'),
            tooltip: 'コインをチャージ',
            visualDensity: VisualDensity.compact,
            onPressed: () => context.go(AppRoute.wallet),
            icon: Icon(Icons.add_circle_outline, color: theme.hintColor),
          ),
          // オプション: the app's own settings, opposite the avatar that opens
          // the user's.
          IconButton(
            key: const ValueKey('appHeaderOptions'),
            tooltip: 'オプション',
            visualDensity: VisualDensity.compact,
            onPressed: () => showOptionsOverlay(context),
            icon: Icon(Icons.settings_outlined, color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final icon = ProfileCatalog.iconById(profile.iconId);
    return InkWell(
      key: const ValueKey('appHeaderAvatar'),
      customBorder: const CircleBorder(),
      onTap: () => showProfileOverlay(context),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(icon.emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

/// Lv, name and the XP bar, painted on the chosen plate inside the chosen
/// frame.
class _NamePlate extends StatelessWidget {
  const _NamePlate({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final plate = ProfileCatalog.plateBackgroundById(profile.plateBackgroundId);
    final frame = ProfileCatalog.frameById(profile.frameId);
    final level = levelForXp(profile.xp);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: plate.colors.length == 1 ? plate.colors.first : null,
        gradient: plate.colors.length > 1
            ? LinearGradient(colors: plate.colors)
            : null,
        border: frame.width > 0
            ? Border.all(color: frame.color, width: frame.width)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lv$level ${profile.userName.isEmpty ? '未設定' : profile.userName}',
            key: const ValueKey('appHeaderName'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // The plate is painted in its own colours, so the text on it comes
            // from the plate rather than from the app theme — a light theme
            // would otherwise write black on a dark plate.
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: levelProgress(profile.xp),
              minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({
    required this.valueKey,
    required this.emoji,
    required this.amount,
  });

  final String valueKey;
  final String emoji;
  final int amount;

  @override
  Widget build(BuildContext context) => Row(
    key: ValueKey(valueKey),
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 3),
      Text('$amount', style: Theme.of(context).textTheme.labelLarge),
    ],
  );
}
