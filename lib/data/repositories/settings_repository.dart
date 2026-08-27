import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';

/// Settings are tiny and are read while the first frame is being painted, so
/// they live in shared_preferences rather than the database — reads are
/// synchronous once the instance is loaded at startup.
class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _themeIdKey = 'settings.themeId';
  static const _unlockedKey = 'settings.unlockedThemeIds';

  final SharedPreferences _prefs;

  Settings read() => Settings(
    themeId: _prefs.getString(_themeIdKey) ?? AppThemes.defaultThemeId,
    unlockedThemeIds: {
      AppThemes.defaultThemeId,
      ...?_prefs.getStringList(_unlockedKey),
    },
  );

  // `settings.userName` is deliberately neither read nor written any more: the
  // name belongs to the profile now, and `ProfileRepository` reads that key
  // through as a fallback. Leaving it untouched is what keeps a rollback able
  // to find it.
  Future<void> write(Settings settings) async {
    await _prefs.setString(_themeIdKey, settings.themeId);
    await _prefs.setStringList(
      _unlockedKey,
      settings.unlockedThemeIds.toList()..sort(),
    );
  }

  Future<Settings> update(Settings Function(Settings current) change) async {
    final next = change(read());
    await write(next);
    return next;
  }
}
