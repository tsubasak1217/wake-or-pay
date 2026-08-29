import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models.dart';

/// オプション, in shared_preferences: two integers' worth of state, read while
/// the first frame is being painted, exactly like [SettingsRepository].
class OptionsRepository {
  OptionsRepository(this._prefs);

  static const capCeilingKey = 'options.capCeiling';

  final SharedPreferences _prefs;

  /// An unknown or out-of-range stored value reads as the default rather than
  /// as itself: the choices are a fixed list, and a number that is not on it
  /// is data this build does not understand.
  Options read() {
    final stored = _prefs.getInt(capCeilingKey);
    return Options(
      capCeiling: stored != null && capCeilingChoices.contains(stored)
          ? stored
          : maxKakugoCap,
    );
  }

  Future<void> write(Options options) async {
    await _prefs.setInt(capCeilingKey, options.capCeiling);
  }
}
