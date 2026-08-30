import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this app may draw **over the lock screen**.
///
/// A ringing alarm has to: the whole point of the app is that a full-screen
/// intent lands on a sleeping, locked phone and the ring screen comes up
/// anyway. But `showWhenLocked` is a property of the activity, not of the
/// screen that happens to be on it, so leaving it on forever means the *app*
/// shows over the lock screen — put the phone to sleep with the alarm list
/// open, press power again, and there are your alarms instead of the keyguard.
/// That is the bug this exists to fix.
///
/// So the flag is switched: on when a session starts ringing, off the moment
/// the morning is settled, snoozed or dismissed, and off once at startup when
/// nothing is ringing — the last one because [MainActivity.onCreate] still
/// sets it before the first frame (a cold launch from the full-screen intent
/// needs it *then*, and Dart is not running yet to be asked).
///
/// An interface so tests never reach a platform channel.
abstract class LockScreenVisibility {
  /// Never throws: this decides how a window is drawn, and no failure of it is
  /// worth taking the app down for.
  Future<void> setShowWhenLocked(bool show);
}

/// Records instead of touching the platform. The default, so every test runs
/// without a platform under it.
class RecordingLockScreenVisibility implements LockScreenVisibility {
  /// Every call, in order — including repeats, which are meaningful: the
  /// native side is idempotent, and a test that wants the sequence should see
  /// what was actually asked for.
  final calls = <bool>[];

  @override
  Future<void> setShowWhenLocked(bool show) async => calls.add(show);
}

/// The real thing: the `wake_or_pay/lock_screen` channel on [MainActivity].
class PlatformLockScreenVisibility implements LockScreenVisibility {
  const PlatformLockScreenVisibility({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'wake_or_pay/lock_screen';

  final MethodChannel _channel;

  @override
  Future<void> setShowWhenLocked(bool show) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('setShowWhenLocked', {'show': show});
    } on Object catch (e) {
      // Swallowed on purpose. Failing to *raise* the flag costs a ring that
      // stays behind the keyguard; failing to lower it costs a lock screen
      // showing the app. Neither is worth an exception escaping into a build
      // or a settle path.
      debugPrint('lock screen visibility failed: $e');
    }
  }
}

/// Overridden in `main()` with the real one; every test keeps the recorder.
final lockScreenVisibilityProvider = Provider<LockScreenVisibility>(
  (ref) => RecordingLockScreenVisibility(),
);

Override platformLockScreenOverride() =>
    lockScreenVisibilityProvider.overrideWithValue(
      const PlatformLockScreenVisibility(),
    );
