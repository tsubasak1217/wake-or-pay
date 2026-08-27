import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';

void main() {
  group('isEmailAddress', () {
    test('accepts what a mail server would', () {
      expect(isEmailAddress('me@example.com'), isTrue);
      expect(isEmailAddress('  me@example.co.jp  '), isTrue);
      expect(isEmailAddress('first.last+tag@example.com'), isTrue);
    });

    test('rejects what could not possibly be one', () {
      expect(isEmailAddress(''), isFalse);
      expect(isEmailAddress('me'), isFalse);
      expect(isEmailAddress('@example.com'), isFalse);
      expect(isEmailAddress('me@example'), isFalse, reason: 'no dot');
      expect(isEmailAddress('me@@example.com'), isFalse);
      expect(isEmailAddress('me@.com'), isFalse);
      expect(isEmailAddress('me@example.'), isFalse);
      expect(isEmailAddress('me you@example.com'), isFalse);
    });
  });

  group('MailSettings.isConfigured', () {
    const complete = MailSettings(
      presetId: 'gmail',
      host: 'smtp.gmail.com',
      fromAddress: 'me@gmail.com',
      username: 'me@gmail.com',
      passwordSaved: true,
    );

    test('every field is load bearing', () {
      expect(complete.isConfigured, isTrue);
      expect(complete.copyWith(host: '').isConfigured, isFalse);
      expect(complete.copyWith(port: 0).isConfigured, isFalse);
      expect(complete.copyWith(fromAddress: 'nope').isConfigured, isFalse);
      expect(complete.copyWith(username: '  ').isConfigured, isFalse);
      expect(
        complete.copyWith(passwordSaved: false).isConfigured,
        isFalse,
        reason: 'an account with no password cannot log in, so it is not set up',
      );
    });

    test('nothing about the password leaks into toString', () {
      // There is no password field to leak; this guards against one being
      // added and printed.
      expect(complete.toString(), contains('password saved'));
      expect(complete.toString(), isNot(contains('secret')));
    });
  });

  group('applyMailPreset', () {
    const typed = MailSettings(
      presetId: MailPreset.customId,
      host: 'mail.mine.example',
      port: 2525,
      useSsl: true,
      fromAddress: 'me@mine.example',
      username: 'me',
      passwordSaved: true,
    );

    test('a preset writes the server fields and leaves the account alone', () {
      final gmail = applyMailPreset(typed, MailPreset.gmail);
      expect(gmail.presetId, 'gmail');
      expect(gmail.host, 'smtp.gmail.com');
      expect(gmail.port, defaultSmtpPort);
      expect(gmail.useSsl, isFalse);
      expect(
        gmail.fromAddress,
        'me@mine.example',
        reason: 'the picker changes where the mail goes out through, not who '
            'it is from',
      );
      expect(gmail.username, 'me');
      expect(gmail.passwordSaved, isTrue);
    });

    test('カスタム unlocks the fields rather than blanking them', () {
      final back = applyMailPreset(
        applyMailPreset(typed, MailPreset.gmail),
        MailPreset.custom,
      );
      expect(back.presetId, MailPreset.customId);
      expect(
        back.host,
        'smtp.gmail.com',
        reason: 'whatever is in the box stays in the box; it just goes editable',
      );
    });

    test('an unknown id reads back as カスタム', () {
      expect(MailPreset.byId('from-a-future-version').id, MailPreset.customId);
      expect(MailPreset.byId(null).id, MailPreset.customId);
      expect(MailPreset.byId('icloud').host, 'smtp.mail.me.com');
    });
  });

  group('buildOversleepMail', () {
    final at = DateTime(2026, 8, 27, 7, 5);

    test('the default body names the app user and the alarm time', () {
      const contact = OversleepContact(
        name: '田中太郎',
        email: 'taro@example.com',
        emailEnabled: true,
      );
      final mail = buildOversleepMail(contact, at, userName: '山田花子');

      expect(mail.to, 'taro@example.com');
      expect(mail.subject, '【Wake or Pay】寝坊のお知らせ');
      expect(mail.body, contains('山田花子'));
      expect(mail.body, contains('07:05'));
      expect(
        mail.body,
        isNot(contains('田中太郎')),
        reason: 'the message is about the sleeper, not about who is told',
      );
    });

    test('a custom body is used exactly as written', () {
      const contact = OversleepContact(
        name: '田中太郎',
        email: 'taro@example.com',
        emailEnabled: true,
        messageMode: MessageMode.custom,
        message: 'ごめん、起こして',
      );
      expect(
        buildOversleepMail(contact, at, userName: '山田花子').body,
        'ごめん、起こして',
      );
    });

    test('with no name set the subject falls back, never to the recipient', () {
      const contact = OversleepContact(
        name: '田中太郎',
        email: 'taro@example.com',
        emailEnabled: true,
      );
      final body = buildOversleepMail(contact, at, userName: '').body;
      expect(body, contains(oversleepUserNameFallback));
      expect(body, isNot(contains('田中太郎')));
    });
  });

  test('the test mail says what it is and where it came from', () {
    const settings = MailSettings(
      host: 'smtp.gmail.com',
      fromAddress: 'me@gmail.com',
      username: 'me@gmail.com',
      passwordSaved: true,
    );
    expect(mailTestSubject, '【Wake or Pay】テスト送信');
    expect(mailTestBody(settings), contains('me@gmail.com'));
    expect(mailTestBody(settings), contains('smtp.gmail.com:$defaultSmtpPort'));
    expect(mailTestBody(settings), contains('STARTTLS'));
    expect(
      mailTestBody(settings.copyWith(useSsl: true, port: sslSmtpPort)),
      contains('SSL'),
    );
  });
}
