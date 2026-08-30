import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_controller.dart';
import '../../app/router.dart';
import '../../data/providers.dart';
import '../../services/alarm_service.dart';
import '../../services/background_dispatch.dart';
import '../../services/lock_screen.dart';

final ringingControllerProvider = Provider(RingingController.new);

/// The one and only exit from a ring: settle the session, stop the platform
/// alarm, show the result.
class RingingController {
  RingingController(this._ref);

  final Ref _ref;

  Future<void> dismiss(String sessionId, {DateTime? now}) async {
    final session = await _ref
        .read(alarmSessionRepositoryProvider)
        .getById(sessionId);
    if (session == null) return;

    final settled = await _ref
        .read(sessionServiceProvider)
        .dismiss(session, now ?? DateTime.now());

    // Spec 11.7: the morning is over, so the trigger Android is holding for
    // this session has to go. Cancelled even when the alarm behind it has been
    // deleted — the booking is keyed on the session, not the alarm.
    await _ref.read(oversleepBackgroundSchedulerProvider).cancel(session);

    final alarm = await _ref
        .read(alarmRepositoryProvider)
        .getById(session.alarmId);
    if (alarm != null) {
      await _ref.read(alarmServiceProvider).stopRinging(alarm);
    }

    // The morning is over, so the app stops being allowed over the keyguard:
    // otherwise the flag [RingingScreen] raised would stay up for the rest of
    // the process, and the next time the phone slept with the app open the
    // lock screen would show the app.
    await _ref.read(lockScreenVisibilityProvider).setShowWhenLocked(false);

    _ref.invalidate(sessionByIdProvider(sessionId));
    // A success paid XP straight into shared_preferences, behind the cached
    // profile the header is painted from — so drop the cache rather than let
    // the level go stale until the next launch.
    _ref.invalidate(profileProvider);
    _ref.read(appRouterProvider).go(AppRoute.result(settled.id));
  }

  /// The other way off this screen — and the only one that leaves the morning
  /// unfinished. The session stays open; [AlarmService.snooze] moves the ring
  /// and sends the user Home.
  Future<void> snooze(String sessionId, {DateTime? now}) async {
    // Same as [dismiss]: the ring screen is going away, so the permission to
    // draw over the keyguard goes with it. The re-ring raises it again.
    await _ref.read(lockScreenVisibilityProvider).setShowWhenLocked(false);
    await _ref.read(alarmServiceProvider).snooze(sessionId, now: now);
  }
}
