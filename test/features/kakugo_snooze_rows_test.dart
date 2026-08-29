import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/widgets/settings_island.dart';
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

/// What the numeric field found by [finder] currently shows. The field *is* the
/// value display now, so this is how a sub-screen's number is read.
String numberIn(WidgetTester tester, Finder finder) =>
    tester.widget<TextField>(finder).controller!.text;

/// The sub-screen's own numeric field. `.first` because the 寝坊ペナルティ screen
/// carries a second one in its footer — 起床猶予 — below it.
Finder get subScreenNumber =>
    find.byKey(const ValueKey('sliderNumberInput')).first;

const resetTile = ValueKey('snoozeClockReset');
const continuousTile = ValueKey('snoozeClockContinuous');

/// Whether the radio tile behind [key] is the chosen one. The tile is driven by
/// a [RadioGroup] ancestor, so its selection is read off the tile itself.
bool selected(WidgetTester tester, Key key) =>
    tester.widget<RadioListTile<bool>>(find.byKey(key)).selected;

/// Taps one of the 「スヌーズ中の加算」 tiles, scrolling it into view first.
Future<void> tapOption(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// The value shown on the right of a [SettingRow].
String rowValue(WidgetTester tester, String key) =>
    tester.widget<SettingRow>(find.byKey(ValueKey(key))).value;

/// Picks a 人質 in the sub-screen behind the 人質 row.
///
/// A new pledge starts at 「なし」 — 連絡だけの覚悟 — and 人質なし hides every money
/// row, so any test about 寝坊ペナルティ / スヌーズペナルティ / 上限金額 has to say
/// what is at stake first.
Future<void> chooseHostage(WidgetTester tester, String label) async {
  await scrollTo(tester, find.text('人質'));
  await tester.tap(find.text('人質'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// 覚悟 on, with the coins put up: the state the money rows exist in.
Future<void> toggleKakugoWithCoins(WidgetTester tester) async {
  await toggle(tester, '覚悟');
  await chooseHostage(tester, 'コイン');
}

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

    await toggleKakugoWithCoins(tester);
    expect(find.text('寝坊ペナルティ'), findsOneWidget, reason: '覚悟 is on');
    // スヌーズ is on from the start on a new alarm, so the row is there already.
    await scrollTo(tester, find.text('スヌーズペナルティ'));
    expect(find.text('スヌーズペナルティ'), findsOneWidget);

    // It goes away with スヌーズ…
    await toggle(tester, 'スヌーズ');
    expect(find.text('スヌーズペナルティ'), findsNothing);

    // …and comes back with it.
    await toggle(tester, 'スヌーズ');
    await scrollTo(tester, find.text('スヌーズペナルティ'));
    expect(find.text('スヌーズペナルティ'), findsOneWidget);
  });

  testWidgets('スヌーズ中の加算 is no longer a row of the island', (tester) async {
    await openNewAlarm(tester);
    await toggleKakugoWithCoins(tester);
    await scrollTo(tester, find.text('スヌーズペナルティ'));

    expect(
      find.text('スヌーズ中の加算'),
      findsNothing,
      reason: 'it moved into the 寝坊ペナルティ sub-screen',
    );
  });

  testWidgets('with 覚悟 off there is no kakugo island at all', (tester) async {
    await openNewAlarm(tester);

    await scrollTo(tester, find.text('間隔'));
    expect(find.text('間隔'), findsOneWidget, reason: 'the snooze island');
    expect(find.text('スヌーズペナルティ'), findsNothing);
    expect(find.text('寝坊で失う最大金額'), findsNothing);
  });

  testWidgets('the penalty is a slider plus a number, 0 to 1000', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggleKakugoWithCoins(tester);

    // The default the editor seeds.
    await scrollTo(tester, find.text('スヌーズペナルティ'));
    expect(find.text('50 コイン'), findsOneWidget);

    await inSubScreen(tester, 'スヌーズペナルティ', () async {
      expect(find.text('0〜1000コイン'), findsOneWidget);
      await tester.enterText(
        // `.first`: the 寝坊ペナルティ screen carries a second numeric field in
        // its footer — 起床猶予 — and the screen's own field is the one above it.
        find.byKey(const ValueKey('sliderNumberInput')).first,
        '250',
      );
      await tester.pumpAndSettle();
      expect(numberIn(tester, subScreenNumber), '250');
    });

    await scrollTo(tester, find.text('スヌーズペナルティ'));
    expect(find.text('250 コイン'), findsOneWidget);
    expect((await save(tester, container)).kakugo!.snoozePenalty, 250);
  });

  testWidgets('the penalties are bounded by 上限金額, and follow it down', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggleKakugoWithCoins(tester);

    // Raise the cap: the rate may now be set anywhere up to it.
    await inSubScreen(tester, '上限金額', () async {
      await tester.enterText(subScreenNumber, '2500');
      await tester.pumpAndSettle();
    });

    await inSubScreen(tester, '寝坊ペナルティ', () async {
      expect(find.text('10〜2500コイン/分'), findsOneWidget);
      await tester.enterText(subScreenNumber, '2000');
      await tester.pumpAndSettle();
    });
    await scrollTo(tester, find.text('寝坊ペナルティ'));
    expect(find.text('2000 コイン/分'), findsOneWidget);

    // Lower the cap under it and the rate comes down with it.
    await inSubScreen(tester, '上限金額', () async {
      await tester.enterText(subScreenNumber, '500');
      await tester.pumpAndSettle();
    });

    final saved = await save(tester, container);
    expect(saved.kakugo!.cap, 500);
    expect(saved.kakugo!.ratePerMinute, 500, reason: 'clamped to the new cap');
    expect(
      saved.kakugo!.snoozePenalty,
      50,
      reason: '50 is already under 500, so it is left alone',
    );
  });

  testWidgets('lowering 上限金額 under the snooze penalty clamps that too', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggleKakugoWithCoins(tester);

    await inSubScreen(tester, 'スヌーズペナルティ', () async {
      await tester.enterText(subScreenNumber, '800');
      await tester.pumpAndSettle();
    });

    await inSubScreen(tester, '上限金額', () async {
      await tester.enterText(subScreenNumber, '300');
      await tester.pumpAndSettle();
    });

    final saved = await save(tester, container);
    expect(saved.kakugo!.cap, 300);
    expect(saved.kakugo!.snoozePenalty, 300);
    expect(saved.kakugo!.ratePerMinute, 100, reason: 'already under the cap');
  });

  testWidgets('out of range input is clamped, not accepted', (tester) async {
    final container = await openNewAlarm(tester);
    await toggleKakugoWithCoins(tester);

    await inSubScreen(tester, 'スヌーズペナルティ', () async {
      await tester.enterText(
        // `.first`: the 寝坊ペナルティ screen carries a second numeric field in
        // its footer — 起床猶予 — and the screen's own field is the one above it.
        find.byKey(const ValueKey('sliderNumberInput')).first,
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
    await toggleKakugoWithCoins(tester);

    await inSubScreen(tester, 'スヌーズペナルティ', () async {
      await tester.enterText(
        // `.first`: the 寝坊ペナルティ screen carries a second numeric field in
        // its footer — 起床猶予 — and the screen's own field is the one above it.
        find.byKey(const ValueKey('sliderNumberInput')).first,
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
      await toggleKakugoWithCoins(tester);

      await inSubScreen(tester, '寝坊ペナルティ', () async {
        expect(find.text('スヌーズ中の加算'), findsOneWidget);
        expect(find.text('規定時刻から加算し続ける'), findsOneWidget);
        // 改訂5: the pausing mode is the recommended default and reads 「（推奨）」.
        expect(find.text('次に鳴る時刻を起点にし直す（推奨）'), findsOneWidget);

        // Two radios on the left, the recommended one selected to begin with.
        expect(find.byKey(resetTile), findsOneWidget);
        expect(find.byKey(continuousTile), findsOneWidget);
        expect(selected(tester, resetTile), isTrue);
        expect(selected(tester, continuousTile), isFalse);

        // Flip to continuous and back, to prove the choice sticks either way.
        // The sub-screen scrolls, so each tile is brought into view first.
        await tapOption(tester, '規定時刻から加算し続ける');
        expect(selected(tester, continuousTile), isTrue);
        expect(selected(tester, resetTile), isFalse);

        await tapOption(tester, '次に鳴る時刻を起点にし直す（推奨）');
        expect(selected(tester, resetTile), isTrue);
      });

      expect((await save(tester, container)).kakugo!.snoozeResetsClock, isTrue);
    },
  );

  testWidgets('with スヌーズ off the 寝坊ペナルティ sub-screen has no clock mode', (
    tester,
  ) async {
    await openNewAlarm(tester);
    await toggleKakugoWithCoins(tester);
    // Off: this test *is* the off case, and new alarms now start snoozeable.
    await toggle(tester, 'スヌーズ');

    await inSubScreen(tester, '寝坊ペナルティ', () async {
      expect(find.text('スヌーズ中の加算'), findsNothing);
      expect(find.byKey(const ValueKey('kakugoGauge')), findsOneWidget);
    });
  });

  testWidgets('起床猶予 sits in the 寝坊ペナルティ sub-screen even with スヌーズ off', (
    tester,
  ) async {
    await openNewAlarm(tester);
    await toggleKakugoWithCoins(tester);
    // Off: the point of this test is that 起床猶予 is there without スヌーズ.
    await toggle(tester, 'スヌーズ');

    await inSubScreen(tester, '寝坊ペナルティ', () async {
      expect(find.text('起床猶予'), findsOneWidget);
      expect(find.byKey(const ValueKey('graceSelector')), findsOneWidget);
      expect(
        numberIn(
          tester,
          find.descendant(
            of: find.byKey(const ValueKey('graceSelector')),
            matching: find.byKey(const ValueKey('sliderNumberInput')),
          ),
        ),
        '1',
      );
      expect(find.text('1〜5分'), findsOneWidget);
    });
  });

  testWidgets('the header stays the cap, not the cap plus penalties', (
    tester,
  ) async {
    await openNewAlarm(tester);
    await toggleKakugoWithCoins(tester);

    await scrollTo(tester, find.byKey(const ValueKey('maxLoss')));
    expect(find.text('寝坊で失う最大金額'), findsOneWidget);
    expect(
      textOf(tester, const ValueKey('maxLoss')),
      '1000 コイン',
      reason: 'the cap, exactly',
    );

    await inSubScreen(tester, 'スヌーズペナルティ', () async {
      await tester.enterText(
        // `.first`: the 寝坊ペナルティ screen carries a second numeric field in
        // its footer — 起床猶予 — and the screen's own field is the one above it.
        find.byKey(const ValueKey('sliderNumberInput')).first,
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

  testWidgets('人質「なし」 is the pledge that is only the contact', (tester) async {
    final container = await openNewAlarm(tester);
    // No 人質 chosen: 覚悟 on and nothing else. 「0 コイン/分」 used to say this;
    // now the 人質 row does, and it is where a new pledge already starts.
    await toggle(tester, '覚悟');

    await scrollTo(tester, find.text('人質'));
    expect(rowValue(tester, 'hostageRow'), 'なし');

    // Every money row is gone with it, header included.
    expect(find.text('寝坊で失う最大金額'), findsNothing);
    expect(find.byKey(const ValueKey('maxLoss')), findsNothing);
    expect(find.text('寝坊ペナルティ'), findsNothing);
    expect(find.text('スヌーズペナルティ'), findsNothing);
    expect(find.text('上限金額'), findsNothing);
    // What is left is the pledge itself, and who hears about it.
    expect(find.text('寝坊時連絡・共有'), findsOneWidget);

    final saved = await save(tester, container);
    expect(saved.kakugo, isNotNull, reason: '覚悟 is on');
    expect(saved.kakugo!.hostage, HostageType.none);
  });

  testWidgets('choosing コイン brings the money rows back, and seeds the rate', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggleKakugoWithCoins(tester);

    await scrollTo(tester, find.text('寝坊ペナルティ'));
    expect(find.text('寝坊ペナルティ'), findsOneWidget);
    expect(find.text('上限金額'), findsOneWidget);
    expect(find.text('寝坊で失う最大金額'), findsOneWidget);

    await inSubScreen(tester, '寝坊ペナルティ', () async {
      expect(find.text('10〜1000コイン/分'), findsOneWidget);
      // The bound is a clamp, not a suggestion: 5 is typed, 10 is committed.
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')).first,
        '5',
      );
      await tester.pumpAndSettle();
    });

    expect((await save(tester, container)).kakugo!.ratePerMinute, 10);
  });

  testWidgets('the header stays the cap under the smallest rate', (
    tester,
  ) async {
    await openNewAlarm(tester);
    await toggleKakugoWithCoins(tester);

    await inSubScreen(tester, '寝坊ペナルティ', () async {
      await tester.enterText(
        // `.first`: the 寝坊ペナルティ screen carries a second numeric field in
        // its footer — 起床猶予 — and the screen's own field is the one above it.
        find.byKey(const ValueKey('sliderNumberInput')).first,
        '10',
      );
      await tester.pumpAndSettle();
    });

    await scrollTo(tester, find.byKey(const ValueKey('maxLoss')));
    expect(
      textOf(tester, const ValueKey('maxLoss')),
      '1000 コイン',
      reason: '10 コイン/分 plus the 50 コイン snooze penalty still reach the cap',
    );
  });

  testWidgets('nothing in the editor sells or gates a snooze', (tester) async {
    await openNewAlarm(tester);
    await toggleKakugoWithCoins(tester);
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

    // The label carries the same red as the 覚悟の設定 island title: the row is
    // the one place in 基本設定 where money is at stake.
    final context = tester.element(find.text('覚悟'));
    expect(
      tester.widget<Text>(find.text('覚悟')).style?.color,
      Theme.of(context).colorScheme.error,
    );
  });
}
