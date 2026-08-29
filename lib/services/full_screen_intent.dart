import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `USE_FULL_SCREEN_INTENT` — the permission that decides whether a ring can
/// reach a sleeping phone at all.
///
/// Android 14 stopped granting it on install to anything the store has not
/// classified as a clock or a calling app, and a sideloaded APK is never
/// classified. Declaring it in the manifest buys nothing on its own: when it is
/// denied the system quietly strips the full-screen intent off the alarm's
/// notification and posts an ordinary heads-up instead. The alarm sounds, the
/// screen stays dark, and no error is reported anywhere — which is exactly what
/// build 106 did on the reporter's Pixel (`appops` showed
/// `USE_FULL_SCREEN_INTENT: deny`, and every posted record had
/// `fullscreenIntent=null`).
///
/// Only the user can grant it, from one system toggle, so all this can do is
/// notice and take them there.
///
/// An interface so tests never reach a platform channel.
abstract class FullScreenIntentPermission {
  /// True on Android 13 and below, where the permission is granted on install.
  Future<bool> isGranted();

  /// Opens the system's 「全画面通知」 toggle for this app.
  Future<void> openSettings();
}

/// Whether to send the user to the system toggle right now. Pure.
///
/// Never while an alarm is ringing: the app may well have been cold-launched by
/// tapping the ring notification, and throwing a Settings screen over the
/// ringing screen would take away the only way to stop the alarm.
bool shouldAskForFullScreenIntent({
  required bool granted,
  required bool ringing,
}) => !granted && !ringing;

/// Checks the permission and, when it is missing, opens the toggle. Returns
/// whether it is granted.
///
/// Asked again on every cold start until it is granted — deliberately. An
/// alarm that cannot turn the screen on is not a smaller alarm, it is not an
/// alarm; and the moment the user grants it this stops happening forever.
Future<bool> ensureFullScreenIntent(
  FullScreenIntentPermission permission, {
  required bool ringing,
}) async {
  final granted = await permission.isGranted();
  if (!shouldAskForFullScreenIntent(granted: granted, ringing: ringing)) {
    return granted;
  }
  await permission.openSettings();
  return false;
}

/// Records instead of touching the platform. The default, so every test runs
/// without a platform under it — and granted, so no test ever takes the
/// settings path by accident.
class RecordingFullScreenIntentPermission implements FullScreenIntentPermission {
  RecordingFullScreenIntentPermission({this.granted = true});

  final bool granted;
  int checks = 0;
  int settingsOpened = 0;

  @override
  Future<bool> isGranted() async {
    checks++;
    return granted;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// The real thing: the `wake_or_pay/full_screen_intent` channel on
/// [MainActivity].
class PlatformFullScreenIntentPermission implements FullScreenIntentPermission {
  const PlatformFullScreenIntentPermission({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'wake_or_pay/full_screen_intent';

  final MethodChannel _channel;

  /// A channel failure answers "granted". The only thing a false alarm here
  /// could do is drop the user into a Settings screen they did not need, on
  /// every start, with no way to make it stop.
  @override
  Future<bool> isGranted() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _channel.invokeMethod<bool>('isGranted') ?? true;
    } on Object catch (e) {
      debugPrint('full screen intent check failed: $e');
      return true;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } on Object catch (e) {
      debugPrint('full screen intent settings failed: $e');
    }
  }
}

/// Overridden in `main()` with the real one; every test keeps the recorder.
final fullScreenIntentPermissionProvider = Provider<FullScreenIntentPermission>(
  (ref) => RecordingFullScreenIntentPermission(),
);

Override platformFullScreenIntentOverride() =>
    fullScreenIntentPermissionProvider.overrideWithValue(
      const PlatformFullScreenIntentPermission(),
    );
