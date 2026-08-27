import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/alarm_service.dart';

import '../helpers.dart';

Future<ProviderContainer> pumpHome(
  WidgetTester tester, {
  int coins = 0,
  List<Override> extra = const [],
}) async {
  final container = await testContainer(
    extra: [fakeAlarmServiceOverride(), ...extra],
  );
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

/// The editor's own scroll view. The time wheel brings scrollables of its own,
/// so the form has to be addressed explicitly.
Finder get editorScrollable => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<void> scrollToInEditor(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 120, scrollable: editorScrollable);
  // scrollUntilVisible stops as soon as the widget is attached, which can leave
  // it clipped at the edge of the viewport where a tap would miss it.
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

/// Opens the sub-screen behind the row labelled [row], runs [inside], and comes
/// back — which is when the sub-screen commits.
Future<void> inSubScreen(
  WidgetTester tester,
  String row,
  Future<void> Function() inside,
) async {
  await scrollToInEditor(tester, find.text(row));
  await tester.tap(find.text(row));
  await tester.pumpAndSettle();
  await inside();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

Future<void> toggleInEditor(WidgetTester tester, String label) async {
  await scrollToInEditor(tester, find.text(label));
  await tester.tap(find.widgetWithText(SwitchListTile, label));
  await tester.pumpAndSettle();
}

/// Types [value] into the one numeric field of a number sub-screen.
Future<void> enterNumber(WidgetTester tester, String value) async {
  await tester.enterText(
    find.byKey(const ValueKey('sliderNumberInput')),
    value,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('saving a new alarm makes it appear on Home', (tester) async {
    final container = await pumpHome(tester, coins: 5000);
    expect(find.text('アラームはまだありません'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('アラームを追加'), findsOneWidget);

    // Default 07:00. Monday and Friday, the maths check, kakugo at 500/min.
    await inSubScreen(tester, '曜日', () async {
      await tester.tap(find.widgetWithText(FilterChip, '月'));
      await tester.tap(find.widgetWithText(FilterChip, '金'));
      await tester.pumpAndSettle();
    });
    expect(find.text('月・金'), findsOneWidget, reason: 'summarised on the row');

    await inSubScreen(tester, '起床確認方法', () async {
      await tester.tap(find.text('計算（3問）'));
      await tester.pumpAndSettle();
    });

    await toggleInEditor(tester, '覚悟');
    await inSubScreen(tester, '寝坊ペナルティ', () async {
      await enterNumber(tester, '500');
      expect(find.text('💀 寝るな'), findsOneWidget);
    });

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Back on Home, showing the new alarm.
    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('月・金 ・ 計算（3問）'), findsOneWidget);
    // The 覚悟 row is its own thing now: the badge from the gauge, the rate,
    // and the worst case in the editor's own words on a line of its own.
    expect(find.text('💀'), findsOneWidget);
    expect(find.text('500 コイン/分'), findsOneWidget);
    expect(find.text('寝坊で失う最大金額 1000 コイン'), findsOneWidget);

    final saved =
        (await container.read(alarmRepositoryProvider).getAll()).single;
    expect(saved.repeatDays, {1, 5});
    expect(saved.wakeCheck, WakeCheckType.math);
    // Stage B: switching 覚悟 on now seeds the snooze penalty too, at the 50
    // the spec's editor shows. It costs nothing here — this alarm has no
    // snooze, so there is nothing to penalise.
    expect(saved.kakugo, defaultKakugo.copyWith(ratePerMinute: 500));
    expect(saved.kakugo!.snoozeResetsClock, isFalse, reason: 'the strict mode');
    expect(saved.enabled, isTrue);
    expect(saved.snooze, isNull, reason: 'the toggle was never touched');
    expect(saved.soundId, defaultSoundId);

    // Saving also armed the platform alarm.
    final fake = container.read(alarmServiceProvider) as FakeAlarmService;
    expect(fake.scheduled, contains(saved.id));
  });

  testWidgets('the time is set with inline 24h wheels, not a dialog', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 5000);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byKey(const ValueKey('timeWheel')),
    );
    expect(picker.mode, CupertinoDatePickerMode.time);
    expect(picker.use24hFormat, isTrue);
    expect(picker.initialDateTime.hour, 7);
    expect(picker.initialDateTime.minute, 0);
    expect(find.byType(TimePickerDialog), findsNothing, reason: 'inline');

    // Spinning the hour wheel up two rows moves 07:00 to 09:00.
    final wheel = tester.getRect(find.byKey(const ValueKey('timeWheel')));
    await tester.dragFrom(
      Offset(wheel.center.dx - 60, wheel.center.dy),
      const Offset(0, -64),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final saved =
        (await container.read(alarmRepositoryProvider).getAll()).single;
    expect(saved.hour, 9);
    expect(saved.minute, 0);
    expect(find.text('09:00'), findsOneWidget, reason: 'shown on Home');
  });

  testWidgets('a new alarm has no kakugo and no snooze island', (tester) async {
    await pumpHome(tester, coins: 5000);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('基本設定'), findsOneWidget);
    expect(
      find.text('覚悟の設定'),
      findsNothing,
      reason: 'kakugo is off on a new alarm',
    );
    expect(find.text('スヌーズ設定'), findsNothing);
    for (final row in ['曜日', '起床確認方法', 'サウンド', '起床猶予', 'スヌーズ', '覚悟']) {
      expect(find.text(row), findsOneWidget, reason: row);
    }
  });

  testWidgets(
    'the kakugo island appears with the toggle and shows the worst case',
    (tester) async {
      final container = await pumpHome(tester, coins: 5000);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await toggleInEditor(tester, '覚悟');
      expect(find.text('覚悟の設定'), findsOneWidget);
      expect(find.text('寝坊で失う最大金額'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('maxLoss'))).data,
        '1000 コイン',
        reason: 'the default cap',
      );

      // The header follows the cap.
      await inSubScreen(tester, '上限金額', () async {
        await enterNumber(tester, '2500');
      });
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('maxLoss'))).data,
        '2500 コイン',
      );

      // Switching it back off takes the island with it and clears the pledge.
      await toggleInEditor(tester, '覚悟');
      expect(find.text('覚悟の設定'), findsNothing);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(
        (await container.read(alarmRepositoryProvider).getAll()).single.kakugo,
        isNull,
      );
    },
  );

  testWidgets('the snooze island appears with the toggle and persists', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 5000);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await toggleInEditor(tester, 'スヌーズ');
    expect(find.text('スヌーズ設定'), findsOneWidget);
    expect(find.text('5分'), findsOneWidget, reason: 'the default interval');
    expect(find.text('3回'), findsOneWidget);

    await inSubScreen(tester, '間隔', () async {
      await enterNumber(tester, '12');
    });
    await inSubScreen(tester, '上限回数', () async {
      await enterNumber(tester, '2');
    });

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(
      (await container.read(alarmRepositoryProvider).getAll()).single.snooze,
      const Snooze(intervalMinutes: 12, maxCount: 2),
    );
  });

  testWidgets('the grace window defaults to one minute and is editable', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 5000);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('1分'), findsOneWidget, reason: 'today\'s rule, unchanged');

    await inSubScreen(tester, '起床猶予', () async {
      await enterNumber(tester, '5');
      expect(find.textContaining('鳴り始めからこの時間以内'), findsOneWidget);
    });
    expect(find.text('5分'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(
      (await container.read(alarmRepositoryProvider).getAll())
          .single
          .graceMinutes,
      5,
    );
  });

  testWidgets('a cap above the balance warns but still saves', (tester) async {
    final container = await pumpHome(tester, coins: 100);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await toggleInEditor(tester, '覚悟');

    // The sub-screen says so too, before the save ever happens.
    await inSubScreen(tester, '上限金額', () async {
      expect(find.byKey(const ValueKey('capOverBalance')), findsOneWidget);
    });

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('残高より上限が大きい'), findsOneWidget);
    await tester.tap(find.text('このまま保存'));
    await tester.pumpAndSettle();

    expect(
      await container.read(alarmRepositoryProvider).getAll(),
      hasLength(1),
    );
  });

  testWidgets('the warning can be backed out of without saving', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 100);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await toggleInEditor(tester, '覚悟');
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
    // 「スヌーズ」 itself is no longer banned: as of the alarm v2 spec it is a
    // free standard feature. Selling it in any form still is.
    for (final banned in [
      '広告',
      'プレミアム',
      'アップグレード',
      '課金して',
      'スヌーズを購入',
      'スヌーズを追加',
    ]) {
      expect(find.textContaining(banned), findsNothing, reason: banned);
    }
  });
}
