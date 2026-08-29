import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models.dart';

/// 開始日 and ログイン日数, in shared_preferences beside the profile — for the
/// same reason: the profile paints them without waiting on a future.
class UsageRepository {
  UsageRepository(this._prefs);

  static const firstOpenedAtKey = 'usage.firstOpenedAt';
  static const loginDaysKey = 'usage.loginDays';
  static const lastLoginDayKey = 'usage.lastLoginDay';

  final SharedPreferences _prefs;

  UsageStats read() {
    final first = _prefs.getString(firstOpenedAtKey);
    return UsageStats(
      // `tryParse`, not `parse`: a corrupt value must read as "never opened"
      // rather than throw on the frame that paints the profile.
      firstOpenedAt: first == null ? null : DateTime.tryParse(first),
      loginDays: _prefs.getInt(loginDaysKey) ?? 0,
      lastLoginDay: _prefs.getString(lastLoginDayKey) ?? '',
    );
  }

  /// One app start. Idempotent within a calendar day: opening the app five
  /// times before lunch is one login day, not five.
  Future<UsageStats> recordOpen(DateTime now) async {
    final current = read();
    if (current.firstOpenedAt == null) {
      await _prefs.setString(firstOpenedAtKey, now.toIso8601String());
    }
    final today = usageDayKey(now);
    if (current.lastLoginDay != today) {
      await _prefs.setString(lastLoginDayKey, today);
      await _prefs.setInt(loginDaysKey, current.loginDays + 1);
    }
    return read();
  }
}
