import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';

/// Currently selected theme id. Persisted by [SettingsRepository] once the
/// data layer is wired in; overridden in tests.
final themeIdProvider = NotifierProvider<ThemeIdController, String>(
  ThemeIdController.new,
);

class ThemeIdController extends Notifier<String> {
  @override
  String build() => AppThemes.defaultThemeId;

  void select(String id) => state = AppThemes.byId(id).id;
}

final currentThemeProvider = Provider<AppTheme>(
  (ref) => AppThemes.byId(ref.watch(themeIdProvider)),
);
