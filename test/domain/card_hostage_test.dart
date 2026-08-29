import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/card_sheet.dart';

void main() {
  group('HostageCard', () {
    const card = HostageCard(
      brand: 'visa',
      last4: '4242',
      expMonth: 12,
      expYear: 2030,
    );

    test('the label is the brand upper-cased and the last four', () {
      expect(card.label, 'VISA •••• 4242');
      expect(
        const HostageCard(
          brand: 'mastercard',
          last4: '0007',
          expMonth: 1,
          expYear: 2027,
        ).label,
        'MASTERCARD •••• 0007',
      );
    });

    test('the expiry is MM/YY, zero-padded', () {
      expect(card.expiry, '12/30');
      expect(
        const HostageCard(
          brand: 'amex',
          last4: '1111',
          expMonth: 3,
          expYear: 2027,
        ).expiry,
        '03/27',
      );
    });

    test('json round-trips, and equality is by value', () {
      final back = HostageCard.fromJson(card.toJson());
      expect(back, card);
      expect(back.hashCode, card.hashCode);
    });

    test('anything that is not a card reads back as null', () {
      expect(HostageCard.fromJson(null), isNull);
      expect(HostageCard.fromJson('visa'), isNull);
      expect(HostageCard.fromJson(const <String, Object?>{}), isNull);
      // A Worker answering `{"card": null}`, and a half-written prefs value.
      expect(
        HostageCard.fromJson(const {'brand': 'visa', 'last4': '4242'}),
        isNull,
      );
      expect(
        HostageCard.fromJson(const {
          'brand': '',
          'last4': '4242',
          'expMonth': 1,
          'expYear': 2030,
        }),
        isNull,
      );
    });
  });

  group('CardHostageConsent', () {
    test('json round-trips through UTC', () {
      final consent = CardHostageConsent(
        version: cardHostageConsentVersion,
        acceptedAt: DateTime.utc(2026, 8, 29, 13, 45),
      );
      expect(CardHostageConsent.fromJson(consent.toJson()), consent);
    });

    test('a malformed date is not a consent', () {
      expect(
        CardHostageConsent.fromJson(const {
          'version': 1,
          'acceptedAt': 'yesterday',
        }),
        isNull,
      );
      expect(CardHostageConsent.fromJson(null), isNull);
    });

    test('the mandate says what is charged, when, and how to stop', () {
      expect(cardHostageMandateText, contains('毎月末'));
      expect(cardHostageMandateText, contains('上限金額'));
      expect(cardHostageMandateText, contains('いつでも解除'));
    });
  });

  group('setupIntentIdFromClientSecret', () {
    test('takes the part before _secret_', () {
      expect(
        setupIntentIdFromClientSecret('seti_1ABCdef_secret_XYZ123'),
        'seti_1ABCdef',
      );
    });

    test('is null when there is no marker, or nothing before it', () {
      expect(setupIntentIdFromClientSecret('seti_1ABCdef'), isNull);
      expect(setupIntentIdFromClientSecret(''), isNull);
      expect(setupIntentIdFromClientSecret('_secret_XYZ'), isNull);
    });

    test('keeps only the first marker, so the secret half never leaks', () {
      final id = setupIntentIdFromClientSecret(
        'seti_1_secret_aaa_secret_bbb',
      );
      expect(id, 'seti_1');
      expect(id, isNot(contains('aaa')));
    });
  });
}
