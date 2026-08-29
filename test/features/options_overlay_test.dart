import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/data/repositories/options_repository.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/widgets/settings_island.dart';
import 'package:wake_or_pay/features/options/options_overlay.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/options.dart';

import '../helpers.dart';

/// オプション — the sheet behind the ⚙ at the right of the header, and the
/// 危険な設定 island inside it.

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Alarm? existing,
}) async {
  final container = await testContainer(
    prefs: prefs,
    extra: [fakeAlarmServiceOverride()],
  );
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 1000000));
  if (existing != null) {
    await container.read(alarmRepositoryProvider).save(existing);
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

Future<ProviderContainer> openOptions(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  final container = await pumpApp(tester, prefs: prefs);
  await tester.tap(find.byKey(const ValueKey('appHeaderOptions')));
  await tester.pumpAndSettle();
  return container;
}

String rowValue(WidgetTester tester, String key) =>
    tester.widget<SettingRow>(find.byKey(ValueKey(key))).value;

/// [inner], but only where it sits inside 上限金額の最大値 — the routes below an
/// opaque page route are still in the tree and still findable.
Finder onCeilingScreen(Finder inner) =>
    find.descendant(of: find.byType(CapCeilingScreen), matching: inner);

Future<void> openCeilingScreen(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('optionsCapCeilingRow')));
  await tester.pumpAndSettle();
}

/// What 上限金額の最大値's field currently says.
String ceilingFieldText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('capCeilingInput')))
    .controller!
    .text;

/// Opens 上限金額の最大値, types [text] into the field and presses 決定.
Future<void> typeCeiling(WidgetTester tester, String text) async {
  await openCeilingScreen(tester);
  await tester.enterText(find.byKey(const ValueKey('capCeilingInput')), text);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('capCeilingSave')));
  await tester.pumpAndSettle();
}

// --- the editor side of the same setting ------------------------------------

Finder get editorScrollable => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  tester.state<ScrollableState>(editorScrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 120, scrollable: editorScrollable);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> toggle(WidgetTester tester, String label) async {
  await scrollTo(tester, find.text(label));
  await tester.tap(find.widgetWithText(SwitchListTile, label));
  await tester.pumpAndSettle();
}

