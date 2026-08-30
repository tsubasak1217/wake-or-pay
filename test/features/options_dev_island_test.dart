import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/sample_data.dart';

import '../helpers.dart';

/// オプション › 開発用 — the two rows that fill and empty the charts.

Future<ProviderContainer> openOptions(WidgetTester tester) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('appHeaderOptions')));
  await tester.pumpAndSettle();
  return container;
}

Future<void> tapRow(WidgetTester tester, String key) async {
  final row = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(row, 120);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<List<AlarmSession>> sessionsOf(ProviderContainer container) =>
    container.read(alarmSessionRepositoryProvider).getRecent(limit: 100000);

void main() {
  testWidgets('the 開発用 island says what it is and offers two rows', (
    tester,
  ) async {
    await openOptions(tester);

    final island = find.byKey(const ValueKey('optionsDevIsland'));
    await tester.scrollUntilVisible(island, 120);

    expect(island, findsOneWidget);
    expect(find.text('開発用'), findsOneWidget);
    expect(find.text('サンプルデータを作成（過去12か月）'), findsOneWidget);
    expect(find.text('サンプルデータを削除'), findsOneWidget);
    expect(find.text('開発中の確認用です。実際の記録には影響しません。'), findsOneWidget);
  });

  testWidgets('作成 asks first, and やめる writes nothing', (tester) async {
    final container = await openOptions(tester);

    await tapRow(tester, 'optionsSampleCreate');
    expect(
      find.byKey(const ValueKey('optionsSampleCreateConfirm')),
      findsOneWidget,
    );

    await tester.tap(find.text('やめる'));
    await tester.pumpAndSettle();

    expect(await sessionsOf(container), isEmpty);
  });

  testWidgets('作成する fills the charts and says how many rows it wrote', (
    tester,
  ) async {
    final container = await openOptions(tester);

    await tapRow(tester, 'optionsSampleCreate');
    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();

    final sessions = await sessionsOf(container);
    expect(sessions.length, greaterThan(250));
    expect(sessions.every((s) => s.id.startsWith(sampleIdPrefix)), isTrue);
    expect(
      find.byKey(const ValueKey('optionsSampleProgress')),
      findsNothing,
      reason: 'the spinner is taken away again',
    );
    // findsWidgets, not findsOneWidget: the sheet is a Scaffold stacked over
    // the tab's Scaffold, and one ScaffoldMessenger paints its SnackBar into
    // every Scaffold registered with it — two copies of one message.
    expect(find.textContaining('サンプルデータを作成しました（'), findsWidgets);
    expect(find.textContaining(' 件）'), findsWidgets);
  });

  testWidgets('削除する empties it again, and leaves a real morning alone', (
    tester,
  ) async {
    final container = await openOptions(tester);
    await container.read(alarmSessionRepositoryProvider).save(
      AlarmSession(
        id: 'real-1',
        alarmId: 'a1',
        firedAt: DateTime(2026, 8, 20, 7),
        dismissedAt: DateTime(2026, 8, 20, 7, 2),
        status: SessionStatus.success,
      ),
    );

    await tapRow(tester, 'optionsSampleCreate');
    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();
    expect((await sessionsOf(container)).length, greaterThan(250));

    // Let the create SnackBar go before the next one.
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tapRow(tester, 'optionsSampleDelete');
    expect(
      find.byKey(const ValueKey('optionsSampleDeleteConfirm')),
      findsOneWidget,
    );
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();

    expect((await sessionsOf(container)).map((s) => s.id), ['real-1']);
    expect(find.text('サンプルデータを削除しました'), findsWidgets);
  });

  testWidgets('開発用 sells nothing', (tester) async {
    await openOptions(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('optionsDevIsland')),
      120,
    );

    for (final word in ['課金', '購入', '広告']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }

    // And the confirmations do not either.
    await tapRow(tester, 'optionsSampleCreate');
    for (final word in ['課金', '購入', '広告']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
    await tester.tap(find.text('やめる'));
    await tester.pumpAndSettle();

    await tapRow(tester, 'optionsSampleDelete');
    for (final word in ['課金', '購入', '広告']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  });
}
