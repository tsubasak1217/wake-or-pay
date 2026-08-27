import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/features/alarms/home_screen.dart';
import 'package:wake_or_pay/features/garden/garden_screen.dart';
import 'package:wake_or_pay/features/wallet/wallet_screen.dart';
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

  testWidgets('the three tabs switch between alarm, garden and wallet', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('お庭'));
    await tester.pumpAndSettle();
    expect(find.byType(GardenScreen), findsOneWidget);

    await tester.tap(find.text('ウォレット'));
    await tester.pumpAndSettle();
    expect(find.byType(WalletScreen), findsOneWidget);

    await tester.tap(find.text('アラーム'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('settings is reachable from the wallet tab', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('ウォレット'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定・テーマ'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '設定'), findsOneWidget);
    // Full screen: the tab bar is not stacked underneath the settings screen.
    expect(find.byType(NavigationBar), findsNothing);
  });
}
