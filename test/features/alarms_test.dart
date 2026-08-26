import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/alarm_service.dart';

import '../helpers.dart';

Future<ProviderContainer> pumpHome(WidgetTester tester, {int coins = 0}) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  if (coins > 0) {
    await container.read(walletRepositoryProvider).write(Wallet(coins: coins));
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('saving a new alarm makes it appear on Home', (tester) async {
    final container = await pumpHome(tester, coins: 5000);
    expect(find.text('アラームはまだありません'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('アラームを追加'), findsOneWidget);

    // Default 07:00, add Monday and Friday, switch on kakugo at 500/min.
    await tester.tap(find.widgetWithText(FilterChip, '月'));
    await tester.tap(find.widgetWithText(FilterChip, '金'));
    await tester.tap(find.text('計算（3問）'));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, '500'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '500'));
    await tester.pumpAndSettle();
    expect(find.text('💀 寝るな'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Back on Home, showing the new alarm.
    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('月・金 ・ 計算（3問）'), findsOneWidget);
    expect(find.text('500 コイン/分 ・ 最大 1000'), findsOneWidget);

    final saved =
        (await container.read(alarmRepositoryProvider).getAll()).single;
    expect(saved.repeatDays, {1, 5});
    expect(saved.wakeCheck, WakeCheckType.math);
    expect(saved.kakugo, const Kakugo(ratePerMinute: 500, cap: 1000));
    expect(saved.enabled, isTrue);

    // Saving also armed the platform alarm.
    final fake = container.read(alarmServiceProvider) as FakeAlarmService;
    expect(fake.scheduled, contains(saved.id));
  });

  testWidgets('a cap above the balance warns but still saves', (tester) async {
    final container = await pumpHome(tester, coins: 100);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('残高より上限が大きい'), findsOneWidget);
    await tester.tap(find.text('このまま保存'));
    await tester.pumpAndSettle();

    expect(
      (await container.read(alarmRepositoryProvider).getAll()),
      hasLength(1),
    );
  });

  testWidgets('the warning can be backed out of without saving', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 100);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('戻る'));
    await tester.pumpAndSettle();

    expect(await container.read(alarmRepositoryProvider).getAll(), isEmpty);
    expect(find.text('アラームを追加'), findsOneWidget, reason: 'still editing');
  });

  testWidgets('the Home switch enables and disables an alarm', (tester) async {
    final container = await pumpHome(tester);
    await container
        .read(alarmRepositoryProvider)
        .save(const Alarm(id: 'a1', hour: 6, minute: 30));
    await tester.pumpAndSettle();

    expect(find.text('06:30'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(
      (await container.read(alarmRepositoryProvider).getById('a1'))!.enabled,
      isFalse,
    );
  });

  testWidgets('nothing in the UI sells anything', (tester) async {
    await pumpHome(tester);
    for (final banned in ['広告', 'スヌーズ', 'プレミアム', 'アップグレード', '課金して']) {
      expect(find.textContaining(banned), findsNothing, reason: banned);
    }
  });
}
