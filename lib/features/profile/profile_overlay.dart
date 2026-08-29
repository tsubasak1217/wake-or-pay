import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_controller.dart';
import '../../domain/level.dart';
import '../../domain/models.dart';
import '../../domain/profile_catalog.dart';
import '../../services/card_hostage.dart';
import '../../services/mail_settings.dart';
import '../alarms/widgets/settings_island.dart';
import '../widgets/top_sheet.dart';
import 'card_hostage_screen.dart';
import 'discord_link_row.dart';
import 'mail_settings_screen.dart';
import 'user_name_screen.dart';

/// Drops the profile over whatever is on screen, from the top.
///
/// The route, the grab bar and the 閉じる button are [TopSheetOverlay]'s, shared
/// with オプション so the two sheets cannot behave differently.
Future<void> showProfileOverlay(BuildContext context) => showTopSheet(
  context,
  barrierLabel: 'プロフィールを閉じる',
  builder: (_) => const ProfileOverlay(),
);

class ProfileOverlay extends ConsumerWidget {
  const ProfileOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);

    return TopSheetOverlay(
      scaffoldKey: const ValueKey('profileOverlay'),
      handleKey: const ValueKey('profileOverlayHandle'),
      closeKey: const ValueKey('profileOverlayClose'),
      children: [
        _HeaderBlock(profile: profile),
        const SizedBox(height: 20),
        _ProfileSettingsIsland(profile: profile),
        _CollectionIsland(profile: profile),
        SettingsIsland(
          title: 'アクティビティ',
          children: [
            ListTile(
              key: const ValueKey('profileActivityPlaceholder'),
              title: const Text('近日追加：寝坊や起床までの時間をグラフで表示します'),
              subtitle: Text(
                'いまは記録だけを貯めています。',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = ProfileCatalog.iconById(profile.iconId);
    final level = levelForXp(profile.xp);

    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Text(icon.emoji, style: const TextStyle(fontSize: 34)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lv$level ${profile.userName.isEmpty ? '未設定' : profile.userName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '経験値 ${profile.xp} / 次のLvまで ${xpToNext(profile.xp)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: levelProgress(profile.xp),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSettingsIsland extends ConsumerWidget {
  const _ProfileSettingsIsland({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mail = ref.watch(mailSettingsProvider);
    final card = ref.watch(cardHostageProvider).card;
    return SettingsIsland(
      title: 'プロフィール設定',
      children: [
        SettingRow(
          key: const ValueKey('profileUserNameRow'),
          label: 'あなたの名前',
          value: profile.userName.isEmpty ? '未設定' : profile.userName,
          onTap: () => pushUserNameSubScreen(context),
        ),
        // 手入力の行は 3 つとも無くなった（段階F）。
        // 「Discord ユーザーID」は開発者モードを出させて 18 桁を貼らせる行で、
        // しかも貼られた数字が誰のものかは誰にも分からなかった。
        // 「連携サーバーURL」はデプロイの都合で、ユーザーの持ち物ではない
        // （いまは kDiscordExchangeEndpoint というビルド時定数）。
        // 残ったのは、押せば全部入る 1 つのボタンだけ。
        const DiscordLinkRow(),
        // 設定済み only when the app could actually send: a half-filled account
        // is 未設定 as far as every other screen is concerned, so this row must
        // not be the one place that calls it done.
        SettingRow(
          key: const ValueKey('profileMailRow'),
          leading: const Icon(Icons.mail_outline),
          label: 'メール送信設定',
          value: mail.isConfigured ? '設定済み' : '未設定',
          subtitle: mail.isConfigured
              ? '${mail.fromAddress} から送ります'
              : 'あなたのアドレスから寝坊を知らせられるようにします。',
          onTap: () => pushMailSettingsScreen(context),
        ),
        // 罰としての請求（`docs/BILLING_API.md`）。機能を売る行ではない：
        // 押しても何も解放されず、押さなくても全機能が使える。
        SettingRow(
          key: const ValueKey('profileCardHostageRow'),
          leading: const Icon(Icons.credit_card),
          label: 'クレジットカードを人質にする',
          value: card == null ? 'なし' : card.label,
          subtitle: card == null
              ? '寝坊で確定した金額を、あなたのカードに請求できるようにします。'
              : '有効期限 ${card.expiry}',
          onTap: () => pushCardHostageScreen(context),
        ),
        // 「アプリの更新」 used to sit here. It is not プロフィール — it is about
        // the app, not about who you are — so it moved to オプション › アプリ
        // (`optionsUpdateRow`).
      ],
    );
  }
}

/// The three pickers. Every entry is owned today, but the owned set is what
/// decides — so the day something has to be earned, only the grant is new.
class _CollectionIsland extends ConsumerWidget {
  const _CollectionIsland({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(profileProvider.notifier);
    return SettingsIsland(
      title: 'コレクション',
      children: [
        _PickerRow(
          label: 'アイコン',
          children: [
            for (final icon in ProfileCatalog.icons)
              _Swatch(
                key: ValueKey('collectionIcon-${icon.id}'),
                label: icon.label,
                selected: icon.id == profile.iconId,
                owned: profile.ownedIconIds.contains(icon.id),
                onTap: () => controller.selectIcon(icon.id),
                child: Text(icon.emoji, style: const TextStyle(fontSize: 26)),
              ),
          ],
        ),
        _PickerRow(
          label: '名前の背景',
          children: [
            for (final plate in ProfileCatalog.plateBackgrounds)
              _Swatch(
                key: ValueKey('collectionPlate-${plate.id}'),
                label: plate.label,
                selected: plate.id == profile.plateBackgroundId,
                owned: profile.ownedPlateBackgroundIds.contains(plate.id),
                onTap: () => controller.selectPlateBackground(plate.id),
                child: Container(
                  width: 44,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: plate.colors.length == 1 ? plate.colors.first : null,
                    gradient: plate.colors.length > 1
                        ? LinearGradient(colors: plate.colors)
                        : null,
                  ),
                ),
              ),
          ],
        ),
        _PickerRow(
          label: 'フレーム',
          children: [
            for (final frame in ProfileCatalog.frames)
              _Swatch(
                key: ValueKey('collectionFrame-${frame.id}'),
                label: frame.label,
                selected: frame.id == profile.frameId,
                owned: profile.ownedFrameIds.contains(frame.id),
                onTap: () => controller.selectFrame(frame.id),
                child: Container(
                  width: 44,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Theme.of(context).colorScheme.surface,
                    border: frame.width > 0
                        ? Border.all(color: frame.color, width: frame.width)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: children,
          ),
        ),
      ],
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.label,
    required this.selected,
    required this.owned,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;

  /// Nothing is unowned yet; when something is, it greys out and stops
  /// responding rather than disappearing from the row.
  final bool owned;

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: owned ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: owned ? 1 : 0.35,
          child: Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 30, child: Center(child: child)),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
