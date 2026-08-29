import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/billing_api.dart';

/// One request as the mock saw it.
class _Seen {
  _Seen(this.method, this.url, this.headers, this.body);

  final String method;
  final String url;
  final Map<String, String> headers;
  final String body;

  Map<String, Object?> get json =>
      body.isEmpty ? {} : jsonDecode(body) as Map<String, Object?>;
}

void main() {
  late List<_Seen> seen;

  /// A client answering [status] with [body] for everything, recording what it
  /// was asked.
  HttpBillingApi apiThat({int status = 200, String body = '{}'}) {
    seen = [];
    return HttpBillingApi(
      MockClient((request) async {
        seen.add(
          _Seen(
            request.method,
            request.url.toString(),
            Map.of(request.headers),
            request.body,
          ),
        );
        return http.Response(
          body,
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      baseUrl: 'https://worker.example',
    );
  }

  group('register', () {
    test('posts the installId and reads the token back', () async {
      final api = apiThat(body: '{"deviceToken":"tok_abc"}');

      final token = await api.register(
        '11111111-2222-4333-8444-555555555555',
        platform: 'android',
        appVersion: '1.0.0+1',
      );

      expect(token, 'tok_abc');
      expect(seen.single.method, 'POST');
      expect(seen.single.url, 'https://worker.example/v1/devices/register');
      expect(seen.single.json, {
        'installId': '11111111-2222-4333-8444-555555555555',
        'platform': 'android',
        'appVersion': '1.0.0+1',
      });
      // No Authorization: this is the call that gets you one.
      expect(seen.single.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')));
    });

    test('a bad installId comes back as the Worker code', () async {
      final api = apiThat(status: 400, body: '{"error":"bad_install_id"}');

      expect(
        () => api.register('nope', platform: 'android', appVersion: '1'),
        throwsA(
          isA<BillingApiException>()
              .having((e) => e.code, 'code', 'bad_install_id')
              .having((e) => e.status, 'status', 400),
        ),
      );
    });
  });

  group('setup-intent', () {
    test('sends the consent and reads the four secrets back', () async {
      final api = apiThat(
        body: jsonEncode({
          'customerId': 'cus_1',
          'ephemeralKeySecret': 'ek_test_1',
          'setupIntentClientSecret': 'seti_1_secret_x',
          'publishableKey': 'pk_test_1',
        }),
      );

      final session = await api.createSetupIntent(
        'tok_abc',
        CardHostageConsent(
          version: 1,
          acceptedAt: DateTime.utc(2026, 8, 29, 13, 45),
        ),
      );

      expect(session.customerId, 'cus_1');
      expect(session.ephemeralKeySecret, 'ek_test_1');
      expect(session.setupIntentClientSecret, 'seti_1_secret_x');
      expect(session.publishableKey, 'pk_test_1');
      expect(seen.single.url, 'https://worker.example/v1/billing/setup-intent');
      expect(seen.single.headers['authorization'], 'Bearer tok_abc');
      expect(seen.single.json['consent'], {
        'version': 1,
        'acceptedAt': '2026-08-29T13:45:00.000Z',
      });
    });
  });

  group('card confirm', () {
    test('sends the setupIntentId and reads the card back', () async {
      final api = apiThat(
        body: jsonEncode({
          'card': {
            'brand': 'visa',
            'last4': '4242',
            'expMonth': 12,
            'expYear': 2030,
          },
        }),
      );

      final card = await api.confirmCard('tok_abc', 'seti_1');

      expect(card.label, 'VISA •••• 4242');
      expect(seen.single.url, 'https://worker.example/v1/billing/card/confirm');
      expect(seen.single.json, {'setupIntentId': 'seti_1'});
    });

    test('a SetupIntent that did not succeed keeps its code', () async {
      final api = apiThat(status: 409, body: '{"error":"setup_not_succeeded"}');
      expect(
        () => api.confirmCard('tok_abc', 'seti_1'),
        throwsA(
          isA<BillingApiException>().having(
            (e) => e.code,
            'code',
            'setup_not_succeeded',
          ),
        ),
      );
    });
  });

  group('card', () {
    test('reads card and consent, and null is a legitimate answer', () async {
      final api = apiThat(body: '{"card":null,"consent":null}');

      final answer = await api.card('tok_abc');

      expect(answer.card, isNull);
      expect(answer.consent, isNull);
      expect(seen.single.method, 'GET');
      expect(seen.single.url, 'https://worker.example/v1/billing/card');
    });

    test('reads a registered card with its consent', () async {
      final api = apiThat(
        body: jsonEncode({
          'card': {
            'brand': 'mastercard',
            'last4': '0007',
            'expMonth': 1,
            'expYear': 2027,
          },
          'consent': {'version': 1, 'acceptedAt': '2026-08-29T13:45:00.000Z'},
        }),
      );

      final answer = await api.card('tok_abc');

      expect(answer.card?.label, 'MASTERCARD •••• 0007');
      expect(answer.consent?.version, 1);
    });
  });

  test('removeCard sends a DELETE with the token', () async {
    final api = apiThat(body: '{"card":null}');

    await api.removeCard('tok_abc');

    expect(seen.single.method, 'DELETE');
    expect(seen.single.url, 'https://worker.example/v1/billing/card');
    expect(seen.single.headers['authorization'], 'Bearer tok_abc');
  });

  group('401', () {
    test('is unauthorized, from the body', () async {
      final api = apiThat(status: 401, body: '{"error":"unauthorized"}');
      await expectLater(
        api.card('stale'),
        throwsA(
          isA<BillingApiException>()
              .having((e) => e.code, 'code', 'unauthorized')
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue),
        ),
      );
    });

    test('is unauthorized even with no body at all', () async {
      // The retry path hangs off this: a proxy stripping the body must not
      // turn a recoverable 401 into a dead end.
      final api = apiThat(status: 401, body: '');
      await expectLater(
        api.removeCard('stale'),
        throwsA(
          isA<BillingApiException>().having(
            (e) => e.isUnauthorized,
            'isUnauthorized',
            isTrue,
          ),
        ),
      );
    });
  });

  test('a client that cannot reach anything is a network failure', () async {
    final api = HttpBillingApi(
      MockClient((_) async => throw http.ClientException('offline')),
      baseUrl: 'https://worker.example',
    );

    await expectLater(
      api.card('tok'),
      throwsA(
        isA<BillingApiException>()
            .having((e) => e.code, 'code', 'network')
            .having((e) => e.status, 'status', 0),
      ),
    );
  });

  test('a 200 with nothing usable in it is not silently a success', () async {
    final api = apiThat(body: '{"deviceToken":""}');
    await expectLater(
      api.register(
        '11111111-2222-4333-8444-555555555555',
        platform: 'android',
        appVersion: '1',
      ),
      throwsA(isA<BillingApiException>()),
    );
  });
}
