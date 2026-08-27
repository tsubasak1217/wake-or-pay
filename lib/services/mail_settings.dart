import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app can actually send mail from this device.
///
/// Spec 11.5 puts sending behind プロフィール → メール送信設定: an SMTP host, an
/// account and an app password the user supplies. **Stage D builds that.**
/// Until it exists there is nothing to send with, so this is `false` — and the
/// メール toggle on the 連絡設定 screen is greyed with a line saying why.
///
/// A provider, and exactly one of them, so stage D flips a single thing. The
/// alternative — a `false` written into the toggle, the subtitle, the log line
/// and the dispatcher — is four places to remember and three of them to forget.
final mailSendingConfiguredProvider = Provider<bool>((ref) => false);

/// Why the メール toggle cannot be switched on. Shown under the row.
const mailSendingUnconfiguredNote = 'メール送信設定が未完了です（プロフィールで設定します・準備中）';
