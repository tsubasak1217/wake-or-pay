import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The plain notifications the app posts outside of a ring: 「スヌーズ中 7:05 に再鳴動」
/// and the oversleep contact log line.
///
/// An interface so tests can watch what was posted without a platform, and so
/// a failure to post never becomes a failure to snooze.
abstract class AppNotifier {
  /// Posts (or replaces) the notification with [id].
  Future<void> show({
    required int id,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);
}

/// Records instead of posting. Used in tests, and on any platform where the
/// plugin is not wired up.
class RecordingNotifier implements AppNotifier {
  final posted = <({int id, String title, String body})>[];
  final cancelled = <int>[];

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async => posted.add((id: id, title: title, body: body));

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

/// Wraps [inner] so a plugin failure can never take a ring down with it.
///
/// Posting a notification is a courtesy; snoozing, and settling the session
/// behind it, is not. Anything the plugin throws is swallowed here rather than
/// halfway through [AlarmService.snooze].
class SafeNotifier implements AppNotifier {
  const SafeNotifier(this.inner);

  final AppNotifier inner;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await inner.show(id: id, title: title, body: body);
    } on Object catch (e) {
      debugPrint('notification failed: $e');
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await inner.cancel(id);
    } on Object catch (e) {
      debugPrint('notification cancel failed: $e');
    }
  }
}

/// `flutter_local_notifications`, on its own channel.
///
/// Deliberately *not* the channel the `alarm` plugin rings on: these are quiet
/// status notes about a ring, not the ring itself, and a user who silences one
/// should not be silencing the other.
class LocalAppNotifier implements AppNotifier {
  LocalAppNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const channelId = 'wake_or_pay_status';
  static const channelName = 'アラームの状態';

  /// Idempotent, and awaited by every [show]: nothing else in the app has a
  /// natural place to call it, and initializing twice is harmless.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        // Resolved under res/drawable by the plugin, so it cannot be the
        // launcher icon in res/mipmap.
        android: AndroidInitializationSettings('ic_stat_notify'),
      ),
    );
    _initialized = true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'スヌーズ中や寝坊時連絡のお知らせ',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await ensureInitialized();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await ensureInitialized();
    await _plugin.cancel(id: id);
  }
}

/// Overridden in tests with a [RecordingNotifier], and in `main()` with the
/// real one — so widget tests never reach the plugin, and a plugin failure on
/// device is swallowed by [SafeNotifier] rather than aborting a snooze.
final appNotifierProvider = Provider<AppNotifier>((ref) => RecordingNotifier());

Override localAppNotifierOverride() =>
    appNotifierProvider.overrideWithValue(SafeNotifier(LocalAppNotifier()));

/// Notification ids. Kept away from [platformAlarmId]'s range — which is a hash
/// of the alarm id — by being small and fixed per purpose, combined with the
/// platform alarm id so two snoozed alarms do not overwrite each other.
int snoozeNotificationId(int platformAlarmId) =>
    (platformAlarmId % 100000) * 10 + 1;

int contactNotificationId(int platformAlarmId) =>
    (platformAlarmId % 100000) * 10 + 2;
