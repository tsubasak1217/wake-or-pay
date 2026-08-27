import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart' as mailer;

import '../data/providers.dart';
import '../domain/models.dart';
import '../domain/send_result.dart';

/// How long one SMTP conversation is allowed to take.
///
/// Bounded because this runs from the dispatcher at trigger time: a server
/// that accepts the connection and then says nothing must not leave the SMS
/// and the Discord post behind it waiting forever.
const mailSendTimeout = Duration(seconds: 30);

/// Sending one mail from the user's own account.
///
/// An interface because every test in this app must be able to hand in
/// something that does not reach an SMTP server — the address in a test is
/// somebody's real inbox — and because the background isolate of spec 11.7
/// builds its own.
abstract class MailSender {
  /// Never throws. See [SendResult].
  Future<SendResult> send({
    required String to,
    required String subject,
    required String body,
  });
}

/// The `SmtpServer` [settings] and [password] describe. Pure.
///
/// `allowInsecure` is false in both branches: with [MailSettings.useSsl] the
/// socket is TLS from the first byte, and without it the connection is
/// upgraded by `STARTTLS` or refused. There is no path here that puts an app
/// password on the wire in the clear.
mailer.SmtpServer smtpServerFor(MailSettings settings, String password) =>
    mailer.SmtpServer(
      settings.host.trim(),
      port: settings.port,
      ssl: settings.useSsl,
      allowInsecure: false,
      username: settings.username.trim(),
      password: password,
    );

/// How [SmtpMailSender] actually puts a message on the wire. Swapped in tests
/// so the construction of the server and the message can be checked without
/// one.
typedef SmtpTransport =
    Future<void> Function(mailer.Message message, mailer.SmtpServer server);

Future<void> _realTransport(
  mailer.Message message,
  mailer.SmtpServer server,
) async => mailer.send(message, server, timeout: mailSendTimeout);

/// `mailer` over the account in メール送信設定.
///
/// The settings and the password are fetched **per send**, not held: the
/// password must not sit in a field of a long-lived object, and a setting
/// changed last night has to be the one used this morning.
class SmtpMailSender implements MailSender {
  SmtpMailSender({
    required this.settings,
    required this.password,
    SmtpTransport? transport,
  }) : _transport = transport ?? _realTransport;

  final MailSettings Function() settings;
  final Future<String?> Function() password;
  final SmtpTransport _transport;

  @override
  Future<SendResult> send({
    required String to,
    required String subject,
    required String body,
  }) async {
    final account = settings();
    if (!account.isConfigured) {
      return const SendResult.failure(SendFailure.notConfigured);
    }
    if (!isEmailAddress(to)) {
      return const SendResult.failure(SendFailure.noAddress);
    }
    final secret = await password();
    if (secret == null) {
      return const SendResult.failure('アプリパスワードが保存されていません');
    }

    final message = mailer.Message()
      ..from = mailer.Address(account.fromAddress.trim())
      ..recipients.add(to.trim())
      ..subject = subject
      ..text = body;

    try {
      await _transport(message, smtpServerFor(account, secret));
      return const SendResult.success();
    } on mailer.SmtpClientAuthenticationException catch (e) {
      return SendResult.failure(SendFailure.auth, detail: '$e');
    } on mailer.SmtpUnsecureException catch (e) {
      return SendResult.failure('暗号化できませんでした', detail: '$e');
    } on SocketException catch (e) {
      return SendResult.failure(SendFailure.network, detail: '$e');
    } on Object catch (e) {
      return SendResult.failure(SendFailure.unknown, detail: '$e');
    }
  }
}

/// Records instead of sending. The default, so nothing in a test can post a
/// mail to a real address by forgetting an override.
class RecordingMailSender implements MailSender {
  RecordingMailSender({this.result = const SendResult.success()});

  final SendResult result;
  final sent = <({String to, String subject, String body})>[];

  @override
  Future<SendResult> send({
    required String to,
    required String subject,
    required String body,
  }) async {
    sent.add((to: to, subject: subject, body: body));
    return result;
  }
}

/// The real sender, over the stored account.
///
/// `read`, not `watch`, inside the closures: the account is wanted at the
/// moment of sending, and editing it must not tear this provider down while a
/// send is in flight.
final mailSenderProvider = Provider<MailSender>(
  (ref) => SmtpMailSender(
    settings: () => ref.read(mailSettingsRepositoryProvider).read(),
    password: () => ref.read(mailSettingsRepositoryProvider).password(),
  ),
);
