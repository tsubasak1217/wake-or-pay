import 'package:flutter/foundation.dart';

import '../profile_catalog.dart';

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
    this.xp = 0,
    this.iconId = ProfileCatalog.defaultIconId,
    this.plateBackgroundId = ProfileCatalog.defaultPlateBackgroundId,
    this.frameId = ProfileCatalog.defaultFrameId,
    this.ownedIconIds = ProfileCatalog.allIconIds,
    this.ownedPlateBackgroundIds = ProfileCatalog.allPlateBackgroundIds,
    this.ownedFrameIds = ProfileCatalog.allFrameIds,
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

  /// Earned by waking up, never spent. Levels are derived from it, so a level
  /// can never be lost by buying something.
  final int xp;

  final String iconId;
  final String plateBackgroundId;
  final String frameId;

  /// Everything currently held. There is no way to earn a cosmetic yet, so
  /// these default to the whole catalogue — but the pickers read them, so a
  /// grant mechanism only has to start writing narrower sets.
  final Set<String> ownedIconIds;
  final Set<String> ownedPlateBackgroundIds;
  final Set<String> ownedFrameIds;

  Profile copyWith({
    String? userName,
    String? discordUserId,
    int? xp,
    String? iconId,
    String? plateBackgroundId,
    String? frameId,
    Set<String>? ownedIconIds,
    Set<String>? ownedPlateBackgroundIds,
    Set<String>? ownedFrameIds,
  }) => Profile(
    userName: userName ?? this.userName,
    discordUserId: discordUserId ?? this.discordUserId,
    xp: xp ?? this.xp,
    iconId: iconId ?? this.iconId,
    plateBackgroundId: plateBackgroundId ?? this.plateBackgroundId,
    frameId: frameId ?? this.frameId,
    ownedIconIds: ownedIconIds ?? this.ownedIconIds,
    ownedPlateBackgroundIds:
        ownedPlateBackgroundIds ?? this.ownedPlateBackgroundIds,
    ownedFrameIds: ownedFrameIds ?? this.ownedFrameIds,
  );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.userName == userName &&
      other.discordUserId == discordUserId &&
      other.xp == xp &&
      other.iconId == iconId &&
      other.plateBackgroundId == plateBackgroundId &&
      other.frameId == frameId &&
      setEquals(other.ownedIconIds, ownedIconIds) &&
      setEquals(other.ownedPlateBackgroundIds, ownedPlateBackgroundIds) &&
      setEquals(other.ownedFrameIds, ownedFrameIds);

  @override
  int get hashCode => Object.hash(
    userName,
    discordUserId,
    xp,
    iconId,
    plateBackgroundId,
    frameId,
    Object.hashAllUnordered(ownedIconIds),
    Object.hashAllUnordered(ownedPlateBackgroundIds),
    Object.hashAllUnordered(ownedFrameIds),
  );

  @override
  String toString() =>
      'Profile("$userName", discord "$discordUserId", xp $xp, '
      '$iconId/$plateBackgroundId/$frameId)';
}

/// Keeps only the digits of a pasted Discord user ID. Pure.
///
/// People copy the mention rather than the ID — `<@123>` is what Discord puts
/// on the clipboard — and the raw ID is what the webhook payload needs, so the
/// stripping happens once here instead of at every use site.
String normalizeDiscordUserId(String raw) =>
    raw.replaceAll(RegExp(r'[^0-9]'), '');
