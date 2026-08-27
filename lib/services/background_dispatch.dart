import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers.dart';
import '../domain/models.dart';
import '../domain/oversleep_contact_rules.dart';
import 'app_notifier.dart';
import 'oversleep_notifier.dart';
import 'phone_caller.dart';
import 'secret_store.dart';
import 'sms_sender.dart';

/// Firing the oversleep contact **while the app is not running** — spec 11.7.
///
/// The ringing screen can only send while it is on screen, and the whole point
/// of this feature is the morning where the user swiped the app away and went
/// back to sleep. So the trigger time is also booked with Android's own
/// `AlarmManager`, which starts a second Flutter engine and runs
/// [oversleepAlarmCallback] in an isolate of its own.
///
/// Both paths race for the same session, and the loser does nothing at all:
/// the dispatcher claims one row per session before it sends anything. See
/// `ContactEventRepository.claim`.

/// The key the trigger's parameters travel under.
const oversleepSessionIdParam = 'sessionId';

/// The `AlarmManager` id for [sessionId]. Pure.
///
/// Must be stable — cancelling and rescheduling has to find the same booking —
/// and must fit in 32 bits, which the plugin asserts. `hashCode` is stable
/// within a run but **not** across runs of the VM for strings in Dart, so this
/// is a fixed FNV-1a instead: an id computed today has to still match the one
/// computed after a reboot, or a dismissed alarm could never be cancelled.
int backgroundAlarmId(String sessionId) {
  var hash = 0x811c9dc5;
  for (final unit in sessionId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  // Never 0: the plugin treats every id the same, but a 0 in a log is
  // indistinguishable from "no id at all".
  return hash == 0 ? 1 : hash;
}

/// How the app books an exact one-shot with Android. An interface so the
/// scheduling arithmetic can be tested without a platform under it.
abstract class ExactAlarmScheduler {
  Future<bool> oneShotAt(
    DateTime at,
    int id, {
    required Map<String, dynamic> params,
  });

  Future<bool> cancel(int id);
}

/// `android_alarm_manager_plus`.
class AndroidExactAlarmScheduler implements ExactAlarmScheduler {
  const AndroidExactAlarmScheduler();

  @override
  Future<bool> oneShotAt(
    DateTime at,
    int id, {
    required Map<String, dynamic> params,
  }) async {
    try {
      return await AndroidAlarmManager.oneShotAt(
        at,
        id,
        oversleepAlarmCallback,
        // Exact and wakeup, because a contact that goes out when the phone
        // next happens to wake up is a contact that goes out at lunchtime.
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
        params: params,
      );
    } on Object catch (e) {
      debugPrint('background trigger not booked: $e');
      return false;
    }
  }

  @override
  Future<bool> cancel(int id) async {
    try {
      return await AndroidAlarmManager.cancel(id);
    } on Object catch (e) {
      debugPrint('background trigger not cancelled: $e');
      return false;
    }
  }
}

/// Books nothing and remembers everything. The default, so a test cannot leave
/// a real alarm booked on the machine running it.
class RecordingExactAlarmScheduler implements ExactAlarmScheduler {
  final booked = <({DateTime at, int id, Map<String, dynamic> params})>[];
  final cancelled = <int>[];

  @override
  Future<bool> oneShotAt(
    DateTime at,
    int id, {
    required Map<String, dynamic> params,
  }) async {
    booked.add((at: at, id: id, params: params));
    return true;
  }

  @override
  Future<bool> cancel(int id) async {
    cancelled.add(id);
    return true;
  }
}

final exactAlarmSchedulerProvider = Provider<ExactAlarmScheduler>(
  (ref) => RecordingExactAlarmScheduler(),
);

Override androidExactAlarmSchedulerOverride() => exactAlarmSchedulerProvider
    .overrideWithValue(const AndroidExactAlarmScheduler());

/// Keeps the background trigger in step with a live session.
///
/// Booked when a ring opens a session, moved when a snooze moves the clock it
/// is counted from, and cancelled the moment the morning ends — a trigger left
/// behind would wake a dead session up and find nothing to do, which is
/// harmless but pointless, and on a repeating alarm it would collide with
/// tomorrow's booking.
class OversleepBackgroundScheduler {
  const OversleepBackgroundScheduler(this._scheduler);

  final ExactAlarmScheduler _scheduler;

  /// Books — or re-books — the trigger for [session], or cancels it when this
  /// alarm tells nobody.
  Future<void> sync({required Alarm alarm, required AlarmSession session}) {
    final at = contactTriggerAt(session, alarm);
    if (at == null || !session.isRinging) return cancel(session);
    return _scheduler
        .oneShotAt(
          at,
          backgroundAlarmId(session.id),
          params: {oversleepSessionIdParam: session.id},
        )
        .then((_) {});
  }

  Future<void> cancel(AlarmSession session) =>
      _scheduler.cancel(backgroundAlarmId(session.id)).then((_) {});
}

final oversleepBackgroundSchedulerProvider = Provider(
  (ref) => OversleepBackgroundScheduler(ref.watch(exactAlarmSchedulerProvider)),
);

/// What Android runs at the trigger time, in an isolate of its own.
///
/// A top-level function annotated for the VM, because the callback is resolved
/// by handle after a cold start and a closure could not be found.
///
/// Everything it needs is built here from scratch: this isolate shares nothing
/// with the UI's — not the provider container, not the open database, not the
/// loaded preferences. The one thing it does share is the sqlite **file**, and
/// that is exactly what makes the once-per-session claim work.
@pragma('vm:entry-point')
Future<void> oversleepAlarmCallback(int id, Map<String, dynamic> params) async {
  // Required before any plugin channel is touched from a background isolate.
  WidgetsFlutterBinding.ensureInitialized();

  final sessionId = params[oversleepSessionIdParam] as String?;
  if (sessionId == null || sessionId.isEmpty) {
    debugPrint('background trigger $id had no session id');
    return;
  }

  final container = await backgroundContainer();
  try {
    await runBackgroundDispatch(container, sessionId, DateTime.now());
  } on Object catch (e, stack) {
    // Nothing above this catches: a throw here takes the isolate down with no
    // trace anybody will ever read.
    debugPrint('background dispatch failed: $e\n$stack');
  } finally {
    container.dispose();
  }
}

/// The container the background isolate runs on.
///
/// The senders are the real ones — an SMS and a mail are exactly what this
/// exists to send — except the phone, which is [UnavailablePhoneCaller]:
/// `ACTION_CALL` needs a foreground Activity and there is not one, so the log
/// says the call was skipped rather than pretending it was placed.
@visibleForTesting
Future<ProviderContainer> backgroundContainer() async => ProviderContainer(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(
      await SharedPreferences.getInstance(),
    ),
    flutterSecureStoreOverride(),
    platformSmsSenderOverride(),
    phoneCallerProvider.overrideWithValue(const UnavailablePhoneCaller()),
    localAppNotifierOverride(),
  ],
);

/// Loads the session, checks it is still worth notifying about, and runs the
/// same dispatcher the ringing screen does.
///
/// Split out from [oversleepAlarmCallback] so it can be driven by a test with
/// an in-memory container: everything above it is plugin plumbing that no test
/// can stand up.
@visibleForTesting
Future<ContactEvent?> runBackgroundDispatch(
  ProviderContainer container,
  String sessionId,
  DateTime now,
) async {
  final session = await container
      .read(alarmSessionRepositoryProvider)
      .getById(sessionId);
  // Dismissed, snoozed past the valve, or simply never there: the trigger is
  // stale and the morning is over.
  if (session == null || !session.isRinging) return null;

  final alarm = await container
      .read(alarmRepositoryProvider)
      .getById(session.alarmId);
  if (alarm == null) return null;

  return container
      .read(contactDispatcherProvider)
      .fireIfDue(alarm: alarm, session: session, now: now);
}
