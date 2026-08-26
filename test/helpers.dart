import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wake_or_pay/data/database.dart';
import 'package:wake_or_pay/data/providers.dart';

/// Overrides backing the app with an in-memory database and in-memory
/// preferences. The database is closed when the owning container is disposed.
Future<List<Override>> testOverrides({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({...prefs});
  final preferences = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(preferences),
    appDatabaseProvider.overrideWith((ref) {
      final db = AppDatabase.memory();
      ref.onDispose(db.close);
      return db;
    }),
  ];
}

Future<ProviderContainer> testContainer({
  Map<String, Object> prefs = const {},
}) async {
  final container = ProviderContainer(
    overrides: await testOverrides(prefs: prefs),
  );
  addTearDown(container.dispose);
  return container;
}
