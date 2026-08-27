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
import '../domain/snooze_rules.dart';
import 'alarm_settings_builder.dart';
import 'app_notifier.dart';
import 'oversleep_notifier.dart';
import 'phone_caller.dart';
import 'session_service.dart';

final sessionServiceProvider = Provider(
  (ref) => SessionService(
    ref.watch(alarmSessionRepositoryProvider),
    ref.watch(walletRepositoryProvider),
    ref.watch(ojisanRepositoryProvider),
    ref.watch(profileRepositoryProvider),
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
  StreamSubscription<bool>? _callSub;
  final _handled = <String>{};

  /// The alarms silenced for the duration of an oversleep call, waiting to be
  /// started again when it ends. See [_onCallStateChanged].
  final _silencedByCall = <String>{};

  Future<void> init() async {
    await pkg.Alarm.init();

    _ringingSub = pkg.Alarm.ringing.listen(_onRinging);
    _ref.onDispose(() => _ringingSub?.cancel());
    watchCalls();

    await requestPermissions();
    // Recovery first: it settles sessions the safety valve wrote off and
    // switches their one-shot alarms back off, which the reschedule pass would
    // otherwise arm again for tomorrow.
    await resumePendingSession();
    await rescheduleAll();
  }

  /// Silences the ring while an oversleep call is up, and brings it back when
  /// the call ends — spec 11.5.
  ///
  /// The whole point of the call is that the contact's voice comes out of the
  /// speaker; an alarm going off over it defeats it entirely.
  ///
  /// **The `alarm` plugin has no pause.** Its API is `set` / `stop`, so this
  /// stops the platform alarm and sets the same one again afterwards, one
  /// second out, with the same id and payload. The re-ring lands in
  /// [_handleRing] and finds the alarm already in [_handled], so it makes
  /// noise without opening a second session or navigating anywhere.
  ///
  /// Public so a test can drive it without a platform behind `init`.
  void watchCalls() {
    _callSub = _ref
        .read(phoneCallerProvider)
        .inCall
        .listen(_onCallStateChanged);
    _ref.onDispose(() => _callSub?.cancel());
  }

  Future<void> _onCallStateChanged(bool inCall) async {
    final sessions = await _ref
        .read(alarmSessionRepositoryProvider)
        .getRingingAll();

    final alarms = _ref.read(alarmRepositoryProvider);

    if (inCall) {
      for (final session in sessions) {
        // A snoozed session is already silent; stopping and re-arming it here
        // would move its re-ring to the moment the call ended.
        if (isSnoozePending(session, DateTime.now())) continue;
        final alarm = await alarms.getById(session.alarmId);
        if (alarm == null) continue;
        _silencedByCall.add(alarm.id);
        await cancel(alarm);
      }
      return;
    }

    if (_silencedByCall.isEmpty) return;
    for (final alarmId in _silencedByCall.toList()) {
      // Only if the morning is still unfinished: dismissing during the call is
      // exactly the outcome this feature is trying to cause, and it must not
      // be answered by starting the alarm up again.
      final live = sessions.any((s) => s.alarmId == alarmId);
      final alarm = await alarms.getById(alarmId);
      if (live && alarm != null) {
        await setRingAt(alarm, DateTime.now().add(const Duration(seconds: 1)));
      }
      _silencedByCall.remove(alarmId);
    }
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

  /// Arms [alarm] to ring again at [ringAt] — the snooze re-ring.
  ///
  /// Same platform id and same payload as the ring it replaces, so the re-ring
  /// lands in [_handleRing] and finds the session that is already open.
  Future<void> setRingAt(domain.Alarm alarm, DateTime ringAt) =>
      pkg.Alarm.set(alarmSettings: buildAlarmSettings(alarm, ringAt));

  /// Alarms with a snoozed session waiting to come back.
  ///
  /// The reschedule pass has to skip these: their platform alarm is armed for
  /// the re-ring, and `Alarm.set` replaces an alarm with the same id, so a
  /// blind pass would quietly move a 7:05 re-ring to tomorrow morning.
  Future<Set<String>> _snoozePendingAlarmIds(DateTime now) async {
    final ringing = await _ref
        .read(alarmSessionRepositoryProvider)
        .getRingingAll();
    return {
      for (final session in ringing)
        if (isSnoozePending(session, now)) session.alarmId,
    };
  }

  Future<void> rescheduleAll({DateTime? from}) async {
    final now = from ?? DateTime.now();
    final snoozing = await _snoozePendingAlarmIds(now);
    for (final alarm in await _ref.read(alarmRepositoryProvider).getAll()) {
      if (snoozing.contains(alarm.id)) continue;
      await schedule(alarm, from: from);
    }
  }

  /// The user pressed スヌーズ.
  ///
  /// Records the press, moves the ring, and hands the screen back to Home. The
  /// session stays `ringing` throughout: it is the same morning, and it is
  /// still costing money under the default clock mode.
  Future<domain.AlarmSession?> snooze(String sessionId, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final sessions = _ref.read(alarmSessionRepositoryProvider);

    final session = await sessions.getById(sessionId);
    if (session == null || !session.isRinging) return null;

    final alarm = await _ref
        .read(alarmRepositoryProvider)
        .getById(session.alarmId);
    if (alarm == null || !canSnoozeNow(alarm, session)) return null;

    final snoozed = applySnooze(session, at, alarm.snooze!);
    await sessions.save(snoozed);
    _ref.invalidate(sessionByIdProvider(sessionId));

    // Silence this ring, then arm the next one. Dropping the id from _handled
    // is what lets the re-ring through — without it the second ring of the
    // same alarm would be swallowed as a duplicate.
    await cancel(alarm);
    _handled.remove(alarm.id);
    await setRingAt(alarm, snoozed.currentRingAt);

    final text = snoozeNotificationText(snoozed.currentRingAt);
    await _ref
        .read(appNotifierProvider)
        .show(
          id: snoozeNotificationId(platformAlarmId(alarm.id)),
          title: text.title,
          body: text.body,
        );

    _ref.read(appRouterProvider).go(AppRoute.home);
    return snoozed;
  }

  /// Stops the platform alarm once the wake check has been cleared.
  Future<void> stopRinging(domain.Alarm alarm) => _afterRing(alarm);

  /// What happens to an alarm once one of its rings is over, however it ended —
  /// cleared by the user, or written off by the 60 minute safety valve. One
  /// rule, so the dismiss path and the recovery path cannot drift apart.
  Future<void> _afterRing(domain.Alarm alarm) async {
    await cancel(alarm);
    _handled.remove(alarm.id);
    // Whatever the morning cost, the "snoozing until 7:05" line is now a lie.
    await _ref
        .read(appNotifierProvider)
        .cancel(snoozeNotificationId(platformAlarmId(alarm.id)));

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

    // A ring we already opened a session for must not start a second one —
    // a relaunch mid-ring, and now also a snooze coming back. Asked per alarm,
    // because with a second alarm snoozing in the background the newest
    // ringing session is not necessarily this alarm's.
    final sessions = _ref.read(alarmSessionRepositoryProvider);
    final existing = await sessions.getRingingForAlarm(alarmId);
    // firedAt is the *scheduled* time, not now: ignoring the notification for
    // ten minutes must already have cost ten minutes' worth.
    final session =
        existing ??
        await _ref
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
    final live = {
      outcome.resumed?.alarmId,
      for (final s in outcome.snoozing) s.alarmId,
    };

    for (final session in outcome.settled) {
      // Never touch the alarm behind a ring that is still live — resumed or
      // snoozed — even if an older session of the same alarm was written off.
      if (live.contains(session.alarmId)) continue;
      final alarm = await alarms.getById(session.alarmId);
      if (alarm != null) await _afterRing(alarm);
    }

    // A snooze survives a kill: re-arm the re-ring rather than resuming the
    // screen. Setting it again is harmless if the platform kept it, and is the
    // only thing that brings it back if it did not.
    for (final session in outcome.snoozing) {
      final alarm = await alarms.getById(session.alarmId);
      if (alarm == null) continue;
      _handled.remove(alarm.id);
      await setRingAt(alarm, session.currentRingAt);
      // Under 「規定時刻から加算し続ける」 the contact timer does not stop for a
      // snooze, so it can come due while the ring screen is closed. This
      // catches it whenever the app is running; the re-ring catches the rest.
      await _ref
          .read(contactDispatcherProvider)
          .fireIfDue(
            alarm: alarm,
            session: session,
            now: now ?? DateTime.now(),
          );
      final text = snoozeNotificationText(session.currentRingAt);
      await _ref
          .read(appNotifierProvider)
          .show(
            id: snoozeNotificationId(platformAlarmId(alarm.id)),
            title: text.title,
            body: text.body,
          );
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
