import 'dart:async';

import 'package:alarm/alarm.dart' as pkg;
import 'package:alarm/utils/alarm_set.dart' as pkg;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/router.dart';
import '../data/providers.dart';
import '../domain/models.dart' as domain;
import '../domain/schedule.dart';
import 'alarm_settings_builder.dart';
import 'session_service.dart';

final sessionServiceProvider = Provider(
  (ref) => SessionService(
    ref.watch(alarmSessionRepositoryProvider),
    ref.watch(walletRepositoryProvider),
    ref.watch(ojisanRepositoryProvider),
  ),
);

final alarmServiceProvider = Provider((ref) => AlarmService(ref));

/// Wraps the `alarm` plugin: turns [domain.Alarm] models into scheduled
/// platform alarms, and turns a ring into an [domain.AlarmSession] plus a jump
/// to the ringing screen.
class AlarmService {
  AlarmService(this._ref);

  final Ref _ref;
  StreamSubscription<pkg.AlarmSet>? _ringingSub;
  final _handled = <String>{};

  Future<void> init() async {
    await pkg.Alarm.init();

    _ringingSub = pkg.Alarm.ringing.listen(_onRinging);
    _ref.onDispose(() => _ringingSub?.cancel());

    await requestPermissions();
    await rescheduleAll();
    await resumePendingSession();
  }

  /// Notifications and exact alarms. Without the latter Android 12+ may delay
  /// the ring, which for this app means silently failing to wake anyone.
  Future<void> requestPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// Schedules [alarm] for its next occurrence, or cancels it when disabled.
  Future<void> schedule(domain.Alarm alarm, {DateTime? from}) async {
    if (!alarm.enabled) {
      await cancel(alarm);
      return;
    }
    final fireAt = nextFireTime(alarm, from ?? DateTime.now());
    await pkg.Alarm.set(alarmSettings: buildAlarmSettings(alarm, fireAt));
  }

  Future<void> cancel(domain.Alarm alarm) =>
      pkg.Alarm.stop(platformAlarmId(alarm.id));

  Future<void> rescheduleAll({DateTime? from}) async {
    for (final alarm in await _ref.read(alarmRepositoryProvider).getAll()) {
      await schedule(alarm, from: from);
    }
  }

  /// Stops the platform alarm once the wake check has been cleared, then
  /// re-arms a repeating alarm for its next day.
  Future<void> stopRinging(domain.Alarm alarm) async {
    await cancel(alarm);
    _handled.remove(alarm.id);
    if (alarm.repeatDays.isNotEmpty && alarm.enabled) {
      await schedule(alarm);
    } else {
      await _ref.read(alarmRepositoryProvider).setEnabled(alarm.id, false);
    }
  }

  void _onRinging(pkg.AlarmSet set) {
    for (final settings in set.alarms) {
      unawaited(_handleRing(settings));
    }
  }

  Future<void> _handleRing(pkg.AlarmSettings settings) async {
    final alarmId = settings.payload;
    if (alarmId == null || !_handled.add(alarmId)) return;

    final alarm = await _ref.read(alarmRepositoryProvider).getById(alarmId);
    if (alarm == null) return;

    // A ring we already opened a session for (a relaunch mid-ring) must not
    // start a second one.
    final sessions = _ref.read(alarmSessionRepositoryProvider);
    final existing = await sessions.getRinging();
    final session = existing != null && existing.alarmId == alarmId
        ? existing
        : await _ref
              .read(sessionServiceProvider)
              .start(alarm: alarm, firedAt: DateTime.now());

    _goRinging(session.id);
  }

  /// After a kill or a crash: put a still-live ring back on screen, or show the
  /// result of one the safety valve wrote off.
  Future<void> resumePendingSession({DateTime? now}) async {
    final outcome = await _ref
        .read(sessionServiceProvider)
        .recoverPending(now ?? DateTime.now());

    if (outcome.resumed != null) {
      _handled.add(outcome.resumed!.alarmId);
      _goRinging(outcome.resumed!.id);
    } else if (outcome.settled.isNotEmpty) {
      _ref
          .read(appRouterProvider)
          .go(AppRoute.result(outcome.settled.first.id));
    }
  }

  void _goRinging(String sessionId) =>
      _ref.read(appRouterProvider).go(AppRoute.ringing(sessionId));
}
