import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'database.dart';
import 'repositories/alarm_repository.dart';
import 'repositories/alarm_session_repository.dart';
import 'repositories/contact_book_repository.dart';
import 'repositories/contact_event_repository.dart';
import 'repositories/discord_webhook_repository.dart';
import 'repositories/garden_repository.dart';
import 'repositories/mail_settings_repository.dart';
import 'repositories/ojisan_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/wallet_repository.dart';
import '../services/secret_store.dart';

/// Overridden in `main()` with the instance loaded before the first frame, and
/// in tests with mock values.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// The wall clock, injectable so tests can pin "now" instead of racing it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

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

final discordWebhookRepositoryProvider = Provider(
  (ref) => DiscordWebhookRepository(ref.watch(appDatabaseProvider)),
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

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(ref.watch(sharedPreferencesProvider)),
);

/// メール送信設定. Two stores behind one object — prefs for the server fields,
/// the secure store for the app password. See [MailSettingsRepository].
final mailSettingsRepositoryProvider = Provider(
  (ref) => MailSettingsRepository(
    ref.watch(sharedPreferencesProvider),
    ref.watch(secretStoreProvider),
  ),
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

/// The oversleep log for one ring, live. The ringing screen reads it to say
/// which routes actually went out — 「田中太郎 に電話をかけました」.
final sessionContactEventsProvider =
    StreamProvider.family<List<ContactEvent>, String>(
      (ref, sessionId) =>
          ref.watch(contactEventRepositoryProvider).watchForSession(sessionId),
    );

/// The 連絡帳, already in よみがな order.
final contactBookProvider = StreamProvider<List<ContactEntry>>(
  (ref) => ref.watch(contactBookRepositoryProvider).watchAll(),
);

/// The 連絡帳 as a plain list, for everything that resolves an alarm's contact
/// snapshot against it — see `resolveOversleepContact`.
///
/// Empty while the stream is still loading, which is the same answer as an
/// empty book: the snapshot held on the alarm is used, and the row corrects
/// itself one frame later when the rows arrive.
final contactBookListProvider = Provider<List<ContactEntry>>(
  (ref) => ref.watch(contactBookProvider).valueOrNull ?? const <ContactEntry>[],
);

/// The app-wide Discord 共有先 list, oldest first.
final discordWebhooksProvider = StreamProvider<List<DiscordWebhook>>(
  (ref) => ref.watch(discordWebhookRepositoryProvider).watchAll(),
);

/// The 共有先 as a plain list, for everything that turns an alarm's stored ids
/// back into rows — the count on a row, the switches on the 共有先 screen.
///
/// Empty while the stream is still loading, which is the same answer as an
/// empty list: the row reads 「なし」 for one frame and corrects itself when the
/// rows arrive.
final discordWebhookListProvider = Provider<List<DiscordWebhook>>(
  (ref) =>
      ref.watch(discordWebhooksProvider).valueOrNull ??
      const <DiscordWebhook>[],
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
