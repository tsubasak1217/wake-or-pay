import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_controller.dart';
import '../../domain/models.dart';
import '../../domain/profile_catalog.dart';
import '../../domain/title_catalog.dart';
import '../alarms/widgets/settings_island.dart';
import 'profile_head.dart';

/// プロフィール編集 — the one place a name and a set of cosmetics are chosen.
///
/// Everything is edited against a **draft**, and the draft is what the preview
/// at the top is painted from: 「プレビューしながら装備」 is the whole point of the
/// screen, and a picker that wrote straight through would be previewing on the
/// profile behind the screen instead.
///
/// Written on the way out, like every other editor sub-screen in this app.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late Profile _draft = ref.read(profileProvider);
  late final TextEditingController _name = TextEditingController(
    text: _draft.userName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _commit() {
    final stored = ref.read(profileProvider);
    final draft = _draft.copyWith(userName: _name.text.trim());
    if (draft.userName == stored.userName &&
        draft.iconId == stored.iconId &&
        draft.frameId == stored.frameId &&
        draft.plateBackgroundId == stored.plateBackgroundId &&
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
          titlePrefixId: draft.titlePrefixId,
          titleConnectorId: draft.titleConnectorId,
          titleSuffixId: draft.titleSuffixId,
        );
  }

  @override
  Widget build(BuildContext context) {
    // The name is typed, so the preview has to follow the field rather than the
    // draft — the draft only learns the name on the way out.
    final preview = _draft.copyWith(userName: _name.text.trim());

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _commit();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('プロフィール編集')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // No pencil on the preview: this *is* the screen the pencil opens.
            ProfileHead(profile: preview, keyPrefix: 'profileEdit'),
            const SizedBox(height: 24),
            TextField(
              key: const ValueKey('profileEditName'),
              controller: _name,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => Navigator.of(context).maybePop(),
              decoration: const InputDecoration(
                labelText: '名前',
                hintText: '例：田中太郎',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '寝坊したことを連絡先に伝える文面の主語になります。'
              '未設定のままなら「$oversleepUserNameFallback さん」になります。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            SettingsIsland(
              title: 'コレクション',
              children: [
                _PickerRow(
                  label: 'アイコン',
                  children: [
                    for (final icon in ProfileCatalog.icons)
                      ProfileSwatch(
                        key: ValueKey('collectionIcon-${icon.id}'),
                        label: icon.label,
                        selected: icon.id == _draft.iconId,
                        owned: _draft.ownedIconIds.contains(icon.id),
                        onTap: () => setState(
                          () => _draft = _draft.copyWith(iconId: icon.id),
                        ),
                        child: Text(
                          icon.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                  ],
                ),
                _PickerRow(
                  label: 'アイコンフレーム',
                  children: [
                    for (final frame in ProfileCatalog.frames)
                      ProfileSwatch(
                        key: ValueKey('collectionFrame-${frame.id}'),
                        label: frame.label,
                        selected: frame.id == _draft.frameId,
                        owned: _draft.ownedFrameIds.contains(frame.id),
                        onTap: () => setState(
                          () => _draft = _draft.copyWith(frameId: frame.id),
                        ),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.surface,
                            border: frame.width > 0
                                ? Border.all(
                                    color: frame.color,
                                    width: frame.width,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                _PickerRow(
                  label: 'ネームプレート',
                  children: [
                    for (final plate in ProfileCatalog.plateBackgrounds)
                      ProfileSwatch(
                        key: ValueKey('collectionPlate-${plate.id}'),
                        label: plate.label,
                        selected: plate.id == _draft.plateBackgroundId,
                        owned: _draft.ownedPlateBackgroundIds.contains(
                          plate.id,
                        ),
                        onTap: () => setState(
                          () => _draft = _draft.copyWith(
                            plateBackgroundId: plate.id,
                          ),
                        ),
                        child: Container(
                          width: 44,
                          height: 26,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: plate.colors.length == 1
                                ? plate.colors.first
                                : null,
                            gradient: plate.colors.length > 1
                                ? LinearGradient(colors: plate.colors)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SettingsIsland(
              title: '称号',
              children: [
                _TitleChipRow(
                  label: '前半',
                  keyPrefix: 'titlePrefix',
                  words: TitleCatalog.prefixes,
                  selectedId: _draft.titlePrefixId,
                  owned: _draft.ownedTitleWordIds,
                  onPick: (id) => setState(
                    () => _draft = _draft.copyWith(titlePrefixId: id),
                  ),
                ),
                _TitleChipRow(
                  label: '接続詞',
                  keyPrefix: 'titleConnector',
                  words: TitleCatalog.connectors,
                  selectedId: _draft.titleConnectorId,
                  owned: _draft.ownedTitleWordIds,
                  onPick: (id) => setState(
                    () => _draft = _draft.copyWith(titleConnectorId: id),
                  ),
                ),
                _TitleChipRow(
                  label: '後半',
                  keyPrefix: 'titleSuffix',
                  words: TitleCatalog.suffixes,
                  selectedId: _draft.titleSuffixId,
                  owned: _draft.ownedTitleWordIds,
                  onPick: (id) => setState(
                    () => _draft = _draft.copyWith(titleSuffixId: id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the editor over whatever screen asked for it.
Future<void> pushProfileEditScreen(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const ProfileEditScreen()));

/// One horizontal row of swatches, with its label above.
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
          child: ListView(scrollDirection: Axis.horizontal, children: children),
        ),
      ],
    ),
  );
}

/// One slot of the 称号, as a row of chips.
///
/// Chips and not swatches: a word has nothing to draw, so the tile would be a
/// box around the same text the label already is.
class _TitleChipRow extends StatelessWidget {
  const _TitleChipRow({
    required this.label,
    required this.keyPrefix,
    required this.words,
    required this.selectedId,
    required this.owned,
    required this.onPick,
  });

  final String label;
  final String keyPrefix;
  final List<TitleWord> words;
  final String selectedId;
  final Set<String> owned;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final word in words)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('$keyPrefix-${word.id}'),
                    label: Text(word.text),
                    selected: word.id == selectedId,
                    // Unowned words grey out and stop responding rather than
                    // disappearing — the same rule the swatches follow.
                    onSelected: owned.contains(word.id)
                        ? (_) => onPick(word.id)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ],
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
