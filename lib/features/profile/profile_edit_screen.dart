import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_controller.dart';
import '../../domain/models.dart';
import '../../domain/profile_catalog.dart';
import '../../domain/title_catalog.dart';
import 'profile_head.dart';

/// The seven drawers of the collection, in the order the sketch puts them:
/// four cosmetics on the first row, the three 称号 slots on the second.
enum _EditCategory {
  icon('icon', 'アイコン'),
  frame('frame', 'フレーム'),
  plate('plate', 'プレート'),
  background('background', '背景'),
  titleA('titleA', '称号A'),
  titleB('titleB', '称号B'),
  titleC('titleC', '称号C');

  const _EditCategory(this.slug, this.label);

  /// The half of the chip's key that names it: `editCategory-background`.
  final String slug;
  final String label;
}

/// プロフィール編集 — the one place a name and a set of cosmetics are chosen.
///
/// Three fixed bands, top to bottom: the **preview**, the **category chips**,
/// and one **panel** that scrolls on its own. The preview never moves, because
/// 「プレビューしながら装備」 stops working the moment picking an item scrolls the
/// result off the screen — which is exactly what the old one-long-list layout
/// did.
///
/// Everything is edited against a **draft**, and the draft is what the preview
/// is painted from. Written on the way out, like every other editor sub-screen
/// in this app.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late Profile _draft = ref.read(profileProvider);

  /// Lives on the state rather than in the dialog, so the field can be found
  /// and disposed the same way whichever route is on top.
  late final TextEditingController _name = TextEditingController(
    text: _draft.userName,
  );

  _EditCategory _category = _EditCategory.icon;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _commit() {
    final stored = ref.read(profileProvider);
    final draft = _draft;
    if (draft.userName == stored.userName &&
        draft.iconId == stored.iconId &&
        draft.frameId == stored.frameId &&
        draft.plateBackgroundId == stored.plateBackgroundId &&
        draft.backgroundId == stored.backgroundId &&
        draft.titlePrefixId == stored.titlePrefixId &&
        draft.titleConnectorId == stored.titleConnectorId &&
        draft.titleSuffixId == stored.titleSuffixId) {
      return;
    }
    ref
        .read(profileProvider.notifier)
        .updateCosmetics(
          userName: draft.userName,
          iconId: draft.iconId,
          frameId: draft.frameId,
          plateBackgroundId: draft.plateBackgroundId,
          backgroundId: draft.backgroundId,
          titlePrefixId: draft.titlePrefixId,
          titleConnectorId: draft.titleConnectorId,
          titleSuffixId: draft.titleSuffixId,
        );
  }

  /// 名前 has no field of its own on this screen: the sketch has none, and the
  /// plate in the preview is where the name already is. Tapping it opens the
  /// dialog; OK writes the draft, and the draft is still only committed on the
  /// way out.
  Future<void> _editName() async {
    _name.text = _draft.userName;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('名前を変更'),
        content: TextField(
          key: const ValueKey('profileEditName'),
          controller: _name,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
          decoration: const InputDecoration(
            labelText: '名前',
            hintText: '例：田中太郎',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('profileEditNameCancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const ValueKey('profileEditNameOk'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    setState(() => _draft = _draft.copyWith(userName: _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _commit();
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('プロフィール編集')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // No pencil on the preview: this *is* the screen the pencil opens.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: ProfileHead(
                profile: _draft,
                keyPrefix: 'profileEdit',
                onNameTap: _editName,
                nameTapKey: const ValueKey('editNameplate'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final category in _EditCategory.values)
                    ChoiceChip(
                      key: ValueKey('editCategory-${category.slug}'),
                      label: Text(category.label),
                      selected: category == _category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
                  key: const ValueKey('editPanel'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  // Its own scroll: the preview above stays where it is no
                  // matter how long the drawer is.
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _items(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// What the panel is showing right now. One list per drawer, all built out of
  /// the same two tiles — a swatch for anything with art, a chip for a word.
  List<Widget> _items(BuildContext context) {
    switch (_category) {
      case _EditCategory.icon:
        return [
          for (final icon in ProfileCatalog.icons)
            ProfileSwatch(
              key: ValueKey('collectionIcon-${icon.id}'),
              label: icon.label,
              selected: icon.id == _draft.iconId,
              owned: _draft.ownedIconIds.contains(icon.id),
              onTap: () =>
                  setState(() => _draft = _draft.copyWith(iconId: icon.id)),
              child: Text(icon.emoji, style: const TextStyle(fontSize: 26)),
            ),
        ];
      case _EditCategory.frame:
        return [
          for (final frame in ProfileCatalog.frames)
            ProfileSwatch(
              key: ValueKey('collectionFrame-${frame.id}'),
              label: frame.label,
              selected: frame.id == _draft.frameId,
              owned: _draft.ownedFrameIds.contains(frame.id),
              onTap: () =>
                  setState(() => _draft = _draft.copyWith(frameId: frame.id)),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                  border: frame.width > 0
                      ? Border.all(color: frame.color, width: frame.width)
                      : null,
                ),
              ),
            ),
        ];
      case _EditCategory.plate:
        return [
          for (final plate in ProfileCatalog.plateBackgrounds)
            ProfileSwatch(
              key: ValueKey('collectionPlate-${plate.id}'),
              label: plate.label,
              selected: plate.id == _draft.plateBackgroundId,
              owned: _draft.ownedPlateBackgroundIds.contains(plate.id),
              onTap: () => setState(
                () => _draft = _draft.copyWith(plateBackgroundId: plate.id),
              ),
              child: _Fill(colors: plate.colors),
            ),
        ];
      case _EditCategory.background:
        return [
          for (final background in ProfileCatalog.backgrounds)
            ProfileSwatch(
              key: ValueKey('collectionBackground-${background.id}'),
              label: background.name,
              selected: background.id == _draft.backgroundId,
              owned: _draft.ownedBackgroundIds.contains(background.id),
              onTap: () => setState(
                () => _draft = _draft.copyWith(backgroundId: background.id),
              ),
              child: _Fill(colors: background.colors),
            ),
        ];
      case _EditCategory.titleA:
        return _words(
          TitleCatalog.prefixes,
          'titlePrefix',
          _draft.titlePrefixId,
          (id) => setState(() => _draft = _draft.copyWith(titlePrefixId: id)),
        );
      case _EditCategory.titleB:
        return _words(
          TitleCatalog.connectors,
          'titleConnector',
          _draft.titleConnectorId,
          (id) =>
              setState(() => _draft = _draft.copyWith(titleConnectorId: id)),
        );
      case _EditCategory.titleC:
        return _words(
          TitleCatalog.suffixes,
          'titleSuffix',
          _draft.titleSuffixId,
          (id) => setState(() => _draft = _draft.copyWith(titleSuffixId: id)),
        );
    }
  }

  /// One 称号 slot. Chips and not swatches: a word has nothing to draw, so the
  /// tile would be a box around the same text the label already is.
  List<Widget> _words(
    List<TitleWord> words,
    String keyPrefix,
    String selectedId,
    ValueChanged<String> onPick,
  ) => [
    for (final word in words)
      ChoiceChip(
        key: ValueKey('$keyPrefix-${word.id}'),
        label: Text(word.text),
        selected: word.id == selectedId,
        // Unowned words grey out and stop responding rather than
        // disappearing — the same rule the swatches follow.
        onSelected: _draft.ownedTitleWordIds.contains(word.id)
            ? (_) => onPick(word.id)
            : null,
      ),
  ];
}

/// Opens the editor over whatever screen asked for it.
Future<void> pushProfileEditScreen(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const ProfileEditScreen()));

/// A colour or a gradient in a little rounded box — the plate and the 背景 are
/// both nothing but their fill, so they preview identically. Outlined, so 「なし」
/// (fully transparent) is a visible empty tile rather than a hole.
class _Fill extends StatelessWidget {
  const _Fill({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 26,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      color: colors.length == 1 ? colors.first : null,
      gradient: colors.length > 1 ? LinearGradient(colors: colors) : null,
    ),
  );
}

/// The tile every cosmetic picker is made of. Greys out and stops responding
/// when the item is not owned.
class ProfileSwatch extends StatelessWidget {
  const ProfileSwatch({
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
    return InkWell(
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
    );
  }
}