/// The 人質 sub-screen, same as `kakugo_snooze_rows_test.dart`: a new pledge
/// starts at なし and hides every money row, so 上限金額 needs a stake first.
Future<void> chooseHostage(WidgetTester tester, String label) async {
  await scrollTo(tester, find.text('人質'));
  await tester.tap(find.text('人質'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// The 「100〜NNNNNコイン」 line under the 上限金額 slider — the bound, as the
/// screen states it.
Future<String> capRangeLabel(WidgetTester tester) async {
  await scrollTo(tester, find.text('上限金額'));
  await tester.tap(find.text('上限金額'));
  await tester.pumpAndSettle();
  final label = tester
      .widgetList<Text>(find.textContaining('〜'))
      .map((t) => t.data!)
      .firstWhere((t) => t.endsWith('コイン'));
  await tester.pageBack();
  await tester.pumpAndSettle();
  return label;
}

void main() {
  testWidgets('the ⚙ opens オプション, and 閉じる puts it away', (tester) async {
    await openOptions(tester);

    expect(find.byKey(const ValueKey('optionsOverlay')), findsOneWidget);
    expect(find.text('オプション'), findsWidgets);
    expect(find.text('アプリ'), findsOneWidget);
    expect(find.text('危険な設定'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('optionsOverlayClose')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('optionsOverlay')), findsNothing);
    // Non-opaque, exactly like プロフィール: the tab it covered was never left.
    expect(find.byKey(const ValueKey('appHeader')), findsOneWidget);
  });

  testWidgets('a downward flick puts it away too', (tester) async {
    await openOptions(tester);

    await tester.fling(
      find.byKey(const ValueKey('optionsOverlayHandle')),
      const Offset(0, 300),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('optionsOverlay')), findsNothing);
  });

  testWidgets('アプリの更新 lives in オプション and no longer in プロフィール', (
    tester,
  ) async {
    await openOptions(tester);
    expect(find.byKey(const ValueKey('optionsUpdateRow')), findsOneWidget);
    expect(find.text('アプリの更新'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('optionsOverlayClose')));
    await tester.pumpAndSettle();

    // And the profile it came from does not have it any more, under either name.
    await tester.tap(find.byKey(const ValueKey('appHeaderAvatar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profileOverlay')), findsOneWidget);
    expect(find.byKey(const ValueKey('profileUpdateRow')), findsNothing);
    expect(find.byKey(const ValueKey('optionsUpdateRow')), findsNothing);
    expect(find.text('アプリの更新'), findsNothing);
  });

  testWidgets('上限金額の最大値 starts at 10,000 コイン and says what it is', (
    tester,
  ) async {
    await openOptions(tester);

    expect(rowValue(tester, 'optionsCapCeilingRow'), '10,000 コイン');
    expect(find.text('上限金額の最大値'), findsOneWidget);
    expect(
      find.textContaining('クレジットカードを人質にしたアラームでは、この金額までが実際に請求されます。'),
      findsOneWidget,
    );
  });

  testWidgets('the ceiling is typed, not picked off a list of prices', (
    tester,
  ) async {
    await openOptions(tester);
    await openCeilingScreen(tester);

    // One field, prefilled with what is stored, and no menu of amounts.
    expect(find.byKey(const ValueKey('capCeilingInput')), findsOneWidget);
    expect(ceilingFieldText(tester), '10000');
    expect(onCeilingScreen(find.text('コイン')), findsOneWidget);
    expect(find.text('決定'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.textContaining('いくらにするかはあなた次第です'), findsOneWidget);

    // And no range is stated anywhere: the clamp is silent by design.
    expect(onCeilingScreen(find.textContaining('〜')), findsNothing);
    for (final banned in ['1,000,000', '1000000', '300,000', '30,000']) {
      expect(
        onCeilingScreen(find.textContaining(banned)),
        findsNothing,
        reason: banned,
      );
    }
  });

  testWidgets('決定 is dead until the field says a number', (tester) async {
    await openOptions(tester);
    await openCeilingScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('capCeilingInput')),
      '',
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('capCeilingSave')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('raising it asks first, and やめる changes nothing', (
    tester,
  ) async {
    final container = await openOptions(tester);

    await typeCeiling(tester, '100000');

    expect(find.byKey(const ValueKey('capCeilingConfirm')), findsOneWidget);
    expect(find.text('本当に上げますか？'), findsOneWidget);
    expect(
      find.textContaining('寝坊 1 回でこの金額まで請求されることがあります'),
      findsOneWidget,
    );

    await tester.tap(find.text('やめる'));
    await tester.pumpAndSettle();

    expect(container.read(capCeilingProvider), 10000);
    // Still on the choice screen, with nothing written.
    expect(
      OptionsRepository(container.read(sharedPreferencesProvider))
          .read()
          .capCeiling,
      10000,
    );
  });

  testWidgets('上げる stores it, and the editor offers the new ceiling', (
    tester,
  ) async {
    final container = await openOptions(tester);

    await typeCeiling(tester, '100000');
    await tester.tap(find.text('上げる'));
    await tester.pumpAndSettle();

    expect(container.read(capCeilingProvider), 100000);
    expect(
      OptionsRepository(container.read(sharedPreferencesProvider))
          .read()
          .capCeiling,
      100000,
      reason: 'the next launch has to find the same answer',
    );

    // The screen stays open, showing what was actually accepted.
    expect(ceilingFieldText(tester), '100000');

    // Back on the sheet, showing the number it now holds.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(rowValue(tester, 'optionsCapCeilingRow'), '100,000 コイン');

    // And the editor's 上限金額 is bounded by it.
    await tester.tap(find.byKey(const ValueKey('optionsOverlayClose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await toggle(tester, '覚悟');
    await chooseHostage(tester, 'コイン');

    expect(await capRangeLabel(tester), '100〜100000コイン');
  });

  testWidgets('lowering it needs no confirmation', (tester) async {
    final container = await openOptions(
      tester,
      prefs: {OptionsRepository.capCeilingKey: 100000},
    );
    expect(rowValue(tester, 'optionsCapCeilingRow'), '100,000 コイン');

    await typeCeiling(tester, '10000');

    expect(find.byKey(const ValueKey('capCeilingConfirm')), findsNothing);
    expect(container.read(capCeilingProvider), 10000);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(rowValue(tester, 'optionsCapCeilingRow'), '10,000 コイン');
  });

  testWidgets('a number over the bound is clamped in silence, not refused', (
    tester,
  ) async {
    final container = await openOptions(tester);

    await typeCeiling(tester, '5000000');
    // Higher than what is stored, so the confirmation still applies — the
    // clamp is not a rejection, it is the number the app agreed to.
    expect(find.byKey(const ValueKey('capCeilingConfirm')), findsOneWidget);
    await tester.tap(find.text('上げる'));
    await tester.pumpAndSettle();

    expect(container.read(capCeilingProvider), absoluteMaxKakugoCap);
    expect(
      OptionsRepository(container.read(sharedPreferencesProvider))
          .read()
          .capCeiling,
      absoluteMaxKakugoCap,
    );
    // No error anywhere — the field simply says what was accepted.
    expect(ceilingFieldText(tester), '$absoluteMaxKakugoCap');
    expect(onCeilingScreen(find.textContaining('エラー')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('capCeilingInput')))
          .decoration!
          .errorText,
      isNull,
    );
  });

  testWidgets('a tiny ceiling still leaves the editor a usable slider', (
    tester,
  ) async {
    await openOptions(tester);
    await typeCeiling(tester, '50');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Lower than the default, so nothing was confirmed and 50 is stored.
    expect(find.byKey(const ValueKey('capCeilingConfirm')), findsNothing);
    expect(rowValue(tester, 'optionsCapCeilingRow'), '50 コイン');

    await tester.tap(find.byKey(const ValueKey('optionsOverlayClose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await toggle(tester, '覚悟');
    await chooseHostage(tester, 'コイン');

    // effectiveCapCeiling floors at minKakugoCap, so max is never under min.
    expect(await capRangeLabel(tester), '100〜1000コイン');
  });

  testWidgets('an alarm saved above the ceiling still opens at its own cap', (
    tester,
  ) async {
    // The ceiling is back at the default; this alarm was saved when it was not.
    await pumpApp(
      tester,
      existing: const Alarm(
        id: 'a1',
        hour: 6,
        minute: 30,
        kakugo: Kakugo(
          hostage: HostageType.coin,
          ratePerMinute: 100,
          cap: 50000,
        ),
      ),
    );
    await tester.tap(find.text('06:30'));
    await tester.pumpAndSettle();

    // effectiveCapCeiling: the editor does not drag a stored pledge down.
    expect(await capRangeLabel(tester), '100〜50000コイン');
  });

  testWidgets('危険な設定 sells nothing', (tester) async {
    await openOptions(tester);
    await tester.tap(find.byKey(const ValueKey('optionsCapCeilingRow')));
    await tester.pumpAndSettle();

    for (final word in ['課金', '購入', '広告']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  });
}
