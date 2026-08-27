import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';

void main() {
  group('normalizePhoneNumber', () {
    test('keeps the digits of every way a number gets written', () {
      expect(normalizePhoneNumber('090-1234-5678'), '09012345678');
      expect(normalizePhoneNumber('090 1234 5678'), '09012345678');
      expect(normalizePhoneNumber('(03) 1234-5678'), '0312345678');
      expect(normalizePhoneNumber('  09012345678  '), '09012345678');
    });

    test('a leading + survives, in ASCII, and only at the front', () {
      expect(normalizePhoneNumber('+81 90-1234-5678'), '+819012345678');
      expect(normalizePhoneNumber('＋81 90 1234 5678'), '+819012345678');
      expect(
        normalizePhoneNumber('090+1234'),
        '0901234',
        reason: 'a plus in the middle is not an international prefix',
      );
    });

    test('full-width digits fold onto ASCII', () {
      expect(normalizePhoneNumber('０９０－１２３４－５６７８'), '09012345678');
    });

    test('nothing dialable in, nothing out', () {
      expect(normalizePhoneNumber(''), '');
      expect(normalizePhoneNumber('けいたい'), '');
      expect(normalizePhoneNumber('---'), '');
    });
  });

  group('buildOversleepSms', () {
    final at = DateTime(2026, 8, 27, 7, 5);

    test('the number is normalised and the default body has no subject tag', () {
      const contact = OversleepContact(
        name: '田中太郎',
        phone: '090-1234-5678',
        smsEnabled: true,
      );
      final sms = buildOversleepSms(contact, at, userName: '山田花子');

      expect(sms.to, '09012345678');
      expect(sms.body, contains('山田花子'));
      expect(sms.body, contains('07:05'));
      expect(
        sms.body,
        isNot(contains('【Wake or Pay】')),
        reason: 'a text message has no inbox to be recognised in',
      );
    });

    test('a custom body is the same one the mail carries', () {
      const contact = OversleepContact(
        name: '田中太郎',
        phone: '09012345678',
        email: 'taro@example.com',
        smsEnabled: true,
        emailEnabled: true,
        messageMode: MessageMode.custom,
        message: 'ごめん、起こして',
      );
      expect(
        buildOversleepSms(contact, at, userName: '山田花子').body,
        buildOversleepMail(contact, at, userName: '山田花子').body,
      );
    });
  });
}
