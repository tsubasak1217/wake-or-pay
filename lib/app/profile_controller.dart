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

  // `setDiscordUserId` went with the hand-typed 「Discord ユーザーID」 screen
  // (段階F). It existed to keep 「連携済み：@なまえ」 from vouching for an ID
  // somebody had merely pasted — a rule with nothing left to protect, now that
  // [linkDiscordAccount] is the only way an ID can get in at all.

  /// Stores what an authorised Discord account said about itself.
  ///
  /// **The only way a Discord ID enters this app.** It always arrives with the
  /// name beside it, and the name is the evidence: it came from an account
  /// that authorised, not from eighteen digits somebody read off a screen.
  ///
  /// The ID is normalised on the way in — people paste the mention (`<@123…>`)
  /// far more often than the bare snowflake — so what is stored is always
  /// something a webhook can actually mention.
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
