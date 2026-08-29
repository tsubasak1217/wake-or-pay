import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models.dart';

/// オプション, in shared_preferences: two integers' worth of state, read while
/// the first frame is being painted, exactly like [SettingsRepository].
class OptionsRepository {
  OptionsRepository(this._prefs);

  static const capCeilingKey = 'options.capCeiling';

  final SharedPreferences _prefs;

  /// The setting is free numeric input, so any integer is a value this build
  /// understands: a stored number reads back as itself, brought inside
  /// `[1, absoluteMaxKakugoCap]`. Only a *missing* value falls back to the
  /// out-of-the-box ceiling.
  Options read() {
    final stored = _prefs.getInt(capCeilingKey);
    return Options(
      capCeiling: stored == null ? maxKakugoCap : normalizeCapCeiling(stored),
    );
  }

  Future<void> write(Options options) async {
    await _prefs.setInt(capCeilingKey, options.capCeiling);
  }
}
