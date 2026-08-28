import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The ongoing 「スヌーズ中」 notification while a snooze is pending — spec 12.1,
/// as amended: a **foreground service** owns it, not a plain notification.
///
/// The service is the reliable mechanism the plain notification could not be:
/// it keeps a single high-importance, ongoing notification alive for the whole
/// snooze, carries the 解除 action, and — from an *in-process* receiver, the
/// only kind that still fires for `ACTION_USER_PRESENT` on Android 8+ — raises
/// itself as heads-up when the phone is unlocked. The loss glance in the body
/// is pushed from here on a timer, so a user who is up but not paying attention
/// can see the meter running.
///
/// An interface so tests never reach a platform channel, and so a channel
/// failure can never take a snooze down with it.
abstract class SnoozeForegroundService {
  /// Starts (or replaces) the service for [sessionId].
  Future<void> start({
    required String sessionId,
    required String title,
    required String body,
  });

  /// Pushes new notification text (the climbing loss) without restarting.
  Future<void> update({required String sessionId, required String body});

  /// Stops the service and removes the notification.
  Future<void> stop();

  /// The session id if the app was cold-launched by tapping 解除, else null.
  Future<String?> consumeLaunchDismiss();

  /// Warm 解除 taps — the app was already alive — arrive here.
  Stream<String> get dismissRequests;
}

/// Builds the notification body for [sessionId] at the moment it is called, or
/// null when the snooze is over and the service should stop. Injected so the
/// platform service can call [lossAt] against the live session without this
/// file knowing about the database.
typedef SnoozeBodyBuilder = Future<String?> Function(String sessionId);

/// Records instead of touching a service. The default, so every test runs
/// without a platform under it.
class RecordingSnoozeService implements SnoozeForegroundService {
  final started = <({String sessionId, String title, String body})>[];
  final updated = <({String sessionId, String body})>[];
  int stops = 0;

  final _dismiss = StreamController<String>.broadcast();

  /// Drives the warm-dismiss path in a test.
  void emitDismiss(String sessionId) => _dismiss.add(sessionId);

  @override
  Future<void> start({
    required String sessionId,
    required String title,
    required String body,
  }) async => started.add((sessionId: sessionId, title: title, body: body));

  @override
  Future<void> update({
    required String sessionId,
    required String body,
  }) async => updated.add((sessionId: sessionId, body: body));

  @override
  Future<void> stop() async => stops++;

  @override
  Future<String?> consumeLaunchDismiss() async => null;

  @override
  Stream<String> get dismissRequests => _dismiss.stream;
}

/// The real thing: a [MethodChannel] to the native `SnoozeService`, plus a Dart
/// timer that recomputes the loss and pushes it into the notification.
///
/// The loss is worked out **here**, in Dart, with the same [lossAt] the ring
/// screen uses — the native side holds no money logic. When the app process is
/// gone the timer stops with it and the notification keeps its last body; the
/// native receiver still re-raises it on unlock. That last-value freeze is the
/// one thing this cannot do headless, and it is documented as such.
class PlatformSnoozeService implements SnoozeForegroundService {
  PlatformSnoozeService({
    required this.bodyBuilder,
    MethodChannel? channel,
    this.interval = const Duration(seconds: 20),
  }) : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const channelName = 'wake_or_pay/snooze';

  final MethodChannel _channel;
  final SnoozeBodyBuilder bodyBuilder;
  final Duration interval;

  final _dismiss = StreamController<String>.broadcast();
  Timer? _timer;
  String? _sessionId;

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'onDismiss') {
      final id = call.arguments as String?;
      if (id != null && id.isNotEmpty) _dismiss.add(id);
    }
    return null;
  }

  @override
  Future<void> start({
    required String sessionId,
    required String title,
    required String body,
  }) async {
    _sessionId = sessionId;
    try {
      await _channel.invokeMethod('start', {
        'sessionId': sessionId,
        'title': title,
        'body': body,
      });
    } on Object catch (e) {
      debugPrint('snooze service start failed: $e');
    }
    _timer?.cancel();
    // The loss glance is refreshed on this cadence — not every second: Android
    // suppresses repeated heads-up anyway, and a one-second wake loop would
    // cost battery for a number that changes once a minute.
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  Future<void> _tick() async {
    final id = _sessionId;
    if (id == null) return;
    final body = await bodyBuilder(id);
    if (body == null) {
      await stop();
      return;
    }
    await update(sessionId: id, body: body);
  }

  @override
  Future<void> update({
    required String sessionId,
    required String body,
  }) async {
    _sessionId = sessionId;
    try {
      await _channel.invokeMethod('update', {'body': body});
    } on Object catch (e) {
      debugPrint('snooze service update failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _sessionId = null;
    try {
      await _channel.invokeMethod('stop');
    } on Object catch (e) {
      debugPrint('snooze service stop failed: $e');
    }
  }

  @override
  Future<String?> consumeLaunchDismiss() async {
    try {
      return await _channel.invokeMethod<String>('consumeLaunchDismiss');
    } on Object catch (e) {
      debugPrint('snooze service launch check failed: $e');
      return null;
    }
  }

  @override
  Stream<String> get dismissRequests => _dismiss.stream;
}

/// Overridden in tests with a [RecordingSnoozeService] (the default), and in
/// `main()` with the real one.
final snoozeForegroundServiceProvider = Provider<SnoozeForegroundService>(
  (ref) => RecordingSnoozeService(),
);

Override platformSnoozeServiceOverride(SnoozeBodyBuilder bodyBuilder) =>
    snoozeForegroundServiceProvider.overrideWithValue(
      PlatformSnoozeService(bodyBuilder: bodyBuilder),
    );
