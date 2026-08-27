import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wop_platform/wop_platform.dart';

import '../domain/send_result.dart';

/// Sending one text message from the user's own number, per spec 11.5.
///
/// An interface because every test must be able to hand in something that does
/// not reach a radio — a number in a test is somebody's real phone — and
/// because the background isolate of spec 11.7 builds its own.
abstract class SmsSender {
  /// Never throws. See [SendResult].
  Future<SendResult> send({required String to, required String body});
}

/// The channel `wop_platform` answers on. A plugin rather than a channel wired
/// up in `MainActivity`, so that it exists on the background isolate's engine
/// too — see that package's pubspec.
@visibleForTesting
const smsMethodChannel = MethodChannel(wopSmsChannel);

/// `SmsManager` over the platform channel.
class PlatformSmsSender implements SmsSender {
  const PlatformSmsSender([this._channel = smsMethodChannel]);

  final MethodChannel _channel;

  @override
  Future<SendResult> send({required String to, required String body}) async {
    if (to.trim().isEmpty) {
      return const SendResult.failure(SendFailure.noAddress);
    }
    if (body.trim().isEmpty) {
      return const SendResult.failure('本文が空です');
    }
    try {
      await _channel.invokeMethod<void>('send', {'to': to, 'body': body});
      return const SendResult.success();
    } on PlatformException catch (e) {
      return SendResult.failure(_reasonFor(e.code), detail: '${e.code}: ${e.message}');
    } on MissingPluginException catch (e) {
      // No Android under this build — a desktop debug run, or a test that
      // reached the real sender by mistake.
      return SendResult.failure(SendFailure.platform, detail: '$e');
    } on Object catch (e) {
      return SendResult.failure(SendFailure.unknown, detail: '$e');
    }
  }
}

/// The Japanese phrase for one of [WopErrorCode]. Pure.
String _reasonFor(String code) => switch (code) {
  WopErrorCode.permission => SendFailure.permission,
  WopErrorCode.invalid => SendFailure.noAddress,
  WopErrorCode.unavailable => SendFailure.platform,
  _ => SendFailure.unknown,
};

/// Records instead of sending. The default everywhere but the real app.
class RecordingSmsSender implements SmsSender {
  RecordingSmsSender({this.result = const SendResult.success()});

  final SendResult result;
  final sent = <({String to, String body})>[];

  @override
  Future<SendResult> send({required String to, required String body}) async {
    sent.add((to: to, body: body));
    return result;
  }
}

/// Deliberately the recording one by default: a test that forgets an override
/// must not be able to text anybody. `main()` swaps in the real sender.
final smsSenderProvider = Provider<SmsSender>((ref) => RecordingSmsSender());

Override platformSmsSenderOverride() =>
    smsSenderProvider.overrideWithValue(const PlatformSmsSender());
