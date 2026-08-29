import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/services/stripe_config.dart';

void main() {
  group('isStripeTestKey', () {
    test('pk_test_ is a test key', () {
      expect(isStripeTestKey('pk_test_51ABC'), isTrue);
    });

    test('pk_live_ is not a test key', () {
      expect(isStripeTestKey('pk_live_51ABC'), isFalse);
    });

    test('empty string is not a test key', () {
      expect(isStripeTestKey(''), isFalse);
    });
  });
}
