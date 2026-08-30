import 'dart:async';

import 'package:alarm/alarm.dart' as pkg;
import 'package:alarm/utils/alarm_set.dart' as pkg;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/profile_controller.dart';
import '../app/router.dart';
import '../data/providers.dart';
import '../domain/loss_calculator.dart';
import '../domain/models.dart' as domain;
import '../domain/schedule.dart';
import '../domain/snooze_rules.dart';
import 'alarm_settings_builder.dart';
import 'background_dispatch.dart';
import 'card_hostage.dart';
import 'full_screen_intent.dart';
import 'lock_screen.dart';
import 'oversleep_notifier.dart';
import 'session_service.dart';
import 'snooze_service.dart';

final sessionServiceProvider = Provider(
  (ref) => SessionService(
    ref.watch(alarmSessionRepositoryProvider),
    ref.watch(walletRepositoryProvider),
    ref.watch(ojisanRepositoryProvider),
    ref.watch(profileRepositoryProvider),
    ref.watch(pendingChargeRepositoryProvider),
    // Read, not watched: the question is only ever asked at settle time, and
    // the answer must be the state of the card *then* — not the state this
    // provider was last rebuilt at.
    isCardRegistered: () => ref.read(cardHostageProvider).card != null,
    clock: ref.watch(clockProvider),
  ),
);

final alarmServiceProvider = Provider((ref) => AlarmService(ref));

/// How long `main()` is willing to hold the first frame while it asks whether
/// the phone is already ringing. Past this the app opens normally and the ring
/// arrives through [AlarmService.init] instead — late is bad, never is worse.
const _launchProbeTimeout = Duration(seconds: 5);

/// Wraps the `alarm` plugin: turns [domain.Alarm] models into scheduled
/// platform alarms, and turns a ring into an [domain.AlarmSession] plus a jump
/// to the ringing screen.
class AlarmService {
  AlarmService(this._ref);

  final Ref _ref;
  StreamSubscription<pkg.AlarmSet>? _ringingSub;
  StreamSubscription<String>? _dismissSub;
  final _handled = <String>{};

  Future<void> init() async {
    await pkg.Alarm.init();

    _ringingSub = pkg.Alarm.ringing.listen(_onRinging);
    _ref.onDispose(() => _ringingSub?.cancel());

    // 解除 from the スヌーズ中 notification, when the app was already alive.
    _dismissSub = _ref
        .read(snoozeForegroundServiceProvider)
        .dismissRequests
        .listen((sessionId) => unawaited(_onSnoozeDismissRequested(sessionId)));
    _ref.onDispose(() => _dismissSub?.cancel());

    await requestPermissions();
    // Recovery first: it settles sessions the safety valve wrote off and
    // switches their one-shot alarms back off, which the reschedule pass would
    // otherwise arm again for tomorrow.
    await resumePendingSession();
    await rescheduleAll();
    // Last: a cold start caused by tapping 解除 on the スヌーズ中 notification.
    await _consumeLaunchDismiss();
  }

  /// The user pressed 解除 on the スヌーズ中 notification while the app was alive.
  Future<void> _onSnoozeDismissRequested(String sessionId) async {
    await dismissSnoozed(sessionId);
    // The settlement is done; the routing is a courtesy that must not be able
    // to undo it, so it comes after and is never awaited against it.
    _ref.invalidate(profileProvider);
    _ref.read(appRouterProvider).go(AppRoute.result(sessionId));
  }

  /// The app was cold-launched by 解除: settle, then land on the result.
  Future<void> _consumeLaunchDismiss() async {
    final sessionId = await _ref
        .read(snoozeForegroundServiceProvider)
        .consumeLaunchDismiss();
    if (sessionId == null) return;
    await dismissSnoozed(sessionId);
    _ref.invalidate(profileProvider);
    _ref.read(appRouterProvider).go(AppRoute.result(sessionId));
  }

  /// Notifications, exact alarms, and the full-screen intent.
  ///
  /// Without exact alarms Android 12+ may delay the ring, which for this app
  /// means silently failing to wake anyone. Without the full-screen intent
  /// (Android 14+, and denied by default for a sideloaded build) the ring
  /// sounds with the screen still off — see [ensureFullScreenIntent].
  Future<void> requestPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    await ensureFullScreenIntent(
      _ref.read(fullScreenIntentPermissionProvider),
      ringing: await pkg.Alarm.isRinging(),
    );
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

