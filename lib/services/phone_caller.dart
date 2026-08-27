import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wop_platform/wop_platform.dart';

import '../domain/send_result.dart';

/// Placing a call from the user's own number, per spec 11.5.
///
/// **Nothing is played into the call**: the contact's own voice coming out of
/// the sleeper's speaker is the whole mechanism. The app dials and gets out of
/// the way.
///
/// An interface because every test must be able to hand in something that
/// dials nobody — a number in a test is somebody's real phone — and because
/// the background isolate of spec 11.7 hands in one that refuses outright.
abstract class PhoneCaller {
  /// Never throws. See [SendResult].
  Future<SendResult> call(String number);

  /// True while a call is up, so the alarm sound can get out of the way and
  /// come back. Best effort: on a device that refuses `READ_PHONE_STATE` this
  /// simply never emits, and the alarm keeps ringing through the call.
  Stream<bool> get inCall;
}

@visibleForTesting
const phoneMethodChannel = MethodChannel(wopPhoneChannel);

@visibleForTesting
const phoneStateEventChannel = EventChannel(wopPhoneStateChannel);

/// `ACTION_CALL` over the platform channel.
class PlatformPhoneCaller implements PhoneCaller {
  const PlatformPhoneCaller([
    this._channel = phoneMethodChannel,
    this._state = phoneStateEventChannel,
  ]);

  final MethodChannel _channel;
  final EventChannel _state;

  @override
  Future<SendResult> call(String number) async {
    if (number.trim().isEmpty) {
      return const SendResult.failure(SendFailure.noAddress);
    }
    try {
      await _channel.invokeMethod<void>('call', {'to': number});
      return const SendResult.success();
    } on PlatformException catch (e) {
      return SendResult.failure(
        _reasonFor(e.code),
        detail: '${e.code}: ${e.message}',
      );
    } on MissingPluginException catch (e) {
      return SendResult.failure(SendFailure.platform, detail: '$e');
    } on Object catch (e) {
      return SendResult.failure(SendFailure.unknown, detail: '$e');
    }
  }

  /// Errors on the stream are swallowed into "not in a call": a broken
  /// listener must never leave the alarm silenced forever.
  @override
  Stream<bool> get inCall => _state
      .receiveBroadcastStream()
      .map((event) => event == true)
      .handleError((Object e) => debugPrint('call state stream failed: $e'));
}

String _reasonFor(String code) => switch (code) {
  WopErrorCode.permission => SendFailure.permission,
  WopErrorCode.invalid => SendFailure.noAddress,
  WopErrorCode.unavailable => SendFailure.platform,
  _ => SendFailure.unknown,
};

/// Records instead of dialling. The default everywhere but the real app.
class RecordingPhoneCaller implements PhoneCaller {
  RecordingPhoneCaller({this.result = const SendResult.success()});

  final SendResult result;
  final called = <String>[];

  final _state = StreamController<bool>.broadcast();

  /// Pushes a call state in, as the platform would.
  void emitInCall(bool value) => _state.add(value);

  @override
  Future<SendResult> call(String number) async {
    called.add(number);
    return result;
  }

  @override
  Stream<bool> get inCall => _state.stream;
}

/// Refuses, with the one reason that is actually true from a background
/// isolate: `ACTION_CALL` needs an Activity, and there is not one.
///
/// Used by the spec 11.7 dispatcher, so the log says the call was skipped
/// rather than leaving a silence that looks like a call that went out.
class UnavailablePhoneCaller implements PhoneCaller {
  const UnavailablePhoneCaller();

  static const backgroundReason = 'アプリが起動していないため発信できません';

  @override
  Future<SendResult> call(String number) async =>
      const SendResult.failure(backgroundReason);

  @override
  Stream<bool> get inCall => const Stream<bool>.empty();
}

/// The default is the recording one, so a test that forgets an override
/// cannot dial anybody. `main()` swaps in the real caller.
final phoneCallerProvider = Provider<PhoneCaller>(
  (ref) => RecordingPhoneCaller(),
);

Override platformPhoneCallerOverride() =>
    phoneCallerProvider.overrideWithValue(const PlatformPhoneCaller());
