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
    this.backgroundId,
    this.onNameTap,
    this.nameTapKey,
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

  /// Overrides which 背景 is painted. Null means [profile]'s own — the editor
  /// hands this in only while a category is being previewed against a draft
  /// that has not been written yet.
  final String? backgroundId;

  /// Tapping the name plate. Null leaves it inert, which is what the profile
  /// itself wants: there the name is changed behind the pencil.
  final VoidCallback? onNameTap;
  final Key? nameTapKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = ProfileCatalog.iconById(profile.iconId);
    final frame = ProfileCatalog.frameById(profile.frameId);
    final plate = ProfileCatalog.plateBackgroundById(profile.plateBackgroundId);
    final background = ProfileCatalog.backgroundById(
      backgroundId ?? profile.backgroundId,
    );
    final level = levelForXp(profile.xp);

    final column = Column(
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
              child: GestureDetector(
                key: nameTapKey,
                onTap: onNameTap,
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
                    // The plate is painted in its own colours, so the text on
                    // it comes from the plate and not from the app theme.
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
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
                // Orange in every theme, never the scheme's primary: the head
                // is painted over a 背景 the user picks, and the purple-ish
                // ones left a purple bar on a purple card with nothing to see.
                // The track is the same orange at a quarter strength, so the
                // filled part still reads as a fraction of something.
                color: gaugeColor,
                backgroundColor: gaugeTrackColor,
              ),
            ),
            // White, bold, shadowed *and* outlined: the label sits on the bar
            // itself, so it crosses both the filled orange and the track, and
            // one colour alone cannot stay legible over both.
            OutlinedText(
              'Lv $level',
              style: (theme.textTheme.labelMedium ?? const TextStyle())
                  .copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
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

    // 背景 is behind the *whole* head — the icon, the 称号, the plate and the
    // gauge — and not a second plate behind the name. 「なし」 paints nothing,
    // so the default head is byte-for-byte what it was before 背景 existed.
    return Container(
      key: ValueKey('${keyPrefix}Background'),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: background.colors.length == 1 ? background.colors.first : null,
        gradient: background.colors.length > 1
            ? LinearGradient(
                colors: background.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: background.pattern == BackgroundPattern.none
          ? column
          : CustomPaint(
              painter: BackgroundPatternPainter(background.pattern),
              child: column,
            ),
    );
  }
}

/// The dots and stripes a 背景 can carry. Placeholder art: a few shapes in a
/// low-contrast white, drawn behind the head rather than over it.
class BackgroundPatternPainter extends CustomPainter {
  const BackgroundPatternPainter(this.pattern);

  final BackgroundPattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x22FFFFFF);
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
    );

    switch (pattern) {
      case BackgroundPattern.none:
        return;
      case BackgroundPattern.dots:
        for (var y = 10.0; y < size.height; y += 24) {
          for (var x = 10.0; x < size.width; x += 24) {
            canvas.drawCircle(Offset(x, y), 2.5, paint);
          }
        }
      case BackgroundPattern.stripes:
        paint.strokeWidth = 6;
        for (var x = -size.height; x < size.width; x += 22) {
          canvas.drawLine(
            Offset(x, size.height),
            Offset(x + size.height, 0),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(BackgroundPatternPainter old) => old.pattern != pattern;
}

/// The 経験値ゲージ's two colours, fixed rather than taken from the scheme —
/// see the note at the bar itself.
const gaugeColor = Color(0xFFFF9800);
const gaugeTrackColor = Color(0x40FF9800);

/// [text] drawn twice: a thin dark stroke underneath, the filled glyphs on
/// top. The outline is what keeps a white label readable where it crosses the
/// pale part of a gauge, which a shadow alone does not manage.
///
/// The two layers are one [Stack] rather than one [Text] with two styles
/// because a stroke and a fill cannot both be a `foreground` of the same span.
class OutlinedText extends StatelessWidget {
  const OutlinedText(this.text, {super.key, required this.style, this.stroke});

  final String text;

  /// The filled style. The outline copies it and swaps the paint.
  final TextStyle style;

  /// The outline colour. Defaults to black — the point is contrast.
  final Color? stroke;

  static const strokeWidth = 2.0;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Text(
        text,
        style: style.copyWith(
          // A foreground paint replaces `color`, so the stroke layer must not
          // carry one; the shadows stay, because they are drawn behind both.
          color: null,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeJoin = StrokeJoin.round
            ..color = stroke ?? Colors.black,
        ),
      ),
      Text(text, style: style),
    ],
  );
}
