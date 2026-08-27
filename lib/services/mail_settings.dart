import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/models.dart';
import '../domain/send_result.dart';
import 'mail_sender.dart';

/// The stored SMTP account, kept in memory so the メール toggle and the profile
/// row can be drawn without waiting on a future.
///
/// The password is **not** in here — see [MailSettings]. Only whether one has
/// been saved.
final mailSettingsProvider =
    NotifierProvider<MailSettingsController, MailSettings>(
      MailSettingsController.new,
    );

class MailSettingsController extends Notifier<MailSettings> {
  @override
  MailSettings build() => ref.watch(mailSettingsRepositoryProvider).read();

  /// Stores [settings], and [password] when the user typed one.
  ///
  /// A null or empty [password] leaves whatever is already stored alone: the
  /// field on the screen is masked and starts empty even when a password
  /// exists, so an empty field can only mean 「触っていない」. Deleting one is
  /// [clearPassword], which is a button of its own.
  Future<void> save(
    MailSettings settings, {
    String? password,
    bool clearPassword = false,
  }) async {
    state = await ref
        .read(mailSettingsRepositoryProvider)
        .write(settings, password: password, clearPassword: clearPassword);
  }

  /// Sends the 「テスト送信」 mail to the user's own address.
  ///
  /// To themselves and nowhere else, per spec 11.5: the point is to prove the
  /// account works, and proving it by mailing a contact in the afternoon would
  /// be a message they never asked for.
  Future<SendResult> sendTest() async {
    final settings = state;
    if (!settings.isConfigured) {
      return const SendResult.failure(SendFailure.notConfigured);
    }
    return ref
        .read(mailSenderProvider)
        .send(
          to: settings.fromAddress.trim(),
          subject: mailTestSubject,
          body: mailTestBody(settings),
        );
  }
}

/// Whether the app can actually send mail from this device.
///
/// The single gate behind every メール control, per spec 11.5: the toggle on
/// 寝坊時の連絡設定, the row in the profile, and the dispatcher's decision to
/// try. One provider so there is one answer — the alternative is the same
/// condition written in four places and wrong in three.
final mailSendingConfiguredProvider = Provider<bool>(
  (ref) => ref.watch(mailSettingsProvider).isConfigured,
);

/// Why the メール toggle cannot be switched on. Shown under the row.
const mailSendingUnconfiguredNote = 'プロフィールの「メール送信設定」が未完了です';
