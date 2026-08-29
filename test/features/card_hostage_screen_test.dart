import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/profile/card_hostage_screen.dart';
import 'package:wake_or_pay/services/card_hostage.dart';
import 'package:wake_or_pay/services/card_sheet.dart';
import 'package:wake_or_pay/services/secret_store.dart';

import '../helpers.dart';
import 'profile_overlay_test.dart' show openOverlay, scrollTo;

/// The screen on its own, with both halves of the flow faked.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester, {
  FakeBillingApi? api,
  FakeCardSheet? sheet,
  InMemorySecretStore? secrets,
  Map<String, Object> prefs = const {},
}) async {
  final container = await testContainer(
    prefs: prefs,
    extra: fakeCardHostageOverrides(api: api, sheet: sheet, secrets: secrets),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CardHostageScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('カードを登録 is dead until the mandate is ticked', (tester) async {
    await pumpScreen(tester);

    expect(find.text(cardHostageMandateText), findsOneWidget);
    final button = find.byKey(const ValueKey('cardHostageEnroll'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('cardHostageConsent')));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('ticking, then 登録, ends in the enrolled state', (tester) async {
    final api = FakeBillingApi();
    final container = await pumpScreen(tester, api: api);

    await tester.tap(find.byKey(const ValueKey('cardHostageConsent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cardHostageEnroll')));
    await tester.pumpAndSettle();

    expect(api.confirmed, hasLength(1));
    expect(container.read(cardHostageProvider).card?.last4, '4242');
    expect(find.text('VISA •••• 4242'), findsOneWidget);
    expect(find.text('有効期限 12/30'), findsOneWidget);
    // Phase 1 says so out loud rather than implying a charge that cannot
    // happen yet.
    expect(find.text('請求の仕組みは準備中です。いまはカードの登録だけができます。'), findsOneWidget);
    expect(find.byKey(const ValueKey('cardHostageRemove')), findsOneWidget);
    expect(find.byKey(const ValueKey('cardHostageError')), findsNothing);
  });

  testWidgets('a refusal is shown on the screen, in the error colour', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      sheet: FakeCardSheet(result: const CardSheetResult.failed('カードが拒否されました')),
    );

    await tester.tap(find.byKey(const ValueKey('cardHostageConsent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cardHostageEnroll')));
    await tester.pumpAndSettle();

    final error = find.byKey(const ValueKey('cardHostageError'));
    expect(error, findsOneWidget);
    expect(tester.widget<Text>(error).data, 'カードが拒否されました');
    final theme = Theme.of(tester.element(error));
    expect(tester.widget<Text>(error).style?.color, theme.colorScheme.error);
    // Still the not-enrolled screen: nothing was registered.
    expect(find.byKey(const ValueKey('cardHostageEnroll')), findsOneWidget);
  });

  testWidgets('a cancelled sheet leaves the screen exactly as it was', (
    tester,
  ) async {
    final api = FakeBillingApi();
    await pumpScreen(
      tester,
      api: api,
      sheet: FakeCardSheet(result: const CardSheetResult.cancelled()),
    );

    await tester.tap(find.byKey(const ValueKey('cardHostageConsent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cardHostageEnroll')));
    await tester.pumpAndSettle();

    expect(api.confirmed, isEmpty);
    expect(find.byKey(const ValueKey('cardHostageError')), findsNothing);
    expect(find.byKey(const ValueKey('cardHostageEnroll')), findsOneWidget);
  });

  testWidgets('解除 asks first, and やめる keeps the card', (tester) async {
    final api = FakeBillingApi();
    final container = await pumpScreen(tester, api: api);
    await container.read(cardHostageProvider.notifier).enroll();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cardHostageRemove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cardHostageRemoveDialog')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cardHostageRemoveCancel')));
    await tester.pumpAndSettle();

    expect(api.removed, isEmpty);
    expect(container.read(cardHostageProvider).card, isNotNull);
  });

  testWidgets('解除 → 解除する takes the card back', (tester) async {
    final api = FakeBillingApi();
    final container = await pumpScreen(tester, api: api);
    await container.read(cardHostageProvider.notifier).enroll();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cardHostageRemove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cardHostageRemoveConfirm')));
    await tester.pumpAndSettle();

    expect(api.removed, hasLength(1));
    expect(container.read(cardHostageProvider).card, isNull);
    // Back to the not-enrolled screen, mandate and all.
    expect(find.byKey(const ValueKey('cardHostageEnroll')), findsOneWidget);
  });

  testWidgets('the screen sells nothing — the banned words are absent', (
    tester,
  ) async {
    await pumpScreen(tester);

    // The same rule the garden and the seed shop are held to. カード人質 is the
    // 罰 half of Wake or Pay, not a thing being sold.
    for (final banned in ['広告', 'スタミナ', 'ルーレット', '課金', '購入', 'プレミアム']) {
      expect(
        find.textContaining(banned),
        findsNothing,
        reason: '「$banned」がカード人質の画面に出ています',
      );
    }
  });

  testWidgets('the profile row reads 未連携, then 連携済み after an enroll', (
    tester,
  ) async {
    final api = FakeBillingApi();
    final container = await openOverlay(
      tester,
      extra: fakeCardHostageOverrides(api: api),
    );

    final row = find.byKey(const ValueKey('profileCardHostageRow'));
    await scrollTo(tester, row);
    // The row, not the screen: the screen it opens is still 「〜を人質にする」.
    expect(find.text('クレジットカード'), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('未連携')),
      findsOneWidget,
    );

    await container.read(cardHostageProvider.notifier).enroll();
    await tester.pumpAndSettle();
    await scrollTo(tester, row);

    // 連携情報 says whether there is a card, never which one: the brand and the
    // last four are a detail of the link, and they live on the screen behind
    // the row.
    expect(
      find.descendant(of: row, matching: find.text('連携済み')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('VISA •••• 4242')),
      findsNothing,
    );
  });

  testWidgets('the profile row opens the screen', (tester) async {
    await openOverlay(tester, extra: fakeCardHostageOverrides());

    final row = find.byKey(const ValueKey('profileCardHostageRow'));
    await scrollTo(tester, row);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cardHostageConsent')), findsOneWidget);
  });
}
