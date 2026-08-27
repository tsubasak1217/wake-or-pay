import 'package:flutter/foundation.dart';

/// What happened on one personal route — mail, SMS, or a phone call.
///
/// A **value, never a throw**. Every one of these runs at the moment an alarm
/// has already been slept through, from a screen nobody is looking at or from
/// a background isolate. A dead SMTP server must not take down the SMS beside
/// it, the loss clock, or the ring.
///
/// Discord keeps its own `DiscordPostResult` because it has an HTTP status
/// worth spelling out; this is the shape for everything that does not.
@immutable
class SendResult {
  const SendResult({required this.ok, this.reason, this.detail});

  const SendResult.success() : ok = true, reason = null, detail = null;

  /// A failure the app can name in one Japanese phrase.
  const SendResult.failure(String this.reason, {this.detail}) : ok = false;

  final bool ok;

  /// Why it failed, in words a user can act on: 「認証に失敗しました」,
  /// 「権限がありません」. Null when [ok].
  final String? reason;

  /// Whatever was thrown, kept for the log. Never shown raw.
  final String? detail;

  /// One short phrase for the event row and the SnackBar.
  String get label => ok ? '成功' : '失敗（${reason ?? '不明なエラー'}）';

  @override
  bool operator ==(Object other) =>
      other is SendResult &&
      other.ok == ok &&
      other.reason == reason &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(ok, reason, detail);

  @override
  String toString() => 'SendResult($label)';
}

/// The failures every route can hit, in the words the app says them in.
class SendFailure {
  const SendFailure._();

  static const notConfigured = '送信設定が未完了です';
  static const noAddress = '宛先がありません';
  static const auth = '認証に失敗しました';
  static const network = '通信エラー';
  static const permission = '権限がありません';
  static const platform = '端末が対応していません';
  static const unknown = '不明なエラー';
}
