import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

/// The editor's own scroll view; the time wheel brings scrollables of its own.
Finder get editorScrollable => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

/// scrollUntilVisible only ever scrolls one way, so anything already above the
/// viewport would be scrolled further away. Start from the top every time.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  tester.state<ScrollableState>(editorScrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 120, scrollable: editorScrollable);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

/// The text of the widget behind [key], which is how a value is read when the
/// same string appears in more than one row.
String textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

Future<void> toggle(WidgetTester tester, String label) async {
  await scrollTo(tester, find.text(label));
  await tester.tap(find.widgetWithText(SwitchListTile, label));
  await tester.pumpAndSettle();
}

Future<void> inSubScreen(
  WidgetTester tester,
  String row,
  Future<void> Function() inside,
) async {
  await scrollTo(tester, find.text(row));
  await tester.tap(find.text(row));
  await tester.pumpAndSettle();
  await inside();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

Future<ProviderContainer> openNewAlarm(WidgetTester tester) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 100000));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  return container;
}

Future<Alarm> save(WidgetTester tester, ProviderContainer container) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  return (await container.read(alarmRepositoryProvider).getAll()).single;
}

void main() {
  testWidgets('the snooze penalty row appears only when スヌーズ is on', (
    tester,
  ) async {
    await openNewAlarm(tester);

    await toggle(tester, '覚悟');
    expect(find.text('寝坊ペナルティ'), findsOneWidget, reason: '覚悟 is on');
    expect(find.text('スヌーズペナルティ'), findsNothing);

    await toggle(tester, 'スヌーズ');
    await scrollTo(tester, find.text('スヌーズペナルティ'));
    expect(find.text('スヌーズペナルティ'), findsOneWidget);

    // And it goes away again with it.
    await toggle(tester, 'スヌーズ');
    expect(find.text('スヌーズペナルティ'), findsNothing);
  });

  testWidgets('スヌーズ中の加算 is no longer a row of the island', (tester) async {
    await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await toggle(tester, 'スヌーズ');
    await scrollTo(tester, find.text('スヌーズペナルティ'));

    expect(
      find.text('スヌーズ中の加算'),
      findsNothing,
      reason: 'it moved into the 寝坊ペナルティ sub-screen',
    );
  });

  testWidgets('with 覚悟 off there is no kakugo island at all', (tester) async {
    await openNewAlarm(tester);

    await toggle(tester, 'スヌーズ');
    expect(find.text('間隔'), findsOneWidget, reason: 'the snooze island');
    expect(find.text('スヌーズペナルティ'), findsNothing);
    expect(find.text('寝坊で失う最大金額'), findsNothing);
  });

  testWidgets('the penalty is a slider plus a number, 0 to 1000', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await toggle(tester, 'スヌーズ');

    // The default the editor seeds.
    await scrollTo(tester, find.text('スヌーズペナルティ'));
    expect(find.text('50 コイン'), findsOneWidget);

    await inSubScreen(tester, 'スヌーズペナルティ', () async {
      expect(find.text('0〜1000コイン'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '250',
      );
      await tester.pumpAndSettle();
      expect(find.text('250コイン'), findsOneWidget);
    });

    await scrollTo(tester, find.text('スヌーズペナルティ'));
    expect(find.text('250 コイン'), findsOneWidget);
    expect((await save(tester, container)).kakugo!.snoozePenalty, 250);
  });

  testWidgets('out of range input is clamped, not accepted', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await toggle(tester, 'スヌーズ');

    await inSubScreen(tester, 'スヌーズペナルティ', () async {
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '99999',
      );
      await tester.pumpAndSettle();
    });
    expect((await save(tester, container)).kakugo!.snoozePenalty, 1000);
  });

  testWidgets('0 is a real choice: snoozing stays free under a pledge', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await toggle(tester, 'スヌーズ');

    await inSubScreen(tester, 'スヌーズペナルティ', () async {
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '0',
      );
      await tester.pumpAndSettle();
    });
    expect((await save(tester, container)).kakugo!.snoozePenalty, 0);
  });

  testWidgets(
    'the clock mode is a two option choice inside the 寝坊ペナルティ sub-screen',
    (tester) async {
      final container = await openNewAlarm(tester);
      await toggle(tester, '覚悟');
      await toggle(tester, 'スヌーズ');

      await inSubScreen(tester, '寝坊ペナルティ', () async {
        expect(find.text('スヌーズ中の加算'), findsOneWidget);
        expect(find.text('規定時刻から加算し続ける'), findsOneWidget);
        // 改訂5: the pausing mode is the recommended default and reads 「（推奨）」.
        expect(find.text('次に鳴る時刻を起点にし直す（推奨）'), findsOneWidget);
        // Flip to continuous and back, to prove the choice sticks either way.
        await tester.tap(find.text('規定時刻から加算し続ける'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('次に鳴る時刻を起点にし直す（推奨）'));
        await tester.pumpAndSettle();
      });

      expect((await save(tester, container)).kakugo!.snoozeResetsClock, isTrue);
    },
  );

  testWidgets('with スヌーズ off the 寝坊ペナルティ sub-screen has no clock mode', (
    tester,
  ) async {
    await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inSubScreen(tester, '寝坊ペナルティ', () async {
      expect(find.text('スヌーズ中の加算'), findsNothing);
      expect(find.byKey(const ValueKey('kakugoGauge')), findsOneWidget);
    });
  });

  testWidgets('the header stays the cap, not the cap plus penalties', (
    tester,
  ) async {
    await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await toggle(tester, 'スヌーズ');

    await scrollTo(tester, find.byKey(const ValueKey('maxLoss')));
    expect(find.text('寝坊で失う最大金額'), findsOneWidget);
    expect(
      textOf(tester, const ValueKey('maxLoss')),
      '1000 コイン',
      reason: 'the cap, exactly',
    );

    await inSubScreen(tester, 'スヌーズペナルティ', () async {
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '1000',
      );
      await tester.pumpAndSettle();
    });

    await scrollTo(tester, find.byKey(const ValueKey('maxLoss')));
    expect(
      textOf(tester, const ValueKey('maxLoss')),
      '1000 コイン',
      reason: 'the cap clamps the whole loss, penalties included',
    );
  });

  testWidgets('寝坊ペナルティ can be 0: a pledge that is only the phone call', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inSubScreen(tester, '寝坊ペナルティ', () async {
      expect(find.text('0〜1000コイン/分'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '0',
      );
      await tester.pumpAndSettle();
      expect(textOf(tester, const ValueKey('kakugoGauge')), '😌 ペナルティなし');
    });

    await scrollTo(tester, find.byKey(const ValueKey('maxLoss')));
    expect(
      textOf(tester, const ValueKey('maxLoss')),
      '0 コイン',
      reason: 'nothing can reach the cap: no rate, and no snooze either',
    );

    expect((await save(tester, container)).kakugo!.ratePerMinute, 0);
  });

  testWidgets('a 0 コイン/分 pledge still shows the cap if snoozing costs', (
    tester,
  ) async {
    await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await toggle(tester, 'スヌーズ');

    await inSubScreen(tester, '寝坊ペナルティ', () async {
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '0',
      );
      await tester.pumpAndSettle();
    });

    await scrollTo(tester, find.byKey(const ValueKey('maxLoss')));
    expect(
      textOf(tester, const ValueKey('maxLoss')),
      '1000 コイン',
      reason: 'the 50 コイン snooze penalty can still add up to the cap',
    );
  });

  testWidgets('nothing in the editor sells or gates a snooze', (tester) async {
    await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await toggle(tester, 'スヌーズ');
    await scrollTo(tester, find.text('スヌーズペナルティ'));

    for (final forbidden in const ['広告', '課金', 'スヌーズを購入', 'プレミアム', '購入']) {
      expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
    }
    // The 「無料の標準機能です」 subtitle is gone from the スヌーズ toggle: the row
    // says nothing about price at all, which is the same promise in fewer words.
    await scrollTo(tester, find.text('スヌーズ'));
    expect(find.text('無料の標準機能です'), findsNothing);
  });

  testWidgets('the 覚悟 toggle explains itself in one line', (tester) async {
    await openNewAlarm(tester);
    await scrollTo(tester, find.text('覚悟'));
    expect(find.text('起床に対するあなたの"覚悟"を設定できます'), findsOneWidget);
  });
}
