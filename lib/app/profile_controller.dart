import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/models.dart';

/// The persisted profile, kept in memory so the header can paint the name,
/// the level and the cosmetics without waiting on a future.
final profileProvider = NotifierProvider<ProfileController, Profile>(
  ProfileController.new,
);

class ProfileController extends Notifier<Profile> {
  @override
  Profile build() => ref.watch(profileRepositoryProvider).read();

  /// The app's own user. Stored trimmed; empty means "not set".
  Future<void> setUserName(String name) =>
      _update((p) => p.copyWith(userName: name.trim()));

  /// Digits only — the repository strips the rest, and doing it here too keeps
  /// what the screen shows next frame equal to what was stored.
  /// Typing a **different** ID drops the linked name and avatar with it: those
  /// are the evidence that the ID came from an authorised account, and leaving
  /// 「連携済み：@なまえ」 over a hand-typed ID would vouch for something nobody
  /// checked. Re-typing the same ID changes nothing.
  Future<void> setDiscordUserId(String id) => _update((p) {
    final normalized = normalizeDiscordUserId(id);
    if (normalized == p.discordUserId) return p;
    return p.copyWith(
      discordUserId: normalized,
      discordUsername: '',
      discordAvatar: '',
    );
  });

  /// Stores what an authorised Discord account said about itself.
  ///
  /// Overwrites a hand-typed ID on purpose: the user just proved which account
  /// is theirs, which is a better answer than whatever they pasted.
  Future<void> linkDiscordAccount({
    required String id,
    required String username,
    String avatar = '',
  }) => _update(
    (p) => p.copyWith(
      discordUserId: normalizeDiscordUserId(id),
      discordUsername: username,
      discordAvatar: avatar,
    ),
  );

  /// 連携を解除. Clears the ID as well as the name.
  ///
  /// Leaving the ID behind would keep mentioning the user from an account they
  /// just said to forget — and 「連携を解除」 that leaves the mention working is a
  /// button that lies. The ID can still be typed back in by hand.
  Future<void> unlinkDiscordAccount() => _update(
    (p) => p.copyWith(
      discordUserId: '',
      discordUsername: '',
      discordAvatar: '',
    ),
  );

  Future<void> selectIcon(String id) =>
      _update((p) => p.copyWith(iconId: id));

  Future<void> selectPlateBackground(String id) =>
      _update((p) => p.copyWith(plateBackgroundId: id));

  Future<void> selectFrame(String id) =>
      _update((p) => p.copyWith(frameId: id));

  /// Read-modify-write against storage rather than against [state]: the
  /// settle path grants XP from outside the widget tree, so this cannot assume
  /// it holds the newest value.
  Future<void> addXp(int amount) =>
      _update((p) => p.copyWith(xp: p.xp + amount));

  Future<void> _update(Profile Function(Profile) change) async {
    state = await ref.read(profileRepositoryProvider).update(change);
  }
}
