import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models.dart';
import '../../domain/profile_catalog.dart';

/// The profile lives beside the settings in shared_preferences, for the same
/// reason: the header paints it on the first frame, so the read has to be
/// synchronous.
class ProfileRepository {
  ProfileRepository(this._prefs);

  static const _userNameKey = 'profile.userName';
  static const _discordUserIdKey = 'profile.discordUserId';
  static const _xpKey = 'profile.xp';
  static const _iconKey = 'profile.iconId';
  static const _plateKey = 'profile.plateBackgroundId';
  static const _frameKey = 'profile.frameId';
  static const _ownedIconsKey = 'profile.ownedIconIds';
  static const _ownedPlatesKey = 'profile.ownedPlateBackgroundIds';
  static const _ownedFramesKey = 'profile.ownedFrameIds';

  /// Where the name lived when it was a setting. Read as a fallback and never
  /// written or deleted: the read-through is non-destructive, so an install
  /// rolled back to a build without the profile still finds its name where it
  /// left it.
  static const legacyUserNameKey = 'settings.userName';

  final SharedPreferences _prefs;

  Profile read() => Profile(
    userName:
        _prefs.getString(_userNameKey) ??
        _prefs.getString(legacyUserNameKey) ??
        '',
    discordUserId: _prefs.getString(_discordUserIdKey) ?? '',
    xp: _prefs.getInt(_xpKey) ?? 0,
    iconId: _prefs.getString(_iconKey) ?? ProfileCatalog.defaultIconId,
    plateBackgroundId:
        _prefs.getString(_plateKey) ?? ProfileCatalog.defaultPlateBackgroundId,
    frameId: _prefs.getString(_frameKey) ?? ProfileCatalog.defaultFrameId,
    // No stored set means nothing has ever been granted or taken away, which
    // today is "owns everything".
    ownedIconIds:
        _prefs.getStringList(_ownedIconsKey)?.toSet() ??
        ProfileCatalog.allIconIds,
    ownedPlateBackgroundIds:
        _prefs.getStringList(_ownedPlatesKey)?.toSet() ??
        ProfileCatalog.allPlateBackgroundIds,
    ownedFrameIds:
        _prefs.getStringList(_ownedFramesKey)?.toSet() ??
        ProfileCatalog.allFrameIds,
  );

  Future<void> write(Profile profile) async {
    await _prefs.setString(_userNameKey, profile.userName);
    // Normalised on the way in as well as in the editor, so a value set by any
    // other caller cannot land in prefs with a `<@…>` around it.
    await _prefs.setString(
      _discordUserIdKey,
      normalizeDiscordUserId(profile.discordUserId),
    );
    await _prefs.setInt(_xpKey, profile.xp);
    await _prefs.setString(_iconKey, profile.iconId);
    await _prefs.setString(_plateKey, profile.plateBackgroundId);
    await _prefs.setString(_frameKey, profile.frameId);
    await _prefs.setStringList(
      _ownedIconsKey,
      profile.ownedIconIds.toList()..sort(),
    );
    await _prefs.setStringList(
      _ownedPlatesKey,
      profile.ownedPlateBackgroundIds.toList()..sort(),
    );
    await _prefs.setStringList(
      _ownedFramesKey,
      profile.ownedFrameIds.toList()..sort(),
    );
  }

  /// Re-reads rather than handing back what was written: [write] normalises the
  /// Discord ID, so the stored profile is the authority on what it now is.
  Future<Profile> update(Profile Function(Profile current) change) async {
    await write(change(read()));
    return read();
  }
}
