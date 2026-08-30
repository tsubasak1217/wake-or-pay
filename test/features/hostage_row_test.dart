import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/theme.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/widgets/settings_island.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/card_hostage.dart';

import '../helpers.dart';

/// 人質 — the first row of 覚悟の設定, and the one that decides whether the rest
/// of the island exists at all.

const _card = HostageCard(
  brand: 'visa',
  last4: '4242',
  expMonth: 12,
  expYear: 2030,
);

/// A prefs map with a card already registered. [CardHostageService] reads its
/// first state straight off prefs, so this is a card the editor sees on the
/// first frame — no network, no sheet.
Map<String, Object> get _enrolledPrefs => {
  kCardPrefsKey: jsonEncode(_card.toJson()),
};

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

SettingRow rowOf(WidgetTester tester, String key) =>
    tester.widget<SettingRow>(find.byKey(ValueKey(key)));

List<String> islandRows(WidgetTester tester, String title) => tester
    .widgetList<SettingRow>(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is SettingsIsland && w.title == title,
        ),
        matching: find.byType(SettingRow),
      ),
    )
    .map((row) => row.label)
    .toList();

/// One person in the 連絡帳, so a test can give an alarm somebody to tell.
Future<void> seedBook(ProviderContainer container) =>
    container
        .read(contactBookRepositoryProvider)
        .save(
          ContactEntry(
            id: 'c1',
            name: '田中太郎',
            reading: 'たなかたろう',
            phone: '090-1234-5678',
            email: 'taro@example.com',
            createdAt: DateTime(2026, 1, 1),
          ),
        );

/// 覚悟の設定 → 寝坊時連絡・共有 → 寝坊時連絡先 → 連絡帳 → [name], and all the way
/// back out. Picking is enough to make the pledge notify somebody:
/// `OversleepContact.isUsable` is a name that is not empty.
Future<void> setContact(WidgetTester tester, String name) async {
  await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
  await tester.tap(find.byKey(const ValueKey('contactShareRow')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('contactRow')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('contactPickRow')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

Future<ProviderContainer> pumpEditor(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Alarm? existing,
}) async {
  final container = await testContainer(
    prefs: prefs,
    extra: [fakeAlarmServiceOverride(), ...fakeCardHostageOverrides()],
  );
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 100000));
  await seedBook(container);
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

  if (existing == null) {
    await tester.tap(find.byType(FloatingActionButton));
  } else {
    await tester.tap(find.text('06:30'));
  }
  await tester.pumpAndSettle();
  return container;
}

