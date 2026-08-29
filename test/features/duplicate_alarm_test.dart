import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/alarm_draft.dart';
import 'package:wake_or_pay/features/alarms/alarm_edit_screen.dart';

import 'alarms_test.dart' show editorScrollable, pumpHome, scrollToInEditor;

/// The editor's own scroll offset — how the refusal is observed: a save blocked
/// by a clash carries the form back to the wheel at the top.
double editorOffset(WidgetTester tester) =>
    tester.state<ScrollableState>(editorScrollable).position.pixels;

/// Shrinks the window so the editor is taller than its viewport — the default
/// 1000x2400 of this file fits the whole form, and a form that cannot scroll
/// cannot show that a refused save scrolled back.
void shrinkView(WidgetTester tester) {
  TestWidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .views
      .first
      .physicalSize = const Size(800, 700);
}

/// Pushes the form well down, so a later `0` means the save actually scrolled.
Future<void> scrollEditorDown(WidgetTester tester) async {
  final position = tester.state<ScrollableState>(editorScrollable).position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
  expect(editorOffset(tester), greaterThan(0), reason: 'scrolled off the wheel');
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('alarmSaveFab')));
  await tester.pumpAndSettle();
}

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
    shrinkView(tester);
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

    // Same minute as the alarm it came from: warned about, and refused — the
    // press scrolls back to the wheel instead of saving.
    expect(find.byKey(const ValueKey('duplicateTimeWarning')), findsOneWidget);
    await scrollEditorDown(tester);
    await tapSave(tester);
    expect(editorOffset(tester), 0, reason: 'carried back to the wheel');
    expect(find.text('アラームを複製'), findsOneWidget, reason: 'no pop');
    expect(
      await container.read(alarmRepositoryProvider).getAll(),
      hasLength(1),
      reason: 'nothing was saved',
    );

    // Everything came across, not just the time. Read the seed first: the
    // scroll below takes the wheel — and with it [seedOf] — off the tree.
    final draft = container.read(alarmDraftProvider(seedOf(tester)));
    await scrollToInEditor(tester, find.text('覚悟の設定'));
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

    await tapSave(tester);

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

  testWidgets('新規: the same rule applies to an alarm that is not a copy', (
    tester,
  ) async {
    shrinkView(tester);
    final container = await pumpHome(tester, coins: 5000);
    await container
        .read(alarmRepositoryProvider)
        .save(const Alarm(id: 'a1', hour: 7, minute: 30));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('アラームを追加'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('duplicateTimeWarning')),
      findsNothing,
      reason: 'seeded at the test clock, 13:45, which is free',
    );

    container.read(alarmDraftProvider(seedOf(tester)).notifier).setTime(7, 30);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('duplicateTimeWarning')), findsOneWidget);

    await scrollEditorDown(tester);
    await tapSave(tester);
    expect(editorOffset(tester), 0);
    expect(find.text('アラームを追加'), findsOneWidget, reason: 'no pop');
    expect(await container.read(alarmRepositoryProvider).getAll(), hasLength(1));

    // One minute off is enough.
    container.read(alarmDraftProvider(seedOf(tester)).notifier).setTime(7, 31);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('duplicateTimeWarning')), findsNothing);

    await tapSave(tester);
    final all = await container.read(alarmRepositoryProvider).getAll();
    expect(all, hasLength(2));
    expect(all.firstWhere((a) => a.id != 'a1').minute, 31);
  });

  testWidgets('編集: an alarm never clashes with itself, but with another', (
    tester,
  ) async {
    shrinkView(tester);
    final container = await pumpHome(tester, coins: 5000);
    final repository = container.read(alarmRepositoryProvider);
    await repository.save(const Alarm(id: 'a1', hour: 7, minute: 30));
    await repository.save(const Alarm(id: 'a2', hour: 9, minute: 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('07:30'));
    await tester.pumpAndSettle();
    expect(find.text('アラームを編集'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('duplicateTimeWarning')),
      findsNothing,
      reason: 'its own time is not a clash',
    );

    // Onto the other alarm's minute: warned, and refused.
    container.read(alarmDraftProvider(seedOf(tester)).notifier).setTime(9, 0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('duplicateTimeWarning')), findsOneWidget);

    await scrollEditorDown(tester);
    await tapSave(tester);
    expect(editorOffset(tester), 0);
    expect(find.text('アラームを編集'), findsOneWidget, reason: 'no pop');
    expect((await repository.getById('a1'))!.hour, 7, reason: 'not saved');
  });
}