    // Under 「次に鳴る時刻を起点にし直す」 the trigger has just moved, so the booking
    // has to move with it. Re-booked unconditionally: the same id replaces the
    // old one, and working out whether it needed to move is more code than
    // just doing it.
    await _ref
        .read(oversleepBackgroundSchedulerProvider)
        .sync(alarm: alarm, session: snoozed);

    // Silence this ring, then arm the next one. Dropping the id from _handled
    // is what lets the re-ring through — without it the second ring of the
    // same alarm would be swallowed as a duplicate.
    await cancel(alarm);
    _handled.remove(alarm.id);
    await setRingAt(alarm, snoozed.currentRingAt);

    // The ongoing, actionable 「スヌーズ中」 notification, owned by the foreground
    // service (spec 12.1). Its body carries the loss so far so a glance reveals
    // the meter running; the service refreshes it while the snooze lasts.
    final text = snoozeNotificationText(
      snoozed.currentRingAt,
      loss: lossAt(at, snoozed),
    );
    await _ref
        .read(snoozeForegroundServiceProvider)
        .start(sessionId: snoozed.id, title: text.title, body: text.body);

    _ref.read(appRouterProvider).go(AppRoute.home);
    return snoozed;
  }

  /// The user got up during a snooze and cleared it early — spec 12.1.
  ///
  /// Runs the *same* settlement as clearing the wake check on the ring screen:
  /// [SessionService.dismiss] makes the session failed under the current rules
  /// with the loss frozen at [now]. On top of that it cancels the pending
  /// re-ring, cancels the background contact trigger (11.7), and takes the
  /// 「スヌーズ中」 notification down — the same three things a re-ring or a valve
  /// settlement would have done, brought forward to now.
  ///
  /// Idempotent, so the notification's 解除 and the Home row's button can both
  /// fire without charging twice: the settle guard in [SessionService.settle]
  /// is a no-op on an already-settled session, and the cancels below are all
  /// harmless to repeat. Returns the settled session, or null if there was no
  /// such session at all.
  Future<domain.AlarmSession?> dismissSnoozed(
    String sessionId, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final session = await _ref
        .read(alarmSessionRepositoryProvider)
        .getById(sessionId);
    if (session == null) return null;

    final settled = await _ref
        .read(sessionServiceProvider)
        .dismiss(session, at);

    // The morning is over: drop the trigger Android is holding for it (11.7),
    // keyed on the session so a deleted alarm is cancelled too.
    await _ref.read(oversleepBackgroundSchedulerProvider).cancel(session);

    // Stand the alarm itself down. _afterRing cancels the re-ring, removes the
    // 「スヌーズ中」 notification, clears the snooze-pending flag, and reschedules
    // or disables the alarm — exactly the path a cleared wake check takes.
    final alarm = await _ref
        .read(alarmRepositoryProvider)
        .getById(session.alarmId);
    if (alarm != null) {
      await _afterRing(alarm);
    } else {
      // The alarm was deleted out from under the snooze; _afterRing cannot run,
      // but the notification it would have taken down still has to go.
      await _ref.read(snoozeForegroundServiceProvider).stop();
    }

    _ref.invalidate(sessionByIdProvider(sessionId));
    return settled;
  }

  /// Stops the platform alarm once the wake check has been cleared.
  Future<void> stopRinging(domain.Alarm alarm) => _afterRing(alarm);

  /// What happens to an alarm once one of its rings is over, however it ended —
  /// cleared by the user, or written off by the 60 minute safety valve. One
  /// rule, so the dismiss path and the recovery path cannot drift apart.
  Future<void> _afterRing(domain.Alarm alarm) async {
    await cancel(alarm);
    _handled.remove(alarm.id);
    // Whatever the morning cost, the "snoozing until 7:05" line is now a lie —
    // stop the foreground service that was holding it.
    await _ref.read(snoozeForegroundServiceProvider).stop();

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
    final session = await _sessionForRing(settings);
    if (session == null) return;
    // A ring on a sleeping, locked phone has to be allowed over the keyguard.
    // Raised here rather than only on the ring screen so the flag is up before
    // the navigation, and lowered again by [RingingController].
    await _ref.read(lockScreenVisibilityProvider).setShowWhenLocked(true);
    _goRinging(session.id);
  }

  /// Everything a ring needs *except* putting it on screen: find or open the
  /// session, and book the background contact trigger for it.
  ///
  /// Split out so the pre-first-frame launch check ([launchRingingSessionId])
  /// and the live [pkg.Alarm.ringing] stream cannot disagree about what a ring
  /// means. Returns null when this ring is already handled or its alarm is gone.
  Future<domain.AlarmSession?> _sessionForRing(
    pkg.AlarmSettings settings,
  ) async {
    final alarmId = settings.payload;
    if (alarmId == null || !_handled.add(alarmId)) return null;

    final alarm = await _ref.read(alarmRepositoryProvider).getById(alarmId);
    if (alarm == null) return null;

    // A ring we already opened a session for must not start a second one —
    // a relaunch mid-ring, and now also a snooze coming back. Asked per alarm,
    // because with a second alarm snoozing in the background the newest
    // ringing session is not necessarily this alarm's.
    final sessions = _ref.read(alarmSessionRepositoryProvider);
    final existing = await sessions.getRingingForAlarm(alarmId);
    // A re-ring or a relaunch mid-ring: the snooze is over, so the スヌーズ中
    // foreground service has nothing left to hold.
    if (existing != null) {
      await _ref.read(snoozeForegroundServiceProvider).stop();
    }
    // firedAt is the *scheduled* time, not now: ignoring the notification for
    // ten minutes must already have cost ten minutes' worth.
    final session =
        existing ??
        await _ref
            .read(sessionServiceProvider)
            .start(alarm: alarm, firedAt: settings.dateTime);

    // Spec 11.7: book the trigger with Android as well, so the contact still
    // goes out on the morning this screen gets swiped away.
    await _ref
        .read(oversleepBackgroundSchedulerProvider)
        .sync(alarm: alarm, session: session);

    return session;
  }

  /// The session the app must already be showing when its first frame is
  /// painted, or null to open on the alarm tab as usual.
  ///
  /// Called from `main()` before `runApp`, which is the whole point: a
  /// full-screen intent launch that navigates *after* the first frame paints
  /// the home tab over the lock screen first. Two questions, cheapest first:
  ///
  /// * the database — a ring this app already opened a session for and was
  ///   killed in the middle of. Snoozed sessions are silent and are left to
  ///   [resumePendingSession]; so is anything the 60 minute valve has already
  ///   written off.
  /// * the plugin — a cold launch by the ring itself, where no Dart code has
  ///   heard about it yet. The session is opened here, through the same path
  ///   the live ring stream uses, and the id is remembered so the stream event
  ///   that follows does not open a second one.
  ///
  /// Never throws and never hangs the launch: anything that goes wrong, or
  /// takes longer than [_launchProbeTimeout], means the app opens where it
  /// always did and [init] sorts the ring out a frame later.
  Future<String?> launchRingingSessionId() async {
    try {
      return await _launchRingingSessionId().timeout(_launchProbeTimeout);
    } on Object catch (e) {
      debugPrint('launch ring probe failed: $e');
      return null;
    }
  }

  Future<String?> _launchRingingSessionId() async {
    final now = DateTime.now();
    final open =
        [
          for (final session in await _ref
              .read(alarmSessionRepositoryProvider)
              .getRingingAll())
            if (!isSnoozePending(session, now) &&
                recoverSession(session, now).isRinging)
              session,
        ]..sort((a, b) => b.firedAt.compareTo(a.firedAt));
    if (open.isNotEmpty) {
      _handled.add(open.first.alarmId);
      return open.first.id;
    }

    // Idempotent, and [init] calls it again in a moment: it is what makes the
    // plugin's storage readable at all.
    await pkg.Alarm.init();
    if (!await pkg.Alarm.isRinging()) return null;

    for (final settings in await pkg.Alarm.getAlarms()) {
      if (!await pkg.Alarm.isRinging(settings.id)) continue;
      final session = await _sessionForRing(settings);
      if (session != null) return session.id;
    }
    return null;
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
      // The morning is over however it ended, so the background trigger has
      // nothing left to fire about.
      await _ref.read(oversleepBackgroundSchedulerProvider).cancel(session);
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
      // Same for the background trigger: a reboot loses the booking, and this
      // is the pass that notices.
      await _ref
          .read(oversleepBackgroundSchedulerProvider)
          .sync(alarm: alarm, session: session);
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
      final text = snoozeNotificationText(
        session.currentRingAt,
        loss: lossAt(now ?? DateTime.now(), session),
      );
      await _ref
          .read(snoozeForegroundServiceProvider)
          .start(sessionId: session.id, title: text.title, body: text.body);
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
