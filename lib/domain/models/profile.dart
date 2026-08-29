import 'package:flutter/foundation.dart';

import '../profile_catalog.dart';
import '../title_catalog.dart';

/// Who the app's user is, and how their name plate is dressed.
///
/// Separate from `Settings` because this is the player, not the app: the name
/// used to be a setting, but it now sits beside XP and the cosmetics that XP
/// will eventually unlock.
@immutable
class Profile {
  const Profile({
    this.userName = '',
    this.discordUserId = '',
    this.discordUsername = '',
    this.discordAvatar = '',
    this.xp = 0,
    this.iconId = ProfileCatalog.defaultIconId,
    this.plateBackgroundId = ProfileCatalog.defaultPlateBackgroundId,
    this.frameId = ProfileCatalog.defaultFrameId,
    this.titlePrefixId = TitleCatalog.defaultPrefixId,
    this.titleConnectorId = TitleCatalog.defaultConnectorId,
    this.titleSuffixId = TitleCatalog.defaultSuffixId,
    this.ownedIconIds = ProfileCatalog.allIconIds,
    this.ownedPlateBackgroundIds = ProfileCatalog.allPlateBackgroundIds,
    this.ownedFrameIds = ProfileCatalog.allFrameIds,
    this.ownedTitleWordIds = TitleCatalog.allTitleWordIds,
  });

  /// The person using the app — the one who oversleeps.
  ///
  /// Empty until they say. The oversleep message is *about* them and is sent
  /// *to* somebody else, so this is the name that belongs in it; with no name
  /// the message uses a generic subject rather than naming the recipient.
  final String userName;

  /// The Discord snowflake used to `@`-mention the user in a shared oversleep
  /// post. Digits only — see [normalizeDiscordUserId]. Empty means "no
  /// mention", and the post falls back to the name.
  final String discordUserId;

  /// The name Discord answered `/users/@me` with when the user linked their
  /// account — `global_name` if they have one, otherwise `username`.
  ///
  /// Display only: 「連携済み：@なまえ」 is the confirmation that the ID above
  /// belongs to the account they meant. Nothing sends it anywhere, and an ID
  /// typed by hand simply leaves it empty.
  final String discordUsername;

  /// The avatar hash from the same answer. Kept because it is free and the
  /// profile will want a real picture eventually; nothing draws it yet.
  final String discordAvatar;

  /// Whether the ID came from an authorised Discord account rather than being
  /// typed in. The name is the evidence — there is no way to obtain it by
  /// hand — so the two are one fact and not two.
  bool get discordLinked =>
      discordUserId.isNotEmpty && discordUsername.isNotEmpty;

  /// Earned by waking up, never spent. Levels are derived from it, so a level
  /// can never be lost by buying something.
  final int xp;

  final String iconId;
  final String plateBackgroundId;
  final String frameId;

  /// The three words the 称号 is built from — 「寝坊」「の」「常習犯」 by default.
  final String titlePrefixId;
  final String titleConnectorId;
  final String titleSuffixId;

  /// 「寝坊の常習犯」. Derived, never stored: the words are the state.
  String get title =>
      composeTitle(titlePrefixId, titleConnectorId, titleSuffixId);

  /// Everything currently held. There is no way to earn a cosmetic yet, so
  /// these default to the whole catalogue — but the pickers read them, so a
  /// grant mechanism only has to start writing narrower sets.
  final Set<String> ownedIconIds;
  final Set<String> ownedPlateBackgroundIds;
  final Set<String> ownedFrameIds;

  /// One set for all three title slots. The ids are namespaced (`p_`/`c_`/`s_`)
  /// so a single set can never confuse a prefix with a suffix.
  final Set<String> ownedTitleWordIds;

  Profile copyWith({
    String? userName,
    String? discordUserId,
    String? discordUsername,
    String? discordAvatar,
    int? xp,
    String? iconId,
    String? plateBackgroundId,
    String? frameId,
    String? titlePrefixId,
    String? titleConnectorId,
    String? titleSuffixId,
    Set<String>? ownedIconIds,
    Set<String>? ownedPlateBackgroundIds,
    Set<String>? ownedFrameIds,
    Set<String>? ownedTitleWordIds,
  }) => Profile(
    userName: userName ?? this.userName,
    discordUserId: discordUserId ?? this.discordUserId,
    discordUsername: discordUsername ?? this.discordUsername,
    discordAvatar: discordAvatar ?? this.discordAvatar,
    xp: xp ?? this.xp,
    iconId: iconId ?? this.iconId,
    plateBackgroundId: plateBackgroundId ?? this.plateBackgroundId,
    frameId: frameId ?? this.frameId,
    titlePrefixId: titlePrefixId ?? this.titlePrefixId,
    titleConnectorId: titleConnectorId ?? this.titleConnectorId,
    titleSuffixId: titleSuffixId ?? this.titleSuffixId,
    ownedIconIds: ownedIconIds ?? this.ownedIconIds,
    ownedPlateBackgroundIds:
        ownedPlateBackgroundIds ?? this.ownedPlateBackgroundIds,
    ownedFrameIds: ownedFrameIds ?? this.ownedFrameIds,
    ownedTitleWordIds: ownedTitleWordIds ?? this.ownedTitleWordIds,
  );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.userName == userName &&
      other.discordUserId == discordUserId &&
      other.discordUsername == discordUsername &&
      other.discordAvatar == discordAvatar &&
      other.xp == xp &&
      other.iconId == iconId &&
      other.plateBackgroundId == plateBackgroundId &&
      other.frameId == frameId &&
      other.titlePrefixId == titlePrefixId &&
      other.titleConnectorId == titleConnectorId &&
      other.titleSuffixId == titleSuffixId &&
      setEquals(other.ownedIconIds, ownedIconIds) &&
      setEquals(other.ownedPlateBackgroundIds, ownedPlateBackgroundIds) &&
      setEquals(other.ownedFrameIds, ownedFrameIds) &&
      setEquals(other.ownedTitleWordIds, ownedTitleWordIds);

  @override
  int get hashCode => Object.hash(
    userName,
    discordUserId,
    discordUsername,
    discordAvatar,
    xp,
    iconId,
    plateBackgroundId,
    frameId,
    titlePrefixId,
    titleConnectorId,
    titleSuffixId,
    Object.hashAllUnordered(ownedIconIds),
    Object.hashAllUnordered(ownedPlateBackgroundIds),
    Object.hashAllUnordered(ownedFrameIds),
    Object.hashAllUnordered(ownedTitleWordIds),
  );

  @override
  String toString() =>
      'Profile("$userName", discord "$discordUserId", xp $xp, '
      '$iconId/$plateBackgroundId/$frameId, 「$title」)';
}

/// Keeps only the digits of a pasted Discord user ID. Pure.
///
/// People copy the mention rather than the ID — `<@123>` is what Discord puts
/// on the clipboard — and the raw ID is what the webhook payload needs, so the
/// stripping happens once here instead of at every use site.
String normalizeDiscordUserId(String raw) =>
    raw.replaceAll(RegExp(r'[^0-9]'), '');
