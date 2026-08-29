import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/profile_controller.dart';
import 'package:wake_or_pay/app/router.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/shop/shop_screen.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/alarm_service.dart';

import '../helpers.dart';

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  final container = await testContainer(
    prefs: prefs,
    extra: [fakeAlarmServiceOverride()],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// The header's name line, whatever it currently says.
String headerName(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('appHeaderName'))).data!;

void main() {
  testWidgets('every tab wears the header', (tester) async {
    await pumpApp(tester);

    for (final tab in const ['アラーム', 'アクティビティ', '庭', 'ショップ']) {
      await openTab(tester, tab);
      expect(
        find.byKey(const ValueKey('appHeader')),
        findsOneWidget,
        reason: tab,
      );
      expect(find.byKey(const ValueKey('appHeaderAvatar')), findsOneWidget);
      expect(find.byKey(const ValueKey('appHeaderTokens')), findsOneWidget);
      expect(find.byKey(const ValueKey('appHeaderCoins')), findsOneWidget);
    }
  });

  testWidgets('the ringing screen has no header', (tester) async {
    const alarm = Alarm(
      id: 'a1',
      hour: 7,
      minute: 0,
      kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
    );
    final container = await pumpApp(tester);
    await container.read(alarmRepositoryProvider).save(alarm);
    await container
        .read(walletRepositoryProvider)
        .write(const Wallet(coins: 5000));
    final session = await container
        .read(sessionServiceProvider)
        .start(alarm: alarm, firedAt: DateTime.now());

    container.read(appRouterProvider).go(AppRoute.ringing(session.id));
    // The ring screen ticks, so it never settles.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('起きろ！！'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('appHeader')),
      findsNothing,
      reason: 'a firing alarm covers the whole screen and offers no way out',
    );
  });

  testWidgets('the name plate shows Lv and the name, 未設定 when empty', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    expect(headerName(tester), 'Lv1 未設定');

    // 150 XP is exactly level 3 on the published curve.
    await container.read(profileProvider.notifier).addXp(150);
    await container.read(profileProvider.notifier).setUserName('山田花子');
    await tester.pumpAndSettle();

    expect(headerName(tester), 'Lv3 山田花子');
  });

  testWidgets('the balances follow the wallet', (tester) async {
    final container = await pumpApp(tester);
    await container
        .read(walletRepositoryProvider)
        .write(const Wallet(coins: 4200, tokens: 7));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('appHeaderCoins')),
        matching: find.text('4200'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('appHeaderTokens')),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the ＋ beside the coins goes to the ショップ tab', (tester) async {
    await pumpApp(tester);
    expect(find.byType(ShopScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('appHeaderCharge')));
    await tester.pumpAndSettle();

    expect(find.byType(ShopScreen), findsOneWidget);
    expect(find.text('開発用チャージ（+1,000コイン）'), findsOneWidget);
  });

  testWidgets('a long name gives way instead of overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = await pumpApp(tester);
    await container
        .read(profileProvider.notifier)
        .setUserName('あいうえおかきくけこさしすせそたちつてと');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('appHeaderName')), findsOneWidget);
  });
}
