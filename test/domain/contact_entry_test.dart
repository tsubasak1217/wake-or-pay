import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';

ContactEntry entry(
  String name, {
  String? reading,
  String? phone,
  String? email,
  int day = 1,
}) => ContactEntry(
  id: name,
  name: name,
  reading: reading,
  phone: phone,
  email: email,
  createdAt: DateTime(2026, 1, day),
);

void main() {
  group('ContactEntry', () {
    test('sorts by よみがな when there is one, by name otherwise', () {
      expect(entry('田中太郎', reading: 'たなかたろう').sortKey, 'たなかたろう');
      expect(entry('田中太郎').sortKey, '田中太郎');
      expect(
        entry('田中太郎', reading: '   ').sortKey,
        '田中太郎',
        reason: 'whitespace is not a よみがな',
      );
    });

    test('the list is ordered by that key', () {
      final sorted = sortedContactEntries([
        entry('田中太郎', reading: 'たなかたろう'),
        entry('佐藤花子', reading: 'さとうはなこ'),
        entry('阿部一郎', reading: 'あべいちろう'),
      ]);
      expect(sorted.map((e) => e.name), ['阿部一郎', '佐藤花子', '田中太郎']);
    });

    test('ties break on the creation time, so the list never reshuffles', () {
      final sorted = sortedContactEntries([
        entry('B', reading: 'あ', day: 3),
        entry('A', reading: 'あ', day: 1),
        entry('C', reading: 'あ', day: 2),
      ]);
      expect(sorted.map((e) => e.name), ['A', 'C', 'B']);
    });

    test('sorting does not mutate the list it was given', () {
      final original = [entry('B', reading: 'い'), entry('A', reading: 'あ')];
      sortedContactEntries(original);
      expect(original.map((e) => e.name), ['B', 'A']);
    });

    test('a usable entry needs a name and one way to reach them', () {
      expect(entry('母', phone: '090').isUsable, isTrue);
      expect(entry('母', email: 'a@b.c').isUsable, isTrue);
      expect(entry('母').isUsable, isFalse, reason: 'unreachable');
      expect(entry('  ', phone: '090').isUsable, isFalse, reason: 'nameless');
      expect(
        entry('母', phone: '   ').isUsable,
        isFalse,
        reason: 'whitespace is not a phone number',
      );
    });

    test('copyWith clears as well as it sets', () {
      final full = entry('母', reading: 'はは', phone: '090', email: 'a@b.c');
      expect(full.copyWith(clearPhone: true).phone, isNull);
      expect(full.copyWith(clearEmail: true).email, isNull);
      expect(full.copyWith(clearReading: true).reading, isNull);
      expect(full.copyWith(name: '母さん').name, '母さん');
      expect(full.copyWith(name: '母さん').phone, '090', reason: 'kept');
    });
  });

  group('OversleepContact', () {
    test(
      'the pre-改訂2 JSON shape reads as custom mail and custom recording',
      () {
        final old = OversleepContact.fromJson(const {
          'name': '母',
          'phone': '090-0000-0000',
          'email': null,
          'triggerMinutesAfterGrace': 5,
          'message': '起きて',
          'recordingPath': '/tmp/a.m4a',
        });

        expect(old.name, '母');
        expect(old.contactId, isNull);
        expect(old.phoneEnabled, isTrue, reason: 'it had a number');
        expect(old.emailEnabled, isFalse);
        expect(old.mailMode, MailMode.custom);
        expect(old.mailMessage, '起きて');
        expect(old.phoneMode, PhoneMode.custom);
        expect(old.recordingPath, '/tmp/a.m4a');
        expect(old.triggerMinutesAfterGrace, 5);
      },
    );

    test(
      'an old contact with neither message nor recording is all defaults',
      () {
        final old = OversleepContact.fromJson(const {
          'name': '母',
          'email': 'haha@example.com',
          'triggerMinutesAfterGrace': 2,
        });
        expect(old.mailMode, MailMode.standard);
        expect(old.phoneMode, PhoneMode.auto);
        expect(old.emailEnabled, isTrue);
        expect(old.phoneEnabled, isFalse);
      },
    );

    test('the new shape round trips through JSON', () {
      const contact = OversleepContact(
        contactId: 'c1',
        name: '田中太郎',
        phone: '090-1234-5678',
        email: 'taro@example.com',
        phoneEnabled: true,
        emailEnabled: false,
        mailMode: MailMode.custom,
        mailMessage: 'おきて',
        phoneMode: PhoneMode.custom,
        recordingPath: '/tmp/a.m4a',
        triggerMinutesAfterGrace: 0,
      );
      expect(OversleepContact.fromJson(contact.toJson()), contact);
    });

    test('a route is only live when it is switched on and reachable', () {
      const noNumber = OversleepContact(name: 'x', phoneEnabled: true);
      expect(noNumber.willPhone, isFalse);
      const notOn = OversleepContact(name: 'x', phone: '090');
      expect(notOn.willPhone, isFalse);
      const live = OversleepContact(
        name: 'x',
        phone: '090',
        phoneEnabled: true,
      );
      expect(live.willPhone, isTrue);
    });

    test('the default message names the person and the alarm time', () {
      expect(
        defaultOversleepMailMessage(
          name: '田中太郎',
          at: DateTime(2026, 8, 27, 7, 5),
        ),
        '田中太郎 さんは 07:05 のアラームを解除できていません。寝坊しています。',
      );
      expect(
        defaultOversleepVoiceScript(name: '母', at: DateTime(2026, 8, 27, 6)),
        '母 さんは 06:00 のアラームを解除できていません。寝坊しています。',
      );
    });

    test('the custom words win only when there are any', () {
      final at = DateTime(2026, 8, 27, 7);
      const blank = OversleepContact(
        name: 'x',
        mailMode: MailMode.custom,
        mailMessage: '   ',
      );
      expect(
        mailBodyFor(blank, at),
        defaultOversleepMailMessage(name: 'x', at: at),
        reason: 'an empty custom message is not a message',
      );
      expect(
        mailBodyFor(
          const OversleepContact(
            name: 'x',
            mailMode: MailMode.custom,
            mailMessage: 'おきて',
          ),
          at,
        ),
        'おきて',
      );
      expect(
        mailBodyFor(const OversleepContact(name: 'x', mailMessage: 'おきて'), at),
        defaultOversleepMailMessage(name: 'x', at: at),
        reason: 'デフォルト mode ignores the stored custom text',
      );
    });

    test('the call plays the recording only under カスタム録音', () {
      final at = DateTime(2026, 8, 27, 7);
      const custom = OversleepContact(
        name: 'x',
        phoneMode: PhoneMode.custom,
        recordingPath: '/tmp/a.m4a',
      );
      expect(callContentFor(custom, at).recordingPath, '/tmp/a.m4a');
      expect(callContentFor(custom, at).script, isNull);

      const auto = OversleepContact(name: 'x', recordingPath: '/tmp/a.m4a');
      expect(callContentFor(auto, at).recordingPath, isNull);
      expect(callContentFor(auto, at).script, isNotNull);
    });
  });
}
