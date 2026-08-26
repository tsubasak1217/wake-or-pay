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
    // Recovery first: it settles sessions the safety valve wrote off and
    // switches their one-shot alarms back off, which the reschedule pass would
    // otherwise arm again for tomorrow.
    await resumePendingSession();
    await rescheduleAll();
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
  ///
  /// A ringing alarm is left strictly alone: `Alarm.set` replaces an alarm with
  /// the same id, so the startup reschedule would otherwise silence a ring the
  /// user is standing in front of and re-arm it for tomorrow.
  Future<void> schedule(domain.Alarm alarm, {DateTime? from}) async {
    final action = scheduleActionFor(
      enabled: alarm.enabled,
      isRinging: await pkg.Alarm.isRinging(platformAlarmId(alarm.id)),
    );

    switch (action) {
      case ScheduleAction.skipRinging:
        return;
      case ScheduleAction.cancel:
        await cancel(alarm);
      case ScheduleAction.schedule:
        final fireAt = nextFireTime(alarm, from ?? DateTime.now());
        await pkg.Alarm.set(alarmSettings: buildAlarmSettings(alarm, fireAt));
    }
  }

  Future<void> cancel(domain.Alarm alarm) =>
      pkg.Alarm.stop(platformAlarmId(alarm.id));

  Future<void> rescheduleAll({DateTime? from}) async {
    for (final alarm in await _ref.read(alarmRepositoryProvider).getAll()) {
      await schedule(alarm, from: from);
    }
  }

  /// Stops the platform alarm once the wake check has been cleared.
  Future<void> stopRinging(domain.Alarm alarm) => _afterRing(alarm);

  /// What happens to an alarm once one of its rings is over, however it ended —
  /// cleared by the user, or written off by the 60 minute safety valve. One
  /// rule, so the dismiss path and the recovery path cannot drift apart.
  Future<void> _afterRing(domain.Alarm alarm) async {
    await cancel(alarm);
    _handled.remove(alarm.id);

    if (alarm.repeatDays.isEmpty) {
      // A one-shot has done its job. Switching it off is also what stops the
      // next reschedule pass from arming it again for tomorrow.
      await _ref.read(alarmRepositoryProvider).setEnabled(alarm.id, false);
    } else {
      await schedule(alarm);
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
    // firedAt is the *scheduled* time, not now: ignoring the notification for
    // ten minutes must already have cost ten minutes' worth.
    final session = existing != null && existing.alarmId == alarmId
        ? existing
        : await _ref
              .read(sessionServiceProvider)
              .start(alarm: alarm, firedAt: settings.dateTime);

    _goRinging(session.id);
  }

  /// After a kill or a crash: put a still-live ring back on screen, or show the
  /// result of one the safety valve wrote off.
  Future<void> resumePendingSession({DateTime? now}) async {
    final outcome = await _ref
        .read(sessionServiceProvider)
        .recoverPending(now ?? DateTime.now());

    final alarms = _ref.read(alarmRepositoryProvider);
    for (final session in outcome.settled) {
      // Never touch the alarm behind a ring that is still live, even if an
      // older session of the same alarm was just written off.
      if (session.alarmId == outcome.resumed?.alarmId) continue;
      final alarm = await alarms.getById(session.alarmId);
      if (alarm != null) await _afterRing(alarm);
    }

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
