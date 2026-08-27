import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wake_or_pay/data/database.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/alarm_service.dart';
import 'package:wake_or_pay/services/app_notifier.dart';

/// Overrides backing the app with an in-memory database and in-memory
/// preferences. The database is closed when the owning container is disposed.
Future<List<Override>> testOverrides({
  Map<String, Object> prefs = const {},
  List<Override> extra = const [],
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
    ...extra,
  ];
}

Future<ProviderContainer> testContainer({
  Map<String, Object> prefs = const {},
  List<Override> extra = const [],
}) async {
  final container = ProviderContainer(
    overrides: await testOverrides(prefs: prefs, extra: extra),
  );
  addTearDown(container.dispose);
  return container;
}

/// Replaces every call that would reach the `alarm` plugin, so widget tests can
/// drive the real controllers without a platform underneath.
class FakeAlarmService extends AlarmService {
  FakeAlarmService(super.ref);

  final scheduled = <String>[];
  final cancelled = <String>[];

  /// Every re-ring armed by a snooze, in order.
  final rearmed = <({String alarmId, DateTime ringAt})>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> schedule(Alarm alarm, {DateTime? from}) async {
    scheduled.add(alarm.id);
  }

  @override
  Future<void> cancel(Alarm alarm) async {
    cancelled.add(alarm.id);
  }

  @override
  Future<void> setRingAt(Alarm alarm, DateTime ringAt) async {
    rearmed.add((alarmId: alarm.id, ringAt: ringAt));
  }
}

Override fakeAlarmServiceOverride() =>
    alarmServiceProvider.overrideWith((ref) => FakeAlarmService(ref));

/// The notifications a test's container posted. The provider's default is
/// already a [RecordingNotifier]; this just reads it back with a type.
RecordingNotifier notifierOf(ProviderContainer container) =>
    container.read(appNotifierProvider) as RecordingNotifier;
