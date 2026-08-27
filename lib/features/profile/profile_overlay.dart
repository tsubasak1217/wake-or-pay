import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_controller.dart';
import '../../domain/level.dart';
import '../../domain/models.dart';
import '../../domain/profile_catalog.dart';
import '../alarms/edit_sub_screens.dart';
import '../alarms/widgets/settings_island.dart';
import 'discord_user_id_screen.dart';
import 'user_name_screen.dart';

/// Drops the profile over whatever is on screen, from the top.
///
/// On the root navigator and non-opaque, so the tab underneath keeps painting
/// and the bottom bar stays where it was — this covers the app, it does not
/// navigate away from it.
Future<void> showProfileOverlay(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        barrierLabel: 'プロフィールを閉じる',
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ProfileOverlay(),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) => SlideTransition(
          position: Tween(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );

/// How fast a downward flick has to be before it counts as "put it away".
/// Below this the sheet stays: scrolling the collection rows must not dismiss.
const _dismissVelocity = 300.0;

class ProfileOverlay extends ConsumerWidget {
  const ProfileOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      key: const ValueKey('profileOverlay'),
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // Only vertical: a horizontal drag belongs to the pickers inside.
        // The list below wins the arena wherever it can actually scroll, so
        // this catches the drag on the parts of the sheet that do not — the
        // grab bar above all.
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > _dismissVelocity) {
            Navigator.of(context).maybePop();
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Material(
              color: theme.colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const _GrabBar(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                    ),
                  ),
                  // Outside the list on purpose: the way out must not be
                  // something you have to scroll to find.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: FilledButton.tonal(
                      key: const ValueKey('profileOverlayClose'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('閉じる'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar you pull down on. It scrolls nothing, so the drag reaches the
/// detector above instead of the list.
class _GrabBar extends StatelessWidget {
  const _GrabBar();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('profileOverlayHandle'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 10),
    color: Colors.transparent,
    child: Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
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

class _ProfileSettingsIsland extends StatelessWidget {
  const _ProfileSettingsIsland({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) => SettingsIsland(
    title: 'プロフィール設定',
    children: [
      SettingRow(
        key: const ValueKey('profileUserNameRow'),
        label: 'あなたの名前',
        value: profile.userName.isEmpty ? '未設定' : profile.userName,
        onTap: () => pushUserNameSubScreen(context),
      ),
      SettingRow(
        key: const ValueKey('profileDiscordIdRow'),
        label: 'Discord ユーザーID',
        value: profile.discordUserId.isEmpty ? '未設定' : profile.discordUserId,
        onTap: () =>
            pushEditorSubScreen(context, const DiscordUserIdSubScreen()),
      ),
      // Deliberately dead: the SMTP settings behind it land in the next stage,
      // and a row that opens an empty screen would be worse than one that says
      // so.
      const SettingRow(
        key: ValueKey('profileMailRow'),
        label: 'メール送信設定',
        value: '準備中',
        subtitle: 'あとの段階で、あなたのアドレスから寝坊を知らせられるようにします。',
      ),
    ],
  );
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
