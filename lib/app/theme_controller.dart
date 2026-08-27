import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/models.dart';
import 'theme.dart';

/// Persisted settings, kept in memory so the theme can be read synchronously
/// while painting.
final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.watch(settingsRepositoryProvider).read();

  Future<void> selectTheme(String id) async {
    state = await ref
        .read(settingsRepositoryProvider)
        .update((s) => s.copyWith(themeId: AppThemes.byId(id).id));
  }

  /// The app's own user. Stored trimmed; empty means "not set".
  Future<void> setUserName(String name) async {
    state = await ref
        .read(settingsRepositoryProvider)
        .update((s) => s.copyWith(userName: name.trim()));
  }

  Future<void> unlockTheme(String id) async {
    state = await ref
        .read(settingsRepositoryProvider)
        .update(
          (s) => s.copyWith(unlockedThemeIds: {...s.unlockedThemeIds, id}),
        );
  }
}

final themeIdProvider = Provider<String>(
  (ref) => ref.watch(settingsProvider).themeId,
);

final currentThemeProvider = Provider<AppTheme>(
  (ref) => AppThemes.byId(ref.watch(themeIdProvider)),
);
