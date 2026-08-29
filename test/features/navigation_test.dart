import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/features/activity/activity_screen.dart';
import 'package:wake_or_pay/features/alarms/home_screen.dart';
import 'package:wake_or_pay/features/garden/garden_screen.dart';
import 'package:wake_or_pay/features/shop/shop_screen.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

Future<void> pumpApp(WidgetTester tester) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// 設定 is reached from オプション now that ショップ carries no links of its own.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('appHeaderOptions')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('optionsSettingsRow')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the app opens on the alarm tab', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('the four tabs are アラーム / アクティビティ / 庭 / ショップ, in order', (
    tester,
  ) async {
    await pumpApp(tester);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 4);
    expect(
      [
        for (final d in bar.destinations)
          ((d as NavigationDestination).label),
      ],
      ['アラーム', 'アクティビティ', '庭', 'ショップ'],
    );
  });

  testWidgets('each tab shows its own screen', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('アクティビティ'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityScreen), findsOneWidget);

    await tester.tap(find.text('庭'));
    await tester.pumpAndSettle();
    expect(find.byType(GardenScreen), findsOneWidget);

    await tester.tap(find.text('ショップ'));
    await tester.pumpAndSettle();
    expect(find.byType(ShopScreen), findsOneWidget);

    await tester.tap(find.text('アラーム'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('the header ＋ lands on ショップ', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('appHeaderCharge')));
    await tester.pumpAndSettle();

    expect(find.byType(ShopScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
  });

  testWidgets('settings is reachable from オプション', (tester) async {
    await pumpApp(tester);
    await openSettings(tester);

    expect(find.widgetWithText(AppBar, '設定'), findsOneWidget);
    // Full screen: the tab bar is not stacked underneath the settings screen,
    // and neither is the sheet it was opened from.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('optionsOverlay')), findsNothing);
  });
}
