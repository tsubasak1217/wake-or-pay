/// The names of the channels the Android side of this package answers on.
///
/// Deliberately nothing else: the Dart wrappers live in the app, next to the
/// interfaces they implement and the `SendResult` they answer with. This
/// package exists so that the Kotlin gets registered on **every** Flutter
/// engine the app starts — the UI's and the background isolate's — which is
/// something only a real plugin gets for free.
library;

/// SMS. `send` takes `{to, body}` and answers null, or fails with one of
/// [WopErrorCode].
const wopSmsChannel = 'com.wakeorpay.platform/sms';

/// Placing a call and turning the speaker on. `call` takes `{to}`; the
/// EventChannel of the same name plus `/state` reports whether a call is up.
const wopPhoneChannel = 'com.wakeorpay.platform/phone';

const wopPhoneStateChannel = 'com.wakeorpay.platform/phone/state';

/// The `code` on a `PlatformException` from either channel.
///
/// Kept as strings the Dart side switches on, so a new failure mode on the
/// Android side cannot silently become "unknown error" without anyone
/// noticing it was added.
class WopErrorCode {
  const WopErrorCode._();

  /// The runtime permission is not granted.
  static const permission = 'permission';

  /// The arguments were unusable — an empty number, an empty body.
  static const invalid = 'invalid';

  /// The platform refused or has no telephony at all.
  static const unavailable = 'unavailable';

  /// Anything the Android API threw.
  static const failed = 'failed';
}
