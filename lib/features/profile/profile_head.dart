import 'package:flutter/material.dart';

import '../../domain/level.dart';
import '../../domain/models.dart';
import '../../domain/profile_catalog.dart';

/// アイコン → 称号 → ネームプレート → 経験値ゲージ, in that order.
///
/// One widget and not two, because the プロフィール編集画面 previews exactly this
/// block: a preview built from a second implementation would eventually show
/// something the profile does not.
class ProfileHead extends StatelessWidget {
  const ProfileHead({
    super.key,
    required this.profile,
    required this.keyPrefix,
    this.onEdit,
  });

  /// What to paint. The editor hands in its **draft**, not the stored profile.
  final Profile profile;

  /// Namespaces the keys of the parts, so the editor's live preview and the
  /// profile behind it are two different widgets to a finder rather than a
  /// duplicate of one.
  final String keyPrefix;

  /// The pencil beside the name plate. Null draws no pencil — the preview
  /// inside the editor has nowhere left to go.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = ProfileCatalog.iconById(profile.iconId);
    final frame = ProfileCatalog.frameById(profile.frameId);
    final plate = ProfileCatalog.plateBackgroundById(profile.plateBackgroundId);
    final level = levelForXp(profile.xp);

    return Column(
      children: [
        // The frame is a ring *around* the avatar rather than a border on it,
        // so a thick frame grows outwards and never eats the icon.
        Container(
          key: ValueKey('${keyPrefix}Avatar'),
          padding: EdgeInsets.all(frame.width > 0 ? frame.width + 3 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: frame.width > 0
                ? Border.all(color: frame.color, width: frame.width)
                : null,
          ),
          child: CircleAvatar(
            radius: 44,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Text(icon.emoji, style: const TextStyle(fontSize: 44)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          profile.title,
          key: ValueKey('${keyPrefix}Title'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The pencil is outside the plate but inside the row, so the plate
            // stays centred under the avatar with the button hanging off it.
            if (onEdit != null) const SizedBox(width: 48),
            Flexible(
              child: Container(
                key: ValueKey('${keyPrefix}NamePlate'),
                constraints: const BoxConstraints(minWidth: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: plate.colors.length == 1 ? plate.colors.first : null,
                  gradient: plate.colors.length > 1
                      ? LinearGradient(colors: plate.colors)
                      : null,
                ),
                child: Text(
                  profile.userName.isEmpty ? '未設定' : profile.userName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // The plate is painted in its own colours, so the text on it
                  // comes from the plate and not from the app theme.
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (onEdit != null)
              SizedBox(
                width: 48,
                child: IconButton(
                  key: ValueKey('${keyPrefix}EditButton'),
                  tooltip: 'プロフィールを編集',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // ランクはゲージの内部. A level printed beside the bar would be one more
        // number on a screen that already has several; inside it, the bar *is*
        // the level.
        Stack(
          key: ValueKey('${keyPrefix}Gauge'),
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: LinearProgressIndicator(
                value: levelProgress(profile.xp),
                minHeight: 18,
              ),
            ),
            Text(
              'Lv $level',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '経験値 ${profile.xp} / 次のLvまで ${xpToNext(profile.xp)}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
