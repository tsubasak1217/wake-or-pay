import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/garden_catalog.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

Future<ProviderContainer> pumpShop(
  WidgetTester tester, {
  int tokens = 0,
  int coins = 0,
}) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  await container
      .read(walletRepositoryProvider)
      .write(Wallet(coins: coins, tokens: tokens));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('お庭'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('種屋'));
  await tester.pumpAndSettle();
  return container;
}

Finder exchangeButtonFor(String itemId) => find.descendant(
  of: find.byKey(ValueKey('offer-$itemId')),
  matching: find.widgetWithText(TextButton, '交換'),
);

void main() {
  testWidgets('the shop lists the catalogue with its token prices', (
    tester,
  ) async {
    await pumpShop(tester);

    expect(find.text('種屋'), findsWidgets);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('tokenBalance'))).data,
      '🎁 0',
    );
    // The list is lazy, so each entry is scrolled to rather than assumed built.
    for (final def in GardenCatalog.purchasable) {
      final tile = find.byKey(ValueKey('offer-${def.id}'));
      await tester.scrollUntilVisible(tile, 120);
      expect(tile, findsOneWidget, reason: def.id);
    }
  });

  testWidgets('an unaffordable item cannot be exchanged', (tester) async {
    final container = await pumpShop(tester, tokens: 10, coins: 999999);

    final button = tester.widget<TextButton>(exchangeButtonFor('plant_moss'));
    expect(button.onPressed, isNull, reason: 'a pile of coins is not tokens');
    expect(
      (await container.read(gardenRepositoryProvider).read()).inventory.countOf(
        'plant_moss',
      ),
      1,
      reason: 'only the free one from the first grant',
    );
  });

  testWidgets('exchanging spends tokens and fills the shelf', (tester) async {
    final container = await pumpShop(tester, tokens: 100, coins: 5000);

    await tester.tap(exchangeButtonFor('plant_moss'));
    await tester.pumpAndSettle();

    final wallet = await container.read(walletRepositoryProvider).read();
    expect(wallet.tokens, 70);
    expect(wallet.coins, 5000, reason: 'coins are never touched');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('tokenBalance'))).data,
      '🎁 70',
      reason: 'the balance updated',
    );
    expect(find.textContaining('手に入れました'), findsOneWidget);

    // And it is on the shelf in the editor.
    await tester.pageBack();
    // Let the snackbar time out; it sits over the buttons until it does.
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.text('模様替え'));
    await tester.pumpAndSettle();
    expect(find.text('×2'), findsNWidgets(2), reason: 'moss and pebbles');
  });

  testWidgets('spending everything disables the rest', (tester) async {
    await pumpShop(tester, tokens: 30);

    await tester.tap(exchangeButtonFor('plant_moss'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('tokenBalance'))).data,
      '🎁 0',
    );
    expect(
      tester.widget<TextButton>(exchangeButtonFor('plant_moss')).onPressed,
      isNull,
    );
  });

  testWidgets('the shop shows no coins and sells nothing it should not', (
    tester,
  ) async {
    await pumpShop(tester, tokens: 500, coins: 12345);

    expect(find.textContaining('🪙'), findsNothing);
    expect(find.textContaining('12345'), findsNothing);
    for (final banned in ['広告', 'スタミナ', 'ルーレット', '課金', 'コインで購入']) {
      expect(find.textContaining(banned), findsNothing, reason: banned);
    }
  });
}
