import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart' as mailer;
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/send_result.dart';
import 'package:wake_or_pay/services/mail_sender.dart';

const account = MailSettings(
  presetId: 'gmail',
  host: 'smtp.gmail.com',
  fromAddress: 'me@gmail.com',
  username: 'me@gmail.com',
  passwordSaved: true,
);

/// A transport that never opens a socket. It records the message and the
/// server it was handed, and can be told to throw whatever the real one would.
class FakeTransport {
  FakeTransport({this.throws});

  final Object? throws;
  final calls = <({mailer.Message message, mailer.SmtpServer server})>[];

  Future<void> call(mailer.Message message, mailer.SmtpServer server) async {
    calls.add((message: message, server: server));
    final error = throws;
    if (error != null) throw error;
  }
}

SmtpMailSender senderFor(
  FakeTransport transport, {
  MailSettings settings = account,
  String? password = 'app-password',
}) => SmtpMailSender(
  settings: () => settings,
  password: () async => password,
  transport: transport.call,
);

void main() {
  group('smtpServerFor', () {
    test('carries the account across and never allows an insecure hop', () {
      final server = smtpServerFor(account, 'app-password');
      expect(server.host, 'smtp.gmail.com');
      expect(server.port, defaultSmtpPort);
      expect(server.ssl, isFalse);
      expect(server.username, 'me@gmail.com');
      expect(server.password, 'app-password');
      expect(
        server.allowInsecure,
        isFalse,
        reason: 'a server offering no encryption is refused, not sent the '
            'password in the clear',
      );
    });

    test('SSL is the implicit-TLS mode, and still not insecure', () {
      final server = smtpServerFor(
        account.copyWith(useSsl: true, port: sslSmtpPort),
        'pw',
      );
      expect(server.ssl, isTrue);
      expect(server.port, sslSmtpPort);
      expect(server.allowInsecure, isFalse);
    });

    test('a host typed with spaces around it still connects', () {
      expect(smtpServerFor(account.copyWith(host: ' smtp.x.jp '), 'pw').host,
          'smtp.x.jp');
    });
  });

  group('SmtpMailSender', () {
    test('sends the subject and body from the configured address', () async {
      final transport = FakeTransport();
      final result = await senderFor(transport).send(
        to: 'taro@example.com',
        subject: '【Wake or Pay】寝坊のお知らせ',
        body: '起きられていません',
      );

      expect(result.ok, isTrue);
      expect(result.label, '成功');
      final call = transport.calls.single;
      expect(call.message.subject, '【Wake or Pay】寝坊のお知らせ');
      expect(call.message.text, '起きられていません');
      expect(call.message.fromAsAddress.mailAddress, 'me@gmail.com');
      expect(
        call.message.recipientsAsAddresses.single.mailAddress,
        'taro@example.com',
      );
    });

    test('an incomplete account never opens a socket', () async {
      final transport = FakeTransport();
      final result = await senderFor(
        transport,
        settings: account.copyWith(passwordSaved: false),
      ).send(to: 'taro@example.com', subject: 's', body: 'b');

      expect(result.ok, isFalse);
      expect(result.reason, SendFailure.notConfigured);
      expect(transport.calls, isEmpty);
    });

    test('a missing password is named, not swallowed', () async {
      final transport = FakeTransport();
      final result = await senderFor(transport, password: null)
          .send(to: 'taro@example.com', subject: 's', body: 'b');

      expect(result.ok, isFalse);
      expect(result.reason, contains('アプリパスワード'));
      expect(transport.calls, isEmpty);
    });

    test('a recipient that is not an address is refused here', () async {
      final transport = FakeTransport();
      final result = await senderFor(transport)
          .send(to: '  ', subject: 's', body: 'b');

      expect(result.reason, SendFailure.noAddress);
      expect(transport.calls, isEmpty);
    });

    test('every throw the transport can make becomes a value', () async {
      Future<SendResult> failWith(Object error) => senderFor(
        FakeTransport(throws: error),
      ).send(to: 'taro@example.com', subject: 's', body: 'b');

      expect(
        (await failWith(
          mailer.SmtpClientAuthenticationException('535 bad password'),
        )).reason,
        SendFailure.auth,
      );
      expect(
        (await failWith(mailer.SmtpUnsecureException('no starttls'))).reason,
        contains('暗号化'),
      );
      expect(
        (await failWith(const SocketException('offline'))).reason,
        SendFailure.network,
      );
      expect(
        (await failWith(StateError('something else'))).reason,
        SendFailure.unknown,
      );
    });

    test('the failure keeps the detail for the log but not for the user',
        () async {
      final result = await senderFor(
        FakeTransport(
          throws: mailer.SmtpClientAuthenticationException('535 bad password'),
        ),
      ).send(to: 'taro@example.com', subject: 's', body: 'b');

      expect(result.detail, contains('535'));
      expect(
        result.label,
        '失敗（認証に失敗しました）',
        reason: 'the log row is one short phrase, not a server transcript',
      );
    });
  });
}
