import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/alarm_draft.dart';
import 'package:wake_or_pay/features/alarms/alarm_edit_screen.dart';

import 'alarms_test.dart' show pumpHome;

/// Something worth copying: a pledge, a non-default grace window, and days.
const sourceAlarm = Alarm(
  id: 'a1',
  hour: 6,
  minute: 30,
  repeatDays: {1, 5},
  graceMinutes: 4,
  wakeCheck: WakeCheckType.math,
  kakugo: Kakugo(ratePerMinute: 500, cap: 3000),
);

/// The seed the open editor was built from — the family key of its draft.
Alarm seedOf(WidgetTester tester) =>
    tester.widget<TimeWheel>(find.byType(TimeWheel)).seed;

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  test('hasTimeClash: another alarm at the same minute, and only that', () {
    const other = Alarm(id: 'other', hour: 6, minute: 30);
    const draft = Alarm(id: 'draft', hour: 6, minute: 30);

    expect(hasTimeClash(const [other], draft), isTrue);
    expect(
      hasTimeClash(const [draft], draft),
      isFalse,
      reason: 'an alarm never clashes with itself',
    );
    expect(
      hasTimeClash(const [other], Alarm(id: 'draft', hour: 6, minute: 31)),
      isFalse,
    );
    expect(
      hasTimeClash(
        const [Alarm(id: 'other', hour: 6, minute: 30, repeatDays: {1})],
        draft,
      ),
      isTrue,
      reason: 'repeat days do not rescue a duplicate time',
    );
    expect(hasTimeClash(const [], draft), isFalse);
  });

  testWidgets('a long press offers 複製 and 削除; 削除 deletes', (tester) async {
    final container = await pumpHome(tester);
    await container.read(alarmRepositoryProvider).save(sourceAlarm);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('06:30'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('alarmActionsDialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('alarmActionDuplicate')), findsOneWidget);
    expect(find.text('複製'), findsOneWidget);
    expect(find.byKey(const ValueKey('alarmActionDelete')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('alarmActionDelete')));
    await tester.pumpAndSettle();

    expect(await container.read(alarmRepositoryProvider).getAll(), isEmpty);
    expect(find.text('アラームはまだありません'), findsOneWidget);
  });

  testWidgets('複製 opens a copy that cannot be saved on the same minute', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 5000);
    await container.read(alarmRepositoryProvider).save(sourceAlarm);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('06:30'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alarmActionDuplicate')));
    await tester.pumpAndSettle();

    expect(find.text('アラームを複製'), findsOneWidget);
    expect(find.text('複製'), findsOneWidget, reason: 'the FAB says so too');
    expect(
      find.byTooltip('削除'),
      findsNothing,
      reason: 'a copy has nothing to delete yet',
    );

    // Same minute as the alarm it came from: warned about, and not saveable.
    expect(find.byKey(const ValueKey('duplicateTimeWarning')), findsOneWidget);
    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('alarmSaveFab')),
    );
    expect(fab.onPressed, isNull);

    // Everything came across, not just the time.
    expect(find.text('覚悟の設定'), findsOneWidget);
    final draft = container.read(alarmDraftProvider(seedOf(tester)));
    expect(draft.id, isNot(sourceAlarm.id));
    expect(draft.graceMinutes, 4);
    expect(draft.kakugo, sourceAlarm.kakugo);
    expect(draft.repeatDays, {1, 5});
    expect(draft.wakeCheck, WakeCheckType.math);
  });

  testWidgets('moving the copy to a free time saves a second alarm', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 5000);
    await container.read(alarmRepositoryProvider).save(sourceAlarm);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('06:30'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alarmActionDuplicate')));
    await tester.pumpAndSettle();

    // The wheel's job, done directly: what matters here is the rule, not the
    // gesture that drives it.
    container.read(alarmDraftProvider(seedOf(tester)).notifier).setTime(8, 30);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('duplicateTimeWarning')), findsNothing);
    expect(
      tester
          .widget<FloatingActionButton>(
            find.byKey(const ValueKey('alarmSaveFab')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('alarmSaveFab')));
    await tester.pumpAndSettle();

    final all = await container.read(alarmRepositoryProvider).getAll();
    expect(all, hasLength(2));
    final copy = all.firstWhere((a) => a.id != sourceAlarm.id);
    expect(copy.hour, 8);
    expect(copy.minute, 30);
    expect(copy.graceMinutes, 4);
    expect(copy.kakugo, sourceAlarm.kakugo);
    expect(copy.repeatDays, {1, 5});
    // Both rows are on Home.
    expect(find.text('06:30'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
  });
}
