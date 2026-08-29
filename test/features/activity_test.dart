import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/activity/activity_screen.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

/// アクティビティ — the tab that shows what the mornings actually did.

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

Future<void> openRecordings(WidgetTester tester) async {
  await openActivity(tester);
  await scrollTo(tester, find.byKey(const ValueKey('activityRecordings')));
}

AlarmSession failed({
  required String id,
  required DateTime firedAt,
  int loss = 300,
  HostageType hostage = HostageType.coin,
}) => AlarmSession(
  id: id,
  alarmId: 'a1',
  firedAt: firedAt,
  dismissedAt: firedAt.add(const Duration(minutes: 5)),
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

void main() {
  testWidgets('every section is on the tab, with a history behind it', (
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
        .save(
          ContactEvent(
            id: 'e1',
            sessionId: 's2',
            firedAt: DateTime(2026, 8, 27, 7, 5),
            contactName: '田中太郎さん',
            channel: ContactChannel.sms,
          ),
        );

    await openActivity(tester);

    for (final key in const [
      'activityWakeChart',
      'activityPenaltyList',
      'activityContactLog',
      'activityRecordings',
    ]) {
      await scrollTo(tester, find.byKey(ValueKey(key)));
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.text('寝言の録音'), findsOneWidget);
  });

  testWidgets('the chart counts days, not rings', (tester) async {
    final container = await pumpApp(tester);
    final sessions = container.read(alarmSessionRepositoryProvider);
    // Two rings on one morning, both fine; one overslept the day before.
    await sessions.save(woke(id: 's1', firedAt: DateTime(2026, 8, 29, 6)));
    await sessions.save(woke(id: 's2', firedAt: DateTime(2026, 8, 29, 7)));
    await sessions.save(failed(id: 's3', firedAt: DateTime(2026, 8, 28, 7)));

    await openActivity(tester);

    expect(find.text('成功 1 ／ 寝坊 1（直近30日）'), findsOneWidget);
  });

  testWidgets('ペナルティ履歴 lists the losses, newest first, with the total', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    final sessions = container.read(alarmSessionRepositoryProvider);
    await sessions.save(
      failed(id: 's1', firedAt: DateTime(2026, 8, 20, 7), loss: 200),
    );
    await sessions.save(
      failed(id: 's2', firedAt: DateTime(2026, 8, 25, 7, 30), loss: 1300),
    );
    // Woke up: on the tab's history, but not in this list.
    await sessions.save(woke(id: 's3', firedAt: DateTime(2026, 8, 26, 7)));

    await openActivity(tester);

    expect(find.text('総支払額 1,500 コイン'), findsOneWidget);
    expect(find.text('8/25 07:30'), findsOneWidget);
    expect(find.text('−1300 コイン'), findsOneWidget);
    expect(find.text('8/20 07:00'), findsOneWidget);
    expect(find.text('−200 コイン'), findsOneWidget);

    // Newest first.
    final rows = tester.getTopLeft(find.byKey(const ValueKey('penalty-s2')));
    final older = tester.getTopLeft(find.byKey(const ValueKey('penalty-s1')));
    expect(rows.dy, lessThan(older.dy));
  });

  testWidgets('a card pledge says it will be billed, and shows 請求予定', (
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

    expect(find.text('1,300 円をカードに請求予定'), findsOneWidget);
    expect(find.text('請求予定 1,300 円'), findsOneWidget);
  });

  testWidgets('an empty history is an empty tab, not a crash', (tester) async {
    await pumpApp(tester);
    await openActivity(tester);

    expect(find.byKey(const ValueKey('activityWakeChart')), findsOneWidget);
    expect(find.text('まだ記録はありません'), findsOneWidget);
    expect(find.text('まだペナルティはありません'), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('activityRecordings')));
    expect(find.text('まだ録音はありません'), findsOneWidget);
    // The contact log stays away entirely until something has been sent.
    expect(find.byKey(const ValueKey('activityContactLog')), findsNothing);
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
