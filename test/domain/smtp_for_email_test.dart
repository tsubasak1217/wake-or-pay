import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';

/// One expected row of the domain table, as the app should answer it.
typedef _Expected = ({
  String domain,
  String label,
  String host,
  int port,
  bool ssl,
});

const _table = <_Expected>[
  (
    domain: 'gmail.com',
    label: 'Gmail',
    host: 'smtp.gmail.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'googlemail.com',
    label: 'Gmail',
    host: 'smtp.gmail.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'outlook.com',
    label: 'Outlook',
    host: 'smtp-mail.outlook.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'outlook.jp',
    label: 'Outlook',
    host: 'smtp-mail.outlook.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'hotmail.com',
    label: 'Outlook',
    host: 'smtp-mail.outlook.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'hotmail.co.jp',
    label: 'Outlook',
    host: 'smtp-mail.outlook.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'live.com',
    label: 'Outlook',
    host: 'smtp-mail.outlook.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'live.jp',
    label: 'Outlook',
    host: 'smtp-mail.outlook.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'msn.com',
    label: 'Outlook',
    host: 'smtp-mail.outlook.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'icloud.com',
    label: 'iCloud',
    host: 'smtp.mail.me.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'me.com',
    label: 'iCloud',
    host: 'smtp.mail.me.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'mac.com',
    label: 'iCloud',
    host: 'smtp.mail.me.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'yahoo.com',
    label: 'Yahoo',
    host: 'smtp.mail.yahoo.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'ymail.com',
    label: 'Yahoo',
    host: 'smtp.mail.yahoo.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'rocketmail.com',
    label: 'Yahoo',
    host: 'smtp.mail.yahoo.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'yahoo.co.jp',
    label: 'Yahoo! JP',
    host: 'smtp.mail.yahoo.co.jp',
    port: 465,
    ssl: true,
  ),
  (domain: 'aol.com', label: 'AOL', host: 'smtp.aol.com', port: 465, ssl: true),
  (
    domain: 'zoho.com',
    label: 'Zoho',
    host: 'smtp.zoho.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'zohomail.com',
    label: 'Zoho',
    host: 'smtp.zoho.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'zoho.jp',
    label: 'Zoho',
    host: 'smtp.zoho.com',
    port: 587,
    ssl: false,
  ),
  (domain: 'gmx.com', label: 'GMX', host: 'smtp.gmx.com', port: 587, ssl: false),
  (domain: 'gmx.net', label: 'GMX', host: 'mail.gmx.net', port: 587, ssl: false),
  (domain: 'gmx.de', label: 'GMX', host: 'mail.gmx.net', port: 587, ssl: false),
  (
    domain: 'mail.com',
    label: 'mail.com',
    host: 'smtp.mail.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'ocn.ne.jp',
    label: 'OCN',
    host: 'smtp.ocn.ne.jp',
    port: 465,
    ssl: true,
  ),
  (
    domain: 'nifty.com',
    label: '@nifty',
    host: 'smtp.nifty.com',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'biglobe.ne.jp',
    label: 'BIGLOBE',
    host: 'mail.biglobe.ne.jp',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'so-net.ne.jp',
    label: 'So-net',
    host: 'mail.so-net.ne.jp',
    port: 587,
    ssl: false,
  ),
  (
    domain: 'plala.or.jp',
    label: 'plala',
    host: 'secure.plala.or.jp',
    port: 587,
    ssl: false,
  ),
];

void main() {
  group('smtpForEmail', () {
    test('every domain in the table resolves to its server', () {
      for (final row in _table) {
        final p = smtpForEmail('taro@${row.domain}');
        expect(p, isNotNull, reason: row.domain);
        expect(p!.label, row.label, reason: row.domain);
        expect(p.host, row.host, reason: row.domain);
        expect(p.port, row.port, reason: row.domain);
        expect(p.useSsl, row.ssl, reason: row.domain);
        expect(
          p.fromAddress,
          'taro@${row.domain}',
          reason: 'the address is never rewritten: ${row.domain}',
        );
      }
    });

    test('Gmail, with the app-password page and a note', () {
      final p = smtpForEmail('me@gmail.com')!;
      expect(p.username, 'me@gmail.com');
      expect(p.appPasswordUrl, 'https://myaccount.google.com/apppasswords');
      expect(p.note, contains('2段階認証'));
    });

    test('Outlook has an app-password page and a note', () {
      final p = smtpForEmail('me@outlook.com')!;
      expect(p.appPasswordUrl, 'https://account.live.com/proofs/AppPassword');
      expect(p.note, contains('Microsoft'));
    });

    test('iCloud points at the Apple account page', () {
      expect(
        smtpForEmail('me@icloud.com')!.appPasswordUrl,
        'https://account.apple.com',
      );
    });

    test('Yahoo! JP logs in as the local part, not the address', () {
      final jp = smtpForEmail('taro@yahoo.co.jp')!;
      expect(jp.username, 'taro');
      expect(
        jp.fromAddress,
        'taro@yahoo.co.jp',
        reason: 'the mail is still from the whole address',
      );
      expect(jp.useSsl, isTrue);
      expect(jp.port, 465);
      expect(jp.note, contains('IMAP/POP/SMTP'));

      // Every other provider logs in as the whole address.
      expect(smtpForEmail('taro@yahoo.com')!.username, 'taro@yahoo.com');
      expect(smtpForEmail('taro@ocn.ne.jp')!.username, 'taro@ocn.ne.jp');
    });

    test('GMX .com and .net are different hosts', () {
      expect(smtpForEmail('me@gmx.com')!.host, 'smtp.gmx.com');
      expect(smtpForEmail('me@gmx.net')!.host, 'mail.gmx.net');
      expect(smtpForEmail('me@gmx.de')!.host, 'mail.gmx.net');
    });

    test('the providers with no app-password page say so', () {
      for (final domain in const [
        'zoho.com',
        'gmx.com',
        'mail.com',
        'ocn.ne.jp',
        'nifty.com',
        'biglobe.ne.jp',
        'so-net.ne.jp',
        'plala.or.jp',
      ]) {
        expect(smtpForEmail('me@$domain')!.appPasswordUrl, isNull,
            reason: domain);
      }
    });

    test('a provider may have no note at all', () {
      expect(smtpForEmail('me@gmx.com')!.note, isNull);
      expect(smtpForEmail('me@mail.com')!.note, isNull);
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
      expect(smtpForEmail('me@notgmail.com'), isNull);
    });

    test('a string that is not an address is null', () {
      expect(smtpForEmail('me'), isNull);
      expect(smtpForEmail(''), isNull);
      expect(smtpForEmail('@gmail.com'), isNull);
      expect(smtpForEmail('a@@gmail.com'), isNull);
    });
  });
}