/// Opens the 人質 sub-screen, runs [inside], and comes back — which is when the
/// choice is committed.
Future<void> inHostageScreen(
  WidgetTester tester,
  Future<void> Function() inside,
) async {
  await scrollTo(tester, find.text('人質'));
  await tester.tap(find.text('人質'));
  await tester.pumpAndSettle();
  await inside();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

bool optionEnabled(WidgetTester tester, String key) =>
    tester
        .widget<RadioListTile<HostageType>>(find.byKey(ValueKey(key)))
        .enabled ??
    true;

void main() {
  testWidgets('人質 is the first row of the island, and starts at なし', (
    tester,
  ) async {
    await pumpEditor(tester);
    await toggle(tester, '覚悟');

    expect(islandRows(tester, '覚悟の設定').first, '人質');
    expect(islandRows(tester, '覚悟の設定'), ['人質', '寝坊時連絡・共有']);
    expect(rowOf(tester, 'hostageRow').value, 'なし');
    expect(rowOf(tester, 'hostageRow').valueColor, isNull);
  });

  testWidgets('with no card the カード option is dead and offers to register', (
    tester,
  ) async {
    await pumpEditor(tester);
    await toggle(tester, '覚悟');

    await inHostageScreen(tester, () async {
      expect(find.text('なし'), findsOneWidget);
      expect(find.text('コイン'), findsOneWidget);
      expect(find.text('クレジットカード'), findsOneWidget);
      expect(find.text('寝坊してもコインもカードも失いません。連絡・共有だけの覚悟です。'), findsOneWidget);
      expect(find.text('寝坊すると、アプリ内のコインが燃えます。'), findsOneWidget);
      expect(find.text('寝坊で確定した金額を、毎月末にまとめてカードに請求します。'), findsOneWidget);

      expect(optionEnabled(tester, 'hostageOptionNone'), isTrue);
      expect(optionEnabled(tester, 'hostageOptionCoin'), isTrue);
      expect(
        optionEnabled(tester, 'hostageOptionCard'),
        isFalse,
        reason: 'a card that does not exist cannot be put up',
      );

      // And the way out of that: the same プロフィール screen, one tap away.
      expect(find.byKey(const ValueKey('hostageRegisterCard')), findsOneWidget);
      expect(find.text('カードを登録する'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hostageRegisterCard')));
      await tester.pumpAndSettle();
      expect(find.text('クレジットカードを人質にする'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('with a card registered the option is live and 「登録する」 is gone', (
    tester,
  ) async {
    await pumpEditor(tester, prefs: _enrolledPrefs);
    await toggle(tester, '覚悟');

    await inHostageScreen(tester, () async {
      expect(optionEnabled(tester, 'hostageOptionCard'), isTrue);
      expect(find.byKey(const ValueKey('hostageRegisterCard')), findsNothing);
    });
  });

  testWidgets('choosing クレジットカード names the card and switches to 円', (
    tester,
  ) async {
    final container = await pumpEditor(tester, prefs: _enrolledPrefs);
    await toggle(tester, '覚悟');

    await inHostageScreen(tester, () async {
      await tester.tap(find.text('クレジットカード'));
      await tester.pumpAndSettle();
    });

    await scrollTo(tester, find.text('人質'));
    // The label alone — which card it is belongs to プロフィール, and the
    // brand + last4 did not fit the row.
    expect(rowOf(tester, 'hostageRow').value, 'クレジットカード');
    expect(rowOf(tester, 'hostageRow').valueColor, isNull);

    // Every amount in the island is now read in yen, with the separators money
    // is written with. Same stored number: 1 コイン = 1 円.
    await scrollTo(tester, find.byKey(const ValueKey('maxLoss')));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('maxLoss'))).data,
      '1,000 円',
    );
    await scrollTo(tester, find.text('上限金額'));
    expect(rowOf(tester, 'hostageRow'), isNotNull);
    expect(find.text('1,000 円'), findsWidgets);
    expect(find.text('100 円/分'), findsOneWidget, reason: '寝坊ペナルティ');
    expect(find.text('50 円'), findsOneWidget, reason: 'スヌーズペナルティ');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final saved = (await container.read(alarmRepositoryProvider).getAll())
        .single;
    expect(saved.kakugo!.hostage, HostageType.card);
    expect(saved.kakugo!.cap, 1000, reason: 'the number itself did not move');
  });

  testWidgets('a card pledge whose card is gone says so, in the error colour', (
    tester,
  ) async {
    // The alarm was saved against a card; the card was handed back afterwards.
    // The stored alarm is left exactly as it is.
    await pumpEditor(
      tester,
      existing: const Alarm(
        id: 'a1',
        hour: 6,
        minute: 30,
        kakugo: Kakugo(
          hostage: HostageType.card,
          ratePerMinute: 100,
          cap: 1000,
        ),
      ),
    );

    await scrollTo(tester, find.text('人質'));
    expect(rowOf(tester, 'hostageRow').value, 'クレジットカード');
    expect(
      rowOf(tester, 'hostageRow').subtitle,
      'カードが未登録です（プロフィールで登録できます）',
    );
    expect(rowOf(tester, 'hostageRow').valueColor, kakugoDanger);
  });

  testWidgets('人質なし hides every money row; コイン brings them back', (
    tester,
  ) async {
    await pumpEditor(tester);
    await toggle(tester, '覚悟');

    // Nothing at stake: the island is down to the two rows that decide what
    // there would be. 起床猶予 is not one of them — it belongs to 基本設定 now.
    expect(islandRows(tester, '覚悟の設定'), ['人質', '寝坊時連絡・共有']);
    expect(find.text('寝坊で失う最大金額'), findsNothing);

    await inHostageScreen(tester, () async {
      await tester.tap(find.text('コイン'));
      await tester.pumpAndSettle();
    });

    expect(islandRows(tester, '覚悟の設定'), [
      '人質',
      '寝坊時連絡・共有',
      '寝坊ペナルティ',
      'スヌーズペナルティ',
      '上限金額',
    ]);
    expect(find.text('寝坊で失う最大金額'), findsOneWidget);
  });

  testWidgets('起床猶予 は覚悟が無くても基本設定にある', (tester) async {
    await pumpEditor(tester);

    // No pledge, nobody to tell — and the row is still there: the window is
    // what decides whether the morning counts as overslept at all, which
    // every alarm has.
    expect(islandRows(tester, '基本設定'), contains('起床猶予'));
    await scrollTo(tester, find.byKey(const ValueKey('graceRow')));
    expect(rowOf(tester, 'graceRow').value, '1分');
  });

  testWidgets('人質なし でも起床猶予は設定できる', (tester) async {
    final container = await pumpEditor(tester);
    await toggle(tester, '覚悟');

    await scrollTo(tester, find.byKey(const ValueKey('graceRow')));
    expect(rowOf(tester, 'graceRow').label, '起床猶予');
    expect(rowOf(tester, 'graceRow').value, '1分', reason: 'the default');

    await tester.tap(find.byKey(const ValueKey('graceRow')));
    await tester.pumpAndSettle();
    expect(find.text('1〜5分'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('sliderNumberInput')).first,
      '3',
    );
    await tester.pumpAndSettle();
    // Committed on the way out, like every other sub-screen.
    await tester.pageBack();
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const ValueKey('graceRow')));
    expect(rowOf(tester, 'graceRow').value, '3分');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final saved = (await container.read(alarmRepositoryProvider).getAll())
        .single;
    expect(saved.graceMinutes, 3);
    expect(saved.kakugo!.hostage, HostageType.none);
  });

  testWidgets('起床猶予 の編集口は基本設定の行だけ', (tester) async {
    await pumpEditor(tester);
    await toggle(tester, '覚悟');
    await inHostageScreen(tester, () async {
      await tester.tap(find.text('コイン'));
      await tester.pumpAndSettle();
    });

    // A burning pledge reads it in the same place as every other alarm.
    await scrollTo(tester, find.byKey(const ValueKey('graceRow')));
    expect(rowOf(tester, 'graceRow').value, '1分');

    // And it is not also inside the 寝坊ペナルティ sub-screen, where it used to
    // live: one number, one editor.
    await scrollTo(tester, find.text('寝坊ペナルティ'));
    await tester.tap(find.text('寝坊ペナルティ'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('graceSelector')), findsNothing);
    expect(find.text('起床猶予'), findsNothing);
    expect(
      find.byKey(const ValueKey('kakugoGauge')),
      findsOneWidget,
      reason: 'the gauge and the clock mode stay',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('the 人質 screen sells nothing', (tester) async {
    await pumpEditor(tester, prefs: _enrolledPrefs);
    await toggle(tester, '覚悟');

    await inHostageScreen(tester, () async {
      for (final banned in const ['広告', '課金', '購入', 'プレミアム', 'スタミナ']) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
    });
  });
}
