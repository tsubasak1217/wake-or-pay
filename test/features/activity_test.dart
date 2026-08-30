import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/activity/activity_screen.dart';
import 'package:wake_or_pay/features/activity/contact_log_archive_screen.dart';
import 'package:wake_or_pay/features/activity/penalty_bar_chart.dart';
import 'package:wake_or_pay/features/activity/penalty_history_screen.dart';
import 'package:wake_or_pay/features/activity/wake_time_history_screen.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

/// アクティビティ — the tab that shows what the mornings actually did.
/// See `docs/design/activity_spec_2026-08-30.png`.

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  List<Override> extra = const [],
}) async {
  final container = await testContainer(
    extra: [fakeAlarmServiceOverride(), ...extra],
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

Future<void> openActivity(WidgetTester tester) async {
  await tester.tap(find.text('アクティビティ'));
  await tester.pumpAndSettle();
}

Finder get activityList => find
    .descendant(of: find.byType(ActivityScreen), matching: find.byType(Scrollable))
    .first;

/// The tab is taller than a phone, so the lower islands have to be scrolled to
/// before they exist at all.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 200, scrollable: activityList);
  await tester.pumpAndSettle();
}

Future<void> tapLink(WidgetTester tester, String key) async {
  await scrollTo(tester, find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> openRecordings(WidgetTester tester) async {
  await openActivity(tester);
  await scrollTo(tester, find.byKey(const ValueKey('activityRecordings')));
}

AlarmSession failed({
  required String id,
  required DateTime firedAt,
  int loss = 300,
  Duration slept = const Duration(minutes: 5),
  HostageType hostage = HostageType.coin,
}) => AlarmSession(
  id: id,
  alarmId: 'a1',
  firedAt: firedAt,
  dismissedAt: firedAt.add(slept),
  status: SessionStatus.failed,
  loss: loss,
  kakugoSnapshot: Kakugo(hostage: hostage, ratePerMinute: 100, cap: 2000),
);

AlarmSession woke({required String id, required DateTime firedAt}) =>
    AlarmSession(
      id: id,
      alarmId: 'a1',
      firedAt: firedAt,
      dismissedAt: firedAt,
      status: SessionStatus.success,
    );

ContactEvent contact({
  required String id,
  required DateTime firedAt,
  String name = '田中太郎さん',
}) => ContactEvent(
  id: id,
  sessionId: 's1',
  firedAt: firedAt,
  contactName: name,
  channel: ContactChannel.sms,
);

void main() {
  testWidgets('the four cards of the sketch are all on the tab', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      extra: [
        fakeRecordingLibraryOverride(
          FakeRecordingLibrary(const ['/rec/a1-1756400000000.m4a']),
        ),
      ],
    );
    final sessions = container.read(alarmSessionRepositoryProvider);
    await sessions.save(woke(id: 's1', firedAt: DateTime(2026, 8, 28, 7)));
    await sessions.save(failed(id: 's2', firedAt: DateTime(2026, 8, 27, 7)));
    await container
        .read(contactEventRepositoryProvider)
        .save(contact(id: 'e1', firedAt: DateTime(2026, 8, 27, 7, 5)));

    await openActivity(tester);

    for (final card in const [
      ('activityMonthCard', '今月の寝坊ペナルティ'),
      ('activityWakeChart', '起床時間の遷移(30日間)'),
      ('activityContactLog', '寝坊連絡・共有履歴'),
      ('activityRecordings', '寝言の録音'),
    ]) {
      await scrollTo(tester, find.byKey(ValueKey(card.$1)));
      expect(find.byKey(ValueKey(card.$1)), findsOneWidget, reason: card.$1);
      expect(find.text(card.$2), findsOneWidget, reason: card.$2);
    }

    // The two strips the sketch drops are gone from the tab itself.
    expect(find.text('起床・寝坊の記録'), findsNothing);
    expect(find.byKey(const ValueKey('activityPenaltyList')), findsNothing);
  });

  group('今月の寝坊ペナルティ', () {
    testWidgets('counts the month, in both units, with the ¥50 footnote', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final sessions = container.read(alarmSessionRepositoryProvider);
      // Coins: two oversleeps this month.
      await sessions.save(
        failed(
          id: 's1',
          firedAt: DateTime(2026, 8, 20, 7),
          loss: 200,
          slept: const Duration(minutes: 15),
        ),
      );
      await sessions.save(
        failed(
          id: 's2',
          firedAt: DateTime(2026, 8, 25, 7),
          loss: 500,
          slept: const Duration(minutes: 10),
        ),
      );
      // Card: a third, on the ledger instead of the coin balance.
      await sessions.save(
        failed(
          id: 's3',
          firedAt: DateTime(2026, 8, 26, 7),
          loss: 1024,
          slept: Duration.zero,
          hostage: HostageType.card,
        ),
      );
      await container
          .read(pendingChargeRepositoryProvider)
          .insertIfAbsent(
            PendingCharge(
              sessionId: 's3',
              alarmId: 'a1',
              amount: 1024,
              createdAt: DateTime(2026, 8, 26, 7, 10),
            ),
          );
      // Last month: not this card's business.
      await sessions.save(
        failed(id: 'old', firedAt: DateTime(2026, 7, 20, 7), loss: 9000),
      );

      await openActivity(tester);

      expect(find.text('寝坊回数 3回　総寝坊時間 25分'), findsOneWidget);
      expect(find.text('1,024円'), findsOneWidget);
      expect(find.text('700コイン'), findsOneWidget);
      expect(find.text('※総額50円未満の場合は請求されません'), findsOneWidget);
    });

    testWidgets('an empty month reads 0円 / 0コイン rather than nothing', (
      tester,
    ) async {
      await pumpApp(tester);
      await openActivity(tester);

      expect(find.text('寝坊回数 0回　総寝坊時間 0分'), findsOneWidget);
      expect(find.text('0円'), findsOneWidget);
      expect(find.text('0コイン'), findsOneWidget);
    });

    testWidgets('ペナルティ履歴 opens the whole history, on the latest day', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final sessions = container.read(alarmSessionRepositoryProvider);
      await sessions.save(
        failed(id: 'old', firedAt: DateTime(2026, 6, 10, 7), loss: 200),
      );
      await sessions.save(
        failed(id: 'new', firedAt: DateTime(2026, 8, 25, 7, 30), loss: 1300),
      );

      await openActivity(tester);
      await tapLink(tester, 'activityPenaltyHistoryLink');

      expect(find.byType(PenaltyHistoryScreen), findsOneWidget);
      expect(find.text('コイン'), findsOneWidget);
      expect(find.text('カード'), findsOneWidget);
      // Defaults to the latest day that cost something.
      expect(find.text('2026/8/25 の記録'), findsOneWidget);
      expect(find.byKey(const ValueKey('penaltyDayRow-new')), findsOneWidget);
      expect(find.text('1300 コイン'), findsOneWidget);
      expect(find.byKey(const ValueKey('penaltyDayRow-old')), findsNothing);
    });

    testWidgets('tapping a day on the chart moves the log to it', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final sessions = container.read(alarmSessionRepositoryProvider);
      // Two days, so the chart is two columns wide and the left half is the
      // older one.
      await sessions.save(
        failed(id: 'first', firedAt: DateTime(2026, 8, 20, 7), loss: 200),
      );
      await sessions.save(
        failed(id: 'second', firedAt: DateTime(2026, 8, 21, 7), loss: 300),
      );

      await openActivity(tester);
      await tapLink(tester, 'activityPenaltyHistoryLink');
      expect(find.text('2026/8/21 の記録'), findsOneWidget);

      final chart = tester.getRect(find.byKey(const ValueKey('penaltyHistoryChart')));
      await tester.tapAt(Offset(chart.left + chart.width * 0.1, chart.center.dy));
      await tester.pumpAndSettle();

      expect(find.text('2026/8/20 の記録'), findsOneWidget);
      expect(find.byKey(const ValueKey('penaltyDayRow-first')), findsOneWidget);
    });

    testWidgets('a card loss says it will be billed, not spent', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await container
          .read(alarmSessionRepositoryProvider)
          .save(
            failed(
              id: 's1',
              firedAt: DateTime(2026, 8, 25, 7),
              loss: 1300,
              hostage: HostageType.card,
            ),
          );
      await container
          .read(pendingChargeRepositoryProvider)
          .insertIfAbsent(
            PendingCharge(
              sessionId: 's1',
              alarmId: 'a1',
              amount: 1300,
              createdAt: DateTime(2026, 8, 25, 7, 10),
            ),
          );

      await openActivity(tester);
      await tapLink(tester, 'activityPenaltyHistoryLink');

      expect(find.text('1,300 円をカードに請求予定'), findsOneWidget);
    });

    testWidgets('nothing ever lost is an empty history, not a crash', (
      tester,
    ) async {
      await pumpApp(tester);
      await openActivity(tester);
      await tapLink(tester, 'activityPenaltyHistoryLink');

      expect(find.byKey(const ValueKey('penaltyHistoryEmpty')), findsOneWidget);
    });
  });

  group('起床時間の遷移', () {
    testWidgets('もっと見る opens the whole history with its average', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final sessions = container.read(alarmSessionRepositoryProvider);
      await sessions.save(woke(id: 's1', firedAt: DateTime(2026, 8, 27, 6)));
      await sessions.save(woke(id: 's2', firedAt: DateTime(2026, 8, 28, 8)));
      // Older than the tab's 30-day window, but part of the whole history.
      await sessions.save(woke(id: 's3', firedAt: DateTime(2026, 5, 1, 7)));

      await openActivity(tester);
      await tapLink(tester, 'activityWakeMoreLink');

      expect(find.byType(WakeTimeHistoryScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('wakeHistoryChart')), findsOneWidget);
      expect(find.text('記録 3日 ・ 平均 7:00'), findsOneWidget);
    });

    testWidgets('no morning on record is an empty chart, not a flat line', (
      tester,
    ) async {
      await pumpApp(tester);
      await openActivity(tester);

      expect(find.text('まだ記録はありません'), findsWidgets);
      await tapLink(tester, 'activityWakeMoreLink');
      expect(find.byKey(const ValueKey('wakeHistoryEmpty')), findsOneWidget);
    });
  });

  group('寝坊連絡・共有履歴', () {
    testWidgets('the card carries the five most recent, and no more', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final events = container.read(contactEventRepositoryProvider);
      for (var i = 1; i <= 7; i++) {
        await events.save(
          contact(id: 'e$i', firedAt: DateTime(2026, 8, 20 + i, 7)),
        );
      }

      await openActivity(tester);
      await scrollTo(tester, find.byKey(const ValueKey('activityContactLog')));

      // Newest five: e7 … e3.
      for (final id in const ['e7', 'e6', 'e5', 'e4', 'e3']) {
        expect(
          find.byKey(ValueKey('contactEvent-$id')),
          findsOneWidget,
          reason: id,
        );
      }
      for (final id in const ['e2', 'e1']) {
        expect(find.byKey(ValueKey('contactEvent-$id')), findsNothing, reason: id);
      }
    });

    testWidgets('an empty log is a card that says so', (tester) async {
      await pumpApp(tester);
      await openActivity(tester);
      await scrollTo(tester, find.byKey(const ValueKey('activityContactLog')));

      expect(find.byKey(const ValueKey('activityContactLog')), findsOneWidget);
      expect(find.text('まだ記録はありません'), findsWidgets);
    });

    testWidgets('the archive shows only years with data and greys empty months', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final events = container.read(contactEventRepositoryProvider);
      await events.save(contact(id: 'e1', firedAt: DateTime(2026, 8, 20, 7)));
      await events.save(contact(id: 'e2', firedAt: DateTime(2026, 3, 2, 7)));
      await events.save(contact(id: 'e3', firedAt: DateTime(2024, 5, 4, 7)));

      await openActivity(tester);
      await tapLink(tester, 'activityContactMoreLink');

      expect(find.byType(ContactLogArchiveScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('archiveYear-2026')), findsOneWidget);
      expect(find.byKey(const ValueKey('archiveYear-2024')), findsOneWidget);
      // 2025 had nothing at all: no header, no grid.
      expect(find.byKey(const ValueKey('archiveYear-2025')), findsNothing);
      // This year stops at this month.
      expect(find.byKey(const ValueKey('archiveMonth-2026-08')), findsOneWidget);
      expect(find.byKey(const ValueKey('archiveMonth-2026-09')), findsNothing);

      // An empty month is drawn, but does not answer a tap.
      final empty = tester.widget<Material>(
        find.byKey(const ValueKey('archiveMonth-2026-01')),
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byKey(const ValueKey('archiveMonth-2026-01')),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
      expect(empty, isNotNull);
    });

    testWidgets('tapping a month lists that month under the grid', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final events = container.read(contactEventRepositoryProvider);
      await events.save(
        contact(id: 'aug', firedAt: DateTime(2026, 8, 20, 7), name: '母さん'),
      );
      await events.save(
        contact(id: 'mar', firedAt: DateTime(2026, 3, 2, 7), name: '部長'),
      );

      await openActivity(tester);
      await tapLink(tester, 'activityContactMoreLink');

      // Nothing is listed until a month is chosen.
      expect(find.byKey(const ValueKey('contactEvent-aug')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('archiveMonth-2026-03')));
      await tester.pumpAndSettle();

      expect(find.text('2026年3月'), findsOneWidget);
      expect(find.byKey(const ValueKey('contactEvent-mar')), findsOneWidget);
      expect(find.byKey(const ValueKey('contactEvent-aug')), findsNothing);
    });

    testWidgets('an archive with nothing in it says so', (tester) async {
      await pumpApp(tester);
      await openActivity(tester);
      await tapLink(tester, 'activityContactMoreLink');

      expect(find.byKey(const ValueKey('archiveEmpty')), findsOneWidget);
    });
  });

  group('寝言の録音', () {
    testWidgets('lists the shelf newest first and plays one', (tester) async {
      final player = FakeVoicePlayer();
      await pumpApp(
        tester,
        extra: [
          fakeRecordingLibraryOverride(
            FakeRecordingLibrary(const [
              // 2026-08-20 and 2026-08-25, in the wrong order on purpose.
              '/rec/a1-1755648000000.m4a',
              '/rec/a1-1756080000000.m4a',
            ]),
          ),
          fakeVoicePlayerOverride(player),
        ],
      );
      await openRecordings(tester);

      final newer = tester.getTopLeft(
        find.byKey(const ValueKey('recording-/rec/a1-1756080000000.m4a')),
      );
      final older = tester.getTopLeft(
        find.byKey(const ValueKey('recording-/rec/a1-1755648000000.m4a')),
      );
      expect(newer.dy, lessThan(older.dy));

      await tester.tap(find.byTooltip('再生').first);
      await tester.pumpAndSettle();
      expect(player.played, ['/rec/a1-1756080000000.m4a']);

      // The row now offers a stop instead of a second play.
      expect(find.byTooltip('停止'), findsOneWidget);
      await tester.tap(find.byTooltip('停止'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('停止'), findsNothing);
    });

    testWidgets('delete asks first, and やめる keeps the file', (tester) async {
      final library = FakeRecordingLibrary(const ['/rec/a1-1756080000000.m4a']);
      await pumpApp(tester, extra: [fakeRecordingLibraryOverride(library)]);
      await openRecordings(tester);

      await tester.tap(find.byTooltip('削除'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recordingDeleteConfirm')), findsOneWidget);

      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();
      expect(library.deleted, isEmpty);
      expect(find.byTooltip('削除'), findsOneWidget);
    });

    testWidgets('削除 removes it from the shelf and from the list', (
      tester,
    ) async {
      final library = FakeRecordingLibrary(const ['/rec/a1-1756080000000.m4a']);
      await pumpApp(tester, extra: [fakeRecordingLibraryOverride(library)]);
      await openRecordings(tester);

      await tester.tap(find.byTooltip('削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除').last);
      await tester.pumpAndSettle();

      expect(library.deleted, ['/rec/a1-1756080000000.m4a']);
      expect(library.paths, isEmpty);
      expect(find.text('まだ録音はありません'), findsOneWidget);
    });
  });

  group('グラフ (fl_chart)', () {
    testWidgets('the tab draws a LineChart of the mornings it was given', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final sessions = container.read(alarmSessionRepositoryProvider);
      // 06:00, 08:00 and 07:00 → three spots, average 07:00 = 420 minutes.
      await sessions.save(woke(id: 's1', firedAt: DateTime(2026, 8, 26, 6)));
      await sessions.save(woke(id: 's2', firedAt: DateTime(2026, 8, 27, 8)));
      await sessions.save(woke(id: 's3', firedAt: DateTime(2026, 8, 28, 7)));

      await openActivity(tester);
      await scrollTo(tester, find.byKey(const ValueKey('activityWakeChart')));

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.spots.length, 3);
      expect(
        chart.data.lineBarsData.first.spots.map((s) => s.y),
        containsAll(<double>[6 * 60, 8 * 60, 7 * 60]),
      );
      expect(chart.data.extraLinesData.horizontalLines.single.y, 7 * 60);
      // The 30-day card does not pan; the whole history does.
      expect(chart.transformationConfig.scaleAxis, FlScaleAxis.none);
    });

    testWidgets('the whole-history line chart pans and zooms horizontally', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final sessions = container.read(alarmSessionRepositoryProvider);
      await sessions.save(woke(id: 's1', firedAt: DateTime(2026, 5, 1, 6)));
      await sessions.save(woke(id: 's2', firedAt: DateTime(2026, 8, 28, 8)));

      await openActivity(tester);
      await tapLink(tester, 'activityWakeMoreLink');

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.spots.length, 2);
      expect(chart.transformationConfig.scaleAxis, FlScaleAxis.horizontal);
      expect(chart.transformationConfig.minScale, 1);
      expect(chart.transformationConfig.maxScale, 6);
    });

    testWidgets('ペナルティ履歴 is a BarChart, one stacked group per day', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final sessions = container.read(alarmSessionRepositoryProvider);
      // 8/20 costs coins, 8/22 costs the card, 8/21 costs nothing — and is
      // still a column, so the quiet day is drawn rather than skipped.
      await sessions.save(
        failed(id: 'coin', firedAt: DateTime(2026, 8, 20, 7), loss: 200),
      );
      await sessions.save(
        failed(
          id: 'card',
          firedAt: DateTime(2026, 8, 22, 7),
          loss: 1300,
          hostage: HostageType.card,
        ),
      );
      await container
          .read(pendingChargeRepositoryProvider)
          .insertIfAbsent(
            PendingCharge(
              sessionId: 'card',
              alarmId: 'a1',
              amount: 1300,
              createdAt: DateTime(2026, 8, 22, 7, 10),
            ),
          );

      await openActivity(tester);
      await tapLink(tester, 'activityPenaltyHistoryLink');

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups.length, 3);
      expect(chart.data.barGroups.first.barRods.single.toY, 200);
      expect(chart.data.barGroups.last.barRods.single.toY, 1300);
      // The quiet middle day is a floor tick, not a full column.
      expect(chart.data.barGroups[1].barRods.single.toY, lessThan(200));
      expect(chart.transformationConfig.scaleAxis, FlScaleAxis.horizontal);
    });

    testWidgets('the chart hands its day up, and the log follows', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final sessions = container.read(alarmSessionRepositoryProvider);
      await sessions.save(
        failed(id: 'first', firedAt: DateTime(2026, 8, 20, 7), loss: 200),
      );
      await sessions.save(
        failed(id: 'second', firedAt: DateTime(2026, 8, 21, 7), loss: 300),
      );

      await openActivity(tester);
      await tapLink(tester, 'activityPenaltyHistoryLink');
      expect(find.text('2026/8/21 の記録'), findsOneWidget);

      // The selection is a callback, so it can be exercised without aiming a
      // tap at a rod.
      final chart = tester.widget<PenaltyBarChart>(
        find.byKey(const ValueKey('penaltyHistoryChart')),
      );
      expect(chart.bars.length, 2);
      expect(chart.selected, DateTime(2026, 8, 21));
      chart.onDaySelected(DateTime(2026, 8, 20));
      await tester.pumpAndSettle();

      expect(find.text('2026/8/20 の記録'), findsOneWidget);
      expect(find.byKey(const ValueKey('penaltyDayRow-first')), findsOneWidget);
    });

    test('no hand-painted chart is left in the activity feature', () {
      final sources = Directory('lib/features/activity')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(sources, isNotEmpty);

      for (final file in sources) {
        final source = file.readAsStringSync();
        expect(
          source.contains('extends CustomPainter'),
          isFalse,
          reason: file.path,
        );
      }

      for (final gone in const [
        'wake_time_painter.dart',
        'day_bars_painter.dart',
      ]) {
        expect(
          File('lib/features/activity/$gone').existsSync(),
          isFalse,
          reason: gone,
        );
      }

      final all = sources.map((f) => f.readAsStringSync()).join('\n');
      for (final name in const [
        'WakeTimePainter',
        'DayBarsPainter',
        'PenaltyBarsPainter',
      ]) {
        expect(all.contains(name), isFalse, reason: name);
      }
    });
  });

  testWidgets('アクティビティ sells nothing', (tester) async {
    final container = await pumpApp(
      tester,
      extra: [
        fakeRecordingLibraryOverride(
          FakeRecordingLibrary(const ['/rec/a1-1756080000000.m4a']),
        ),
      ],
    );
    await container
        .read(alarmSessionRepositoryProvider)
        .save(failed(id: 's1', firedAt: DateTime(2026, 8, 25, 7)));
    await openRecordings(tester);

    for (final word in const ['課金', '購入', '広告', 'プレミアム']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  });
}
