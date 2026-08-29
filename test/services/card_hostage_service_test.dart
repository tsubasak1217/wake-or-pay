import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/card_hostage.dart';
import 'package:wake_or_pay/services/card_sheet.dart';
import 'package:wake_or_pay/services/secret_store.dart';

import '../helpers.dart';

void main() {
  late FakeBillingApi api;
  late InMemorySecretStore secrets;

  Future<ProviderContainer> containerWith({
    FakeBillingApi? billing,
    FakeCardSheet? sheet,
    Map<String, Object> prefs = const {},
  }) async {
    api = billing ?? FakeBillingApi();
    secrets = InMemorySecretStore();
    return testContainer(
      prefs: prefs,
      extra: fakeCardHostageOverrides(
        api: api,
        sheet: sheet,
        secrets: secrets,
      ),
    );
  }

  test('the first enroll registers, opens the sheet, and confirms', () async {
    final sheet = FakeCardSheet();
    final container = await containerWith(sheet: sheet);

    await container.read(cardHostageProvider.notifier).enroll();

    // One device registration, with a UUID generated here and kept.
    expect(api.registered, hasLength(1));
    final installId = api.registered.single.installId;
    expect(
      installId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
    expect(secrets.values[kInstallIdSecretKey], installId);
    expect(secrets.values[kDeviceTokenSecretKey], 'token-1');

    // Then the setup intent, then the sheet, then the confirm — in that order,
    // each carrying the token from the register.
    expect(api.setupIntents.single.token, 'token-1');
    expect(api.setupIntents.single.consent.version, cardHostageConsentVersion);
    expect(api.setupIntents.single.consent.acceptedAt, testNow);
    expect(sheet.presented.single.customerId, 'cus_test');
    // The id, not the whole client secret.
    expect(api.confirmed.single.setupIntentId, 'seti_test_1');

    final state = container.read(cardHostageProvider);
    expect(state.card?.label, 'VISA •••• 4242');
    expect(state.loading, isFalse);
    expect(state.error, isNull);

    // And the row can be drawn on the next launch without a round trip.
    final prefs = container.read(sharedPreferencesProvider);
    expect(
      jsonDecode(prefs.getString(kCardPrefsKey)!),
      {'brand': 'visa', 'last4': '4242', 'expMonth': 12, 'expYear': 2030},
    );
    expect(
      (jsonDecode(prefs.getString(kConsentPrefsKey)!) as Map)['version'],
      cardHostageConsentVersion,
    );
  });

  test('a second enroll reuses the installId and the token', () async {
    final container = await containerWith();
    final notifier = container.read(cardHostageProvider.notifier);

    await notifier.enroll();
    await notifier.enroll();

    expect(api.registered, hasLength(1));
    expect(api.setupIntents.map((s) => s.token), ['token-1', 'token-1']);
  });

  test('a cancelled sheet confirms nothing and says nothing', () async {
    final container = await containerWith(
      sheet: FakeCardSheet(result: const CardSheetResult.cancelled()),
    );

    await container.read(cardHostageProvider.notifier).enroll();

    expect(api.confirmed, isEmpty);
    final state = container.read(cardHostageProvider);
    expect(state.card, isNull);
    expect(state.loading, isFalse);
    // Backing out is what the user meant to do — not a failure to report.
    expect(state.error, isNull);
    expect(
      container.read(sharedPreferencesProvider).getString(kCardPrefsKey),
      isNull,
    );
  });

  test('a refused sheet shows the reason and registers no card', () async {
    final container = await containerWith(
      sheet: FakeCardSheet(result: const CardSheetResult.failed('カードが拒否されました')),
    );

    await container.read(cardHostageProvider.notifier).enroll();

    expect(api.confirmed, isEmpty);
    expect(container.read(cardHostageProvider).error, 'カードが拒否されました');
    expect(container.read(cardHostageProvider).card, isNull);
  });

  test('an unauthorized setup-intent re-registers once and succeeds', () async {
    final container = await containerWith(
      billing: FakeBillingApi(unauthorizedUntilReregister: true),
    );
    // A token from a previous install that the Worker no longer honours.
    secrets.values[kDeviceTokenSecretKey] = 'stale';
    secrets.values[kInstallIdSecretKey] = '11111111-2222-4333-8444-555555555555';

    await container.read(cardHostageProvider.notifier).enroll();

    // Exactly one re-registration, on the same installId — the recovery the
    // contract describes, and not a loop.
    expect(api.registered, hasLength(1));
    expect(
      api.registered.single.installId,
      '11111111-2222-4333-8444-555555555555',
    );
    expect(api.setupIntents.single.token, 'token-1');
    expect(container.read(cardHostageProvider).card?.last4, '4242');
    expect(container.read(cardHostageProvider).error, isNull);
  });

  test('a Worker that refuses everything fails rather than spinning', () async {
    final container = await containerWith(
      billing: FakeBillingApi(failSetupIntentWith: 'server_error'),
    );

    await container.read(cardHostageProvider.notifier).enroll();

    final state = container.read(cardHostageProvider);
    expect(state.loading, isFalse);
    expect(state.error, isNotNull);
    expect(state.card, isNull);
  });

  test('remove calls the Worker and clears both copies', () async {
    final container = await containerWith();
    final notifier = container.read(cardHostageProvider.notifier);
    await notifier.enroll();

    await notifier.remove();

    expect(api.removed, ['token-1']);
    expect(container.read(cardHostageProvider).card, isNull);
    expect(container.read(cardHostageProvider).consent, isNull);
    expect(
      container.read(sharedPreferencesProvider).getString(kCardPrefsKey),
      isNull,
    );
  });

  test('the stored card is read back on the first frame', () async {
    final container = await containerWith(
      prefs: {
        kCardPrefsKey: jsonEncode(
          const HostageCard(
            brand: 'amex',
            last4: '1111',
            expMonth: 3,
            expYear: 2027,
          ).toJson(),
        ),
      },
    );

    // No network call has happened, and the row already has its answer.
    expect(container.read(cardHostageProvider).card?.label, 'AMEX •••• 1111');
    expect(api.registered, isEmpty);
  });

  test('a junk prefs value is 「なし」, not a crash', () async {
    final container = await containerWith(
      prefs: {kCardPrefsKey: 'not json at all'},
    );
    expect(container.read(cardHostageProvider).card, isNull);
  });

  test('refresh takes the Worker as the truth', () async {
    final container = await containerWith();
    api.stored = const HostageCard(
      brand: 'visa',
      last4: '9999',
      expMonth: 6,
      expYear: 2031,
    );

    await container.read(cardHostageProvider.notifier).refresh();

    expect(container.read(cardHostageProvider).card?.last4, '9999');
    expect(api.cardReads, ['token-1']);
  });

  test('newUuidV4 sets the version and variant bits', () {
    for (var i = 0; i < 50; i++) {
      expect(
        newUuidV4(),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );
    }
    expect(newUuidV4(), isNot(newUuidV4()));
  });
}
