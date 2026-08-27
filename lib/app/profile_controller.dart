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
  Future<void> setDiscordUserId(String id) =>
      _update((p) => p.copyWith(discordUserId: normalizeDiscordUserId(id)));

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
