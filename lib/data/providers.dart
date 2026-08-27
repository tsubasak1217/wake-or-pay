import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'database.dart';
import 'repositories/alarm_repository.dart';
import 'repositories/alarm_session_repository.dart';
import 'repositories/contact_book_repository.dart';
import 'repositories/contact_event_repository.dart';
import 'repositories/garden_repository.dart';
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

final contactEventRepositoryProvider = Provider(
  (ref) => ContactEventRepository(ref.watch(appDatabaseProvider)),
);

final contactBookRepositoryProvider = Provider(
  (ref) => ContactBookRepository(ref.watch(appDatabaseProvider)),
);

final walletRepositoryProvider = Provider(
  (ref) => WalletRepository(ref.watch(appDatabaseProvider)),
);

final ojisanRepositoryProvider = Provider(
  (ref) => OjisanRepository(ref.watch(appDatabaseProvider)),
);

final gardenRepositoryProvider = Provider(
  (ref) => GardenRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(sharedPreferencesProvider),
  ),
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

/// Emits after the free starter set has been handed out, so the garden never
/// paints an empty terrarium on a first launch.
final gardenProvider = StreamProvider<GardenState>((ref) {
  final repository = ref.watch(gardenRepositoryProvider);
  // The grant runs first and its result is discarded: `watch` re-reads it.
  return Stream.fromFuture(repository.grantInitialIfNeeded())
      .asyncExpand((_) => repository.watch());
});

final sessionHistoryProvider = StreamProvider<List<AlarmSession>>(
  (ref) => ref.watch(alarmSessionRepositoryProvider).watchRecent(),
);

/// Live ringing sessions, snoozed ones included. The alarm list reads this to
/// mark a row 「スヌーズ中 7:05」.
final ringingSessionsProvider = StreamProvider<List<AlarmSession>>(
  (ref) => ref.watch(alarmSessionRepositoryProvider).watchRinging(),
);

/// The oversleep contact log, newest first. Shown in the wallet history.
final contactEventsProvider = StreamProvider<List<ContactEvent>>(
  (ref) => ref.watch(contactEventRepositoryProvider).watchRecent(),
);

/// The 連絡帳, already in よみがな order.
final contactBookProvider = StreamProvider<List<ContactEntry>>(
  (ref) => ref.watch(contactBookRepositoryProvider).watchAll(),
);

final sessionByIdProvider = FutureProvider.family<AlarmSession?, String>(
  (ref, id) => ref.watch(alarmSessionRepositoryProvider).getById(id),
);

/// Live, not a one-shot read: a `FutureProvider` here caches the alarm as it
/// was the first time anyone asked for it, which is how an alarm edited in the
/// editor used to ring with its previous wake check.
final alarmByIdProvider = StreamProvider.family<Alarm?, String>(
  (ref, id) => ref.watch(alarmRepositoryProvider).watchById(id),
);
