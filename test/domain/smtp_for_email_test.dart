import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';

void main() {
  group('smtpForEmail', () {
    test('Gmail, with the app-password page', () {
      final p = smtpForEmail('me@gmail.com')!;
      expect(p.label, 'Gmail');
      expect(p.host, 'smtp.gmail.com');
      expect(p.port, 587);
      expect(p.useSsl, isFalse);
      expect(p.username, 'me@gmail.com');
      expect(p.fromAddress, 'me@gmail.com');
      expect(p.appPasswordUrl, 'https://myaccount.google.com/apppasswords');
      // googlemail.com is the same provider.
      expect(smtpForEmail('me@googlemail.com')!.host, 'smtp.gmail.com');
    });

    test('Outlook, across its aliases, without an app-password link', () {
      for (final domain in const [
        'outlook.com',
        'hotmail.com',
        'live.com',
        'live.jp',
        'msn.com',
      ]) {
        final p = smtpForEmail('me@$domain')!;
        expect(p.label, 'Outlook', reason: domain);
        expect(p.host, 'smtp-mail.outlook.com', reason: domain);
        expect(p.port, 587, reason: domain);
        expect(p.useSsl, isFalse, reason: domain);
        expect(p.appPasswordUrl, isNull, reason: domain);
      }
    });

    test('iCloud, with Apple ID as the app-password page', () {
      for (final domain in const ['icloud.com', 'me.com', 'mac.com']) {
        final p = smtpForEmail('me@$domain')!;
        expect(p.label, 'iCloud', reason: domain);
        expect(p.host, 'smtp.mail.me.com', reason: domain);
        expect(p.port, 587, reason: domain);
        expect(p.useSsl, isFalse, reason: domain);
        expect(p.appPasswordUrl, 'https://account.apple.com', reason: domain);
      }
    });

    test('Yahoo (.com) and Yahoo! JP are different hosts', () {
      final us = smtpForEmail('me@yahoo.com')!;
      expect(us.label, 'Yahoo');
      expect(us.host, 'smtp.mail.yahoo.com');
      expect(smtpForEmail('me@ymail.com')!.host, 'smtp.mail.yahoo.com');

      final jp = smtpForEmail('me@yahoo.co.jp')!;
      expect(jp.label, 'Yahoo! JP');
      expect(jp.host, 'smtp.mail.yahoo.co.jp');
    });

    test('the domain match is case-insensitive and trims whitespace', () {
      final p = smtpForEmail('  Me@Gmail.COM  ')!;
      expect(p.host, 'smtp.gmail.com');
      expect(
        p.fromAddress,
        'Me@Gmail.COM',
        reason: 'only the domain is lowered for matching; the address is kept',
      );
    });

    test('an unknown domain has no preset', () {
      expect(smtpForEmail('me@mycompany.co.jp'), isNull);
      expect(smtpForEmail('me@example.com'), isNull);
    });

    test('a string that is not an address is null', () {
      expect(smtpForEmail('me'), isNull);
      expect(smtpForEmail(''), isNull);
      expect(smtpForEmail('@gmail.com'), isNull);
      expect(smtpForEmail('a@@gmail.com'), isNull);
    });
  });
}
