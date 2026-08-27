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
    test('the 改訂2 JSON shape collapses into one message and one mode', () {
      // What a v6 row actually held: a mail mode beside a phone mode, a
      // recording for the automated voice, and the trigger delay. Only the
      // first survives 改訂4; the rest are read and discarded here, and the
      // delay is dug back out by the mapper, not by this model.
      final old = OversleepContact.fromJson(const {
        'name': '母',
        'phone': '090-0000-0000',
        'mailMode': 'custom',
        'mailMessage': '起きて',
        'phoneMode': 'custom',
        'recordingPath': '/tmp/a.m4a',
        'recordingWaveform': [0.5],
        'triggerMinutesAfterGrace': 7,
      });

      expect(old.name, '母');
      expect(old.contactId, isNull);
      expect(old.phoneEnabled, isTrue, reason: 'it had a number');
      expect(old.emailEnabled, isFalse);
      expect(
        old.smsEnabled,
        isFalse,
        reason: 'nobody who wrote that row was asked about SMS',
      );
      expect(old.messageMode, MessageMode.custom);
      expect(old.message, '起きて');
      for (final gone in const [
        'recordingPath',
        'recordingWaveform',
        'phoneMode',
        'triggerMinutesAfterGrace',
      ]) {
        expect(
          old.toJson().containsKey(gone),
          isFalse,
          reason: 'the retired 電話設定 leaves no $gone behind',
        );
      }
    });

    test('the pre-改訂2 shape had one bare 「message」 doing both jobs', () {
      final old = OversleepContact.fromJson(const {
        'name': '母',
        'phone': '090-0000-0000',
        'email': null,
        'triggerMinutesAfterGrace': 5,
        'message': '起きて',
        'recordingPath': '/tmp/a.m4a',
      });
      expect(old.messageMode, MessageMode.custom);
      expect(old.message, '起きて');
      expect(old.phoneEnabled, isTrue);
      expect(old.smsEnabled, isFalse);
    });

    test(
      'an old contact with neither message nor recording is all defaults',
      () {
        final old = OversleepContact.fromJson(const {
          'name': '母',
          'email': 'haha@example.com',
          'triggerMinutesAfterGrace': 2,
        });
        expect(old.messageMode, MessageMode.standard);
        expect(old.message, isNull);
        expect(old.emailEnabled, isTrue);
        expect(old.phoneEnabled, isFalse);
        expect(old.smsEnabled, isFalse);
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
        smsEnabled: true,
        messageMode: MessageMode.custom,
        message: 'おきて',
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

    test('the SMS rides on the same number the call would ring', () {
      const texting = OversleepContact(
        name: 'x',
        phone: '090',
        smsEnabled: true,
      );
      expect(texting.willSms, isTrue);
      expect(texting.willPhone, isFalse, reason: 'a separate toggle');
      expect(
        const OversleepContact(name: 'x', smsEnabled: true).willSms,
        isFalse,
        reason: 'no number to text',
      );
    });

    test('the default message names the app user and the alarm time', () {
      expect(
        defaultOversleepMailMessage(
          userName: '田中太郎',
          at: DateTime(2026, 8, 27, 7, 5),
        ),
        '【Wake or Pay】田中太郎 さんは 07:05 のアラームを解除できていません。寝坊しています。',
      );
      expect(
        defaultOversleepSmsMessage(
          userName: '山田花子',
          at: DateTime(2026, 8, 27, 6),
        ),
        '山田花子 さんは 06:00 のアラームを解除できていません。寝坊しています。',
        reason: 'an SMS has no subject line to tag',
      );
    });

    test('with no user name the subject is the generic one', () {
      final at = DateTime(2026, 8, 27, 7, 5);
      expect(oversleepSubjectName(''), oversleepUserNameFallback);
      expect(oversleepSubjectName('   '), oversleepUserNameFallback);
      expect(oversleepSubjectName(' 田中太郎 '), '田中太郎');

      expect(
        defaultOversleepMailMessage(userName: '', at: at),
        '【Wake or Pay】$oversleepUserNameFallback さんは 07:05 の'
        'アラームを解除できていません。寝坊しています。',
      );
      expect(
        defaultOversleepSmsMessage(userName: '  ', at: at),
        '$oversleepUserNameFallback さんは 07:05 のアラームを解除できていません。寝坊しています。',
      );
    });

    test('the default message never names the contact it is sent to', () {
      final at = DateTime(2026, 8, 27, 7);
      const contact = OversleepContact(name: '田中太郎', email: 'a@b.c');
      for (final userName in ['山田花子', '']) {
        expect(
          oversleepMailBodyFor(contact, at, userName: userName),
          isNot(contains('田中太郎')),
          reason: 'Tanaka receives the mail; it is not about Tanaka',
        );
        expect(
          oversleepSmsBodyFor(contact, at, userName: userName),
          isNot(contains('田中太郎')),
        );
      }
    });

    test('the custom words win only when there are any', () {
      final at = DateTime(2026, 8, 27, 7);
      const blank = OversleepContact(
        name: 'x',
        messageMode: MessageMode.custom,
        message: '   ',
      );
      expect(
        oversleepMailBodyFor(blank, at, userName: 'u'),
        defaultOversleepMailMessage(userName: 'u', at: at),
        reason: 'an empty custom message is not a message',
      );
      expect(
        oversleepMailBodyFor(
          const OversleepContact(
            name: 'x',
            messageMode: MessageMode.custom,
            message: 'おきて',
          ),
          at,
          userName: 'u',
        ),
        'おきて',
      );
      expect(
        oversleepMailBodyFor(
          const OversleepContact(name: 'x', message: 'おきて'),
          at,
          userName: 'u',
        ),
        defaultOversleepMailMessage(userName: 'u', at: at),
        reason: 'デフォルト mode ignores the stored custom text',
      );
    });

    test('the mail and the SMS carry the one body the user wrote', () {
      final at = DateTime(2026, 8, 27, 7);
      const custom = OversleepContact(
        name: 'x',
        messageMode: MessageMode.custom,
        message: 'おきて',
      );
      expect(oversleepSmsBodyFor(custom, at, userName: 'u'), 'おきて');
      expect(
        oversleepSmsBodyFor(custom, at, userName: 'u'),
        oversleepMailBodyFor(custom, at, userName: 'u'),
        reason: 'one message, written once',
      );
      // The defaults differ only by the subject tag the inbox needs.
      const plain = OversleepContact(name: 'x');
      expect(
        oversleepMailBodyFor(plain, at, userName: 'u'),
        '【Wake or Pay】${oversleepSmsBodyFor(plain, at, userName: 'u')}',
      );
    });
  });
}
