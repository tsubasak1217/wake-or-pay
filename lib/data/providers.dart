import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'database.dart';
import 'repositories/alarm_repository.dart';
import 'repositories/alarm_session_repository.dart';
import 'repositories/ojisan_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/wallet_repository.dart';

/// Overridden in `main()` with the instance loaded before the first frame, and
/// in tests with mock values.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.file();
  ref.onDispose(db.close);
  return db;
});

final alarmRepositoryProvider = Provider(
  (ref) => AlarmRepository(ref.watch(appDatabaseProvider)),
);

final alarmSessionRepositoryProvider = Provider(
  (ref) => AlarmSessionRepository(ref.watch(appDatabaseProvider)),
);

final walletRepositoryProvider = Provider(
  (ref) => WalletRepository(ref.watch(appDatabaseProvider)),
);

final ojisanRepositoryProvider = Provider(
  (ref) => OjisanRepository(ref.watch(appDatabaseProvider)),
);

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final alarmsProvider = StreamProvider<List<Alarm>>(
  (ref) => ref.watch(alarmRepositoryProvider).watchAll(),
);

final walletProvider = StreamProvider<Wallet>(
  (ref) => ref.watch(walletRepositoryProvider).watch(),
);

final ojisanProvider = StreamProvider<OjisanState>(
  (ref) => ref.watch(ojisanRepositoryProvider).watch(),
);

final sessionHistoryProvider = StreamProvider<List<AlarmSession>>(
  (ref) => ref.watch(alarmSessionRepositoryProvider).watchRecent(),
);

final sessionByIdProvider = FutureProvider.family<AlarmSession?, String>(
  (ref, id) => ref.watch(alarmSessionRepositoryProvider).getById(id),
);

final alarmByIdProvider = FutureProvider.family<Alarm?, String>(
  (ref, id) => ref.watch(alarmRepositoryProvider).getById(id),
);
