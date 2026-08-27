import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../data/providers.dart';
import '../../services/alarm_service.dart';

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

    final alarm = await _ref
        .read(alarmRepositoryProvider)
        .getById(session.alarmId);
    if (alarm != null) {
      await _ref.read(alarmServiceProvider).stopRinging(alarm);
    }

    _ref.invalidate(sessionByIdProvider(sessionId));
    _ref.read(appRouterProvider).go(AppRoute.result(settled.id));
  }

  /// The other way off this screen — and the only one that leaves the morning
  /// unfinished. The session stays open; [AlarmService.snooze] moves the ring
  /// and sends the user Home.
  Future<void> snooze(String sessionId, {DateTime? now}) =>
      _ref.read(alarmServiceProvider).snooze(sessionId, now: now);
}
